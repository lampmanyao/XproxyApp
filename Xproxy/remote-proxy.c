#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "xproxy.h"
#include "socks5.h"
#include "el.h"
#include "tcp-connection.h"
#include "log.h"
#include "cfg.h"
#include "poller.h"
#include "crypt.h"
#include "utils.h"

#define BUFF_SIZE 4096

static void accept_cb(struct xproxy *xproxy);
static int recvfrom_local_cb(struct el *el, struct tcp_connection *tcp_conn);
static int sendto_local_cb(struct el *el, struct tcp_connection *tcp_conn);
static int recvfrom_server_cb(struct el *el, struct tcp_connection *tcp_conn);
static int sendto_server_cb(struct el *el, struct tcp_connection *tcp_conn);

static struct cryptor cryptor;
uint64_t last_recv = 0;
uint64_t last_sent = 0;

struct remote_config {
	char *password;
	char *method;
	char *local_addr;
	uint16_t local_port;
	int nthread;
	int maxfiles;
	int debug;
} configuration;

struct cfgopts cfg_opts[] = {
	{ "password", TYP_STRING, &configuration.password, {0, "helloworld"} },
	{ "method", TYP_STRING, &configuration.method, {0, "aes-256-cfb"} },
	{ "local_addr", TYP_STRING, &configuration.local_addr, {0, "0.0.0.0"} },
	{ "local_port", TYP_INT4, &configuration.local_port, {20086, NULL} },
	{ "nthread", TYP_INT4, &configuration.nthread, {4, NULL} },
	{ "maxfiles", TYP_INT4, &configuration.maxfiles, {1024, NULL} },
	{ "debug", TYP_INT4, &configuration.debug, {0, NULL} },
	{ NULL, 0, NULL, {0, NULL} }
};

static void accept_cb(struct xproxy *xproxy)
{
	int fd;
	struct tcp_connection *tcp_conn;
	struct sockaddr_in sock_addr;

	socklen_t addr_len = sizeof(struct sockaddr_in);
	bzero(&sock_addr, addr_len);

	while ((fd = accept(xproxy->sfd, (struct sockaddr*)&sock_addr, &addr_len)) > 0) {
		INFO("Accept incoming from local %s:%d.",
		      inet_ntoa(sock_addr.sin_addr), ntohs(sock_addr.sin_port));
		set_nonblocking(fd);
		tcp_conn = new_tcp_connection(fd, BUFF_SIZE, recvfrom_local_cb, sendto_local_cb);
		el_watch(xproxy->els[fd % xproxy->nthread], tcp_conn);
	}

	if (errno != EAGAIN && errno != EWOULDBLOCK)
		ERROR("accept(): %s", strerror(errno));
}

static int handle_handshake_request(struct el *el, struct tcp_connection *client)
{
	struct tcp_connection *server;
	char *data = client->rxbuf;
	uint32_t len = client->rxbuf_length;

	int ciphertext_len;
	int plaintext_len;
	uint8_t *plaintext;

	uint8_t reply[256];
	int reply_len;
	char *cipher_reply;
	int cipher_reply_len;

	uint16_t nport;
	uint16_t hsport;

	int fd;

	if (slow(len < 4))
		return 0;

	memcpy((char*)&ciphertext_len, data, 4);
	if (slow(len < 4 + (uint32_t)ciphertext_len))
		return 0;

	plaintext_len = cryptor.decrypt(&cryptor, (char**)&plaintext, data + 4, (uint32_t)ciphertext_len);
	if (slow(plaintext_len < 0)) {
		ERROR("Decryption failure.");
		return -1;
	}

	uint8_t ver = plaintext[0];
	uint8_t cmd = plaintext[1];
	uint8_t rsv = plaintext[2];
	uint8_t typ = plaintext[3];

	SHUTUP_WARNING(cmd);
	SHUTUP_WARNING(rsv);

	reply[0] = ver;
	reply[1] = SOCKS5_RSP_SUCCEED;
	reply[2] = SOCKS5_RSV;

	if (typ == SOCKS5_ATYP_IPv4) {
		char ipv4[32];

		if (!inet_ntop(AF_INET, plaintext + 4, ipv4, INET_ADDRSTRLEN)) {
			ERROR("inet_ntop(): %s", strerror(errno));
			free(plaintext);
			return -1;
		}

		memcpy((char*)&nport, plaintext + 8, SOCKS5_PORT_SIZE);
		hsport = ntohs(nport);

		fd = connect_nonblocking(ipv4, hsport, 3000);
		if (fd < 0) {
			ERROR("Cannot connect to server (%s:%d).", ipv4, hsport);
			free(plaintext);
			return -1;
		}

		server = new_tcp_connection(fd, BUFF_SIZE, recvfrom_server_cb, sendto_server_cb);
		el_watch(el, server);

		INFO("Connected to server (%s:%d).", ipv4, hsport);

		server->peer_tcp_conn = client;
		client->peer_tcp_conn = server;

		memcpy(client->host, ipv4, sizeof(ipv4));
		client->host[sizeof(ipv4)] = '\0';
		memcpy(server->host, ipv4, sizeof(ipv4));
		server->host[sizeof(ipv4)] = '\0';
		reply[3] = SOCKS5_ATYP_IPv4;
		memcpy(reply + 4, plaintext + 4, 4);
		memcpy(reply + 4 + 4, (char*)&nport, SOCKS5_PORT_SIZE);
		reply_len = SOCKS5_IPV4_REQ_SIZE;
	} else if (typ == SOCKS5_ATYP_DONAME) {
		uint8_t domain_name_len;
		char domain_name[256];

		domain_name_len = plaintext[SOCKS5_REQ_HEAD_SIZE];
		memcpy(domain_name, plaintext + SOCKS5_REQ_HEAD_SIZE + 1, domain_name_len);
		domain_name[domain_name_len] = '\0';
		memcpy((char*)&nport, plaintext + SOCKS5_REQ_HEAD_SIZE + 1 + domain_name_len,
			SOCKS5_PORT_SIZE);
		hsport = ntohs(nport);

		fd = connect_nonblocking(domain_name, hsport, 3000);
		if (slow(fd < 0)) {
			ERROR("Cannot connect to server (%s:%d)", domain_name, hsport);
			free(plaintext);
			return -1;
		}

		server = new_tcp_connection(fd, BUFF_SIZE, recvfrom_server_cb, sendto_server_cb);
		el_watch(el, server);

		client->peer_tcp_conn = server;
		server->peer_tcp_conn = client;

		INFO("Connected to server (%s:%d)", domain_name, hsport);

		memcpy(client->host, domain_name, domain_name_len);
		client->host[domain_name_len] = '\0';
		memcpy(server->host, domain_name, domain_name_len);
		server->host[domain_name_len] = '\0';
		reply[3] = SOCKS5_ATYP_DONAME;
		reply[4] = domain_name_len;
		memcpy(reply + 5, domain_name, domain_name_len);
		memcpy(reply + 5 + domain_name_len, (char*)&nport, SOCKS5_PORT_SIZE);
		reply_len = 5 + domain_name_len + SOCKS5_PORT_SIZE;
	} else if (typ == SOCKS5_ATYP_IPv6) {
		char ipv6[128];

		if (!inet_ntop(AF_INET6, plaintext + 4, ipv6, INET6_ADDRSTRLEN)) {
			ERROR("inet_ntop(): %s", strerror(errno));
			free(plaintext);
			return -1;
		}

		memcpy((char*)&nport, plaintext + 4 + 16, SOCKS5_PORT_SIZE);
		hsport = ntohs(nport);

		fd = connect6_nonblocking(ipv6, hsport, 3000);
		if (fd < 0) {
			ERROR("Cannot connect to server (%s:%d).", ipv6, hsport);
			free(plaintext);
			return -1;
		}

		server = new_tcp_connection(fd, BUFF_SIZE, recvfrom_server_cb, sendto_server_cb);
		el_watch(el, server);

		INFO("Connected to server (%s:%d).", ipv6, hsport);

		server->peer_tcp_conn = client;
		client->peer_tcp_conn = server;

		memcpy(client->host, ipv6, sizeof(ipv6));
		client->host[sizeof(ipv6)] = '\0';
		memcpy(server->host, ipv6, sizeof(ipv6));
		server->host[sizeof(ipv6)] = '\0';

		reply[3] = SOCKS5_ATYP_IPv6;
		memcpy(reply + 4, plaintext + 4, 16);
		memcpy(reply + 4 + 16, (char*)&nport, SOCKS5_PORT_SIZE);
		reply_len = SOCKS5_IPV6_REQ_SIZE;
	} else {
		ERROR("Unknown address type: %d.", typ);
		return -1;
	}

	free(plaintext);

	cipher_reply_len = cryptor.encrypt(&cryptor, &cipher_reply,
					   (char *)reply,
					   SOCKS5_IPV6_REQ_SIZE);

	if (slow(cipher_reply_len < 0)) {
		ERROR("encrypt failed");
		return -1;
	}

	tcp_connection_reset_rxbuf(client);

	tcp_connection_append_txbuf(client, (char*)&cipher_reply_len, 4);
	tcp_connection_append_txbuf(client, cipher_reply, (uint32_t)cipher_reply_len);
	free(cipher_reply);

	ssize_t tx = send(client->fd, client->txbuf, client->txbuf_length, 0);

	if (fast(tx > 0)) {
		tcp_connection_reset_txbuf(client);
		client->stage = STAGE_STREAMING;
		server->stage = STAGE_STREAMING;
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK) {
			poller_unwatch_read(el->poller, server->fd, server);
			poller_watch_write(el->poller, client->fd, client);
			return 0;
		}
		return -1;
	}
}

static int stream_to_server(struct el *el, struct tcp_connection *client)
{
	struct tcp_connection *server = client->peer_tcp_conn;;
	char *data = NULL;
	size_t data_len = 0;
	int ciphertext_len = 0;
	int plaintext_len = 0;
	char *plaintext = NULL;
	ssize_t tx = 0;

try_again:
	data = client->rxbuf;
	data_len = client->rxbuf_length;

	if (slow(data_len < 4))
		return 0;

	memcpy((char *)&ciphertext_len, data, 4);

	if (slow(data_len < 4 + (size_t)ciphertext_len))
		return 0;

	plaintext_len = cryptor.decrypt(&cryptor, &plaintext, data + 4, (unsigned int)ciphertext_len);

	if (plaintext_len < 0) {
		ERROR("Decryption failure.");
		return -1;
	}

	tcp_connection_append_txbuf(server, plaintext, (uint32_t)plaintext_len);
	free(plaintext);

	if (data_len == 4 + (size_t)ciphertext_len) {
		tcp_connection_reset_rxbuf(client);
	} else {
		tcp_connection_move_rxbuf(client, 4 + (uint32_t)ciphertext_len);
	}

	tx = send(server->fd, server->txbuf, server->txbuf_length, 0);

	if (fast(tx > 0)) {
		if ((uint32_t)tx == server->txbuf_length) {
			tcp_connection_reset_txbuf(server);
			goto try_again;
		} else {
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, server->fd, server);
			tcp_connection_move_txbuf(server, (uint32_t)tx);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK) {
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, server->fd, server);
			return 0;
		}
		return -1;
	}
}

static int recvfrom_local_cb(struct el *el, struct tcp_connection *client)
{
	int ret = -1;
	while (1) {
		char buf[BUFF_SIZE];
		ssize_t rx = recv(client->fd, buf, BUFF_SIZE - 1, 0);
		if (fast(rx > 0)) {
			tcp_connection_append_rxbuf(client, buf, (uint32_t)rx);
			if (rx < BUFF_SIZE - 1)
				break;
		} else if (rx < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK)
				break;
			return -1;
		} else {
			return -1;
		}
	}

	switch (client->stage) {
	case STAGE_HANDSHAKE:
		ret = handle_handshake_request(el, client);
		break;

	case STAGE_STREAMING:
		ret = stream_to_server(el, client);
		break;

	default:
		ret = -1;
		break;
	}

	return ret;
}

static int sendto_local_cb(struct el *el, struct tcp_connection *client)
{
	struct tcp_connection *server = client->peer_tcp_conn;
	ssize_t tx = send(client->fd, client->txbuf, client->txbuf_length, 0);

	if (fast(tx > 0)) {
		if ((uint32_t)tx == client->txbuf_length) {
			tcp_connection_reset_txbuf(client);
			poller_unwatch_write(el->poller, client->fd, client);
			poller_watch_read(el->poller, server->fd, server);
		} else {
			tcp_connection_move_txbuf(client, (uint32_t)tx);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK)
			return 0;

		return -1;
	}
}

static int recvfrom_server_cb(struct el *el, struct tcp_connection *server)
{
	struct tcp_connection *client = server->peer_tcp_conn;
	char *ciphertext;
	int ciphertext_len;
	ssize_t rx, tx;
	char buf[BUFF_SIZE];

	while (1) {
		rx = recv(server->fd, buf, BUFF_SIZE - 1, 0);
		if (fast(rx > 0)) {
			tcp_connection_append_rxbuf(server, buf, (uint32_t)rx);
			ciphertext_len = cryptor.encrypt(&cryptor, &ciphertext, server->rxbuf,
						      (unsigned int)server->rxbuf_length);
			if (slow(ciphertext_len < 0)) {
				ERROR("Encryption failure.");
				return -1;
			}

			tcp_connection_append_txbuf(client, (char *)&ciphertext_len, 4);
			tcp_connection_append_txbuf(client, ciphertext, (uint32_t)ciphertext_len);
			tcp_connection_reset_rxbuf(server);
			free(ciphertext);
			tx = send(client->fd, client->txbuf, client->txbuf_length, 0);

			if (fast(tx > 0)) {
				if ((uint32_t)tx == client->txbuf_length) {
					tcp_connection_reset_txbuf(client);
				} else {
					poller_unwatch_read(el->poller, server->fd, server);
					poller_watch_write(el->poller, client->fd, client);
					tcp_connection_move_txbuf(client, (uint32_t)tx);
				}
			} else {
				if (errno == EAGAIN || errno == EWOULDBLOCK) {
					poller_unwatch_read(el->poller, server->fd, server);
					poller_watch_write(el->poller, client->fd, client);
					return 0;
				}
				return -1;
			}
		} else if (rx < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK)
				return 0;
			return -1;
		} else {
			return -1;
		}
	}
}

static int sendto_server_cb(struct el *el, struct tcp_connection *server)
{
	struct tcp_connection *client = server->peer_tcp_conn;
	ssize_t tx = send(server->fd, server->txbuf, server->txbuf_length, 0);

	if (fast(tx > 0)) {
		if ((uint32_t)tx == server->txbuf_length) {
			poller_watch_read(el->poller, client->fd, client);
			tcp_connection_reset_txbuf(server);
		} else {
			tcp_connection_move_txbuf(server, (uint32_t)tx);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK)
			return 0;

		return -1;
	}
}

static void usage(void) {
	printf("Usage:\n");
	printf("    remote-xproxy\n");
	printf("        -c <config>           Use configure file to start.\n");
	printf("        -b <local-address>    Local address to bind: 127.0.0.1 or 0.0.0.0.\n");
	printf("        -l <local-port>       Port number for listen.\n");
	printf("        -k <password>         Password.\n");
	printf("        [-e <method>]         Cipher suite: aes-128-cfb, aes-192-cfb, aes-256-cfb.\n");
	printf("        [-t <nthread>         I/O thread number. Defaults to 8.\n");
	printf("        [-m <max-open-files>  Max open files number. Defaults to 1024.\n");
	printf("        [-v]                  Print version and quit.\n");
	printf("        [-h]                  Print this message and quit.\n");
	exit(-1);
}

int running;

int main(int argc, char **argv)
{
	int ch;
	int bflag = 0;
	int lflag = 0;
	int kflag = 0;
	int vflag = 0;  /* version */
	int cflag = 0;
	int hflag = 0;

	const char *conf_file;

	cfg_load_defaults(cfg_opts);

	while ((ch = getopt(argc, argv, "b:l:k:e:t:m:c:vVh")) != -1) {
		switch (ch) {
		case 'b':
			bflag = 1;
			configuration.local_addr = optarg;
			break;

		case 'l':
			lflag = 1;
			configuration.local_port = (uint16_t)atoi(optarg);
			break;

		case 'k':
			kflag = 1;
			configuration.password = optarg;
			break;

		case 'e':
			configuration.method = optarg;
			break;

		case 't':
			configuration.nthread = atoi(optarg);
			break;

		case 'm':
			configuration.maxfiles = atoi(optarg);
			break;

		case 'v':
			vflag = 1;
			break;

		case 'c':
			cflag = 1;
			conf_file = optarg;
			break;

		case 'h':
			hflag = 1;
			break;

		case '?':
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (vflag) {
		//printf("xproxy, version %s\n", xproxy_version());
		return 0;
	}

	if (hflag)
		usage();

	/* We load the config file first. */
	if (cflag) {
		cfg_load_file(conf_file, cfg_opts);
	} else {
		if (!bflag || !lflag || !kflag)
			usage();
	}

	signals_init();
	coredump_init();
	crypt_setup();

	if (cryptor_init(&cryptor, configuration.method, configuration.password) == -1) {
		ERROR("Unsupport method: %s.", configuration.method);
		return -1;
	}

	int sfd;
	struct xproxy *xproxy;

	if (openfiles_init(configuration.maxfiles) != 0) {
		FATAL("Set max open files to %d failed: %s.",
		      configuration.maxfiles, strerror(errno));
	}

	sfd = listen_and_bind(configuration.local_addr, configuration.local_port);
	if (sfd < 0) {
		FATAL("listen_and_bind(): %s", strerror(errno));
	}

	INFO("Listening on port %d.", configuration.local_port);

	xproxy = xproxy_new(sfd, configuration.nthread, accept_cb);
	running = 1;
	xproxy_run(xproxy);

	close(sfd);
	xproxy_free(xproxy);
	cryptor_deinit(&cryptor);
	crypt_cleanup();

        return 0;
}

