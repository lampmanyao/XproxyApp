#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/mman.h>
#include <sys/stat.h>

#ifdef __APPLE__
#include <os/log.h>
#endif

#include "platform.h"
#include "local-proxy.h"
#include "xproxy.h"
#include "socks5.h"
#include "el.h"
#include "tcp-connection.h"
#include "log.h"
#include "cfg.h"
#include "poller.h"
#include "crypt.h"
#include "utils.h"

#define BUFF_SIZE 2048

static void accept_cb(struct xproxy *xproxy);
static int recvfrom_client_cb(struct el *el, struct tcp_connection *tcp_conn);
static int sendto_client_cb(struct el *el, struct tcp_connection *tcp_conn);
static int recvfrom_remote_cb(struct el *el, struct tcp_connection *tcp_conn);
static int sendto_remote_cb(struct el *el, struct tcp_connection *tcp_conn);

static struct cryptor cryptor;

struct local_config {
	char *password;
	char *method;
	char *local_addr;
	uint16_t local_port;
	char *remote_addr;
	uint16_t remote_port;
	int nthread;
	int maxfiles;
	int debug;
} configuration;

struct cfgopts cfg_opts[] = {
	{ "password", TYP_STRING, &configuration.password, {0, "he11owor1d"} },
	{ "method", TYP_STRING, &configuration.method, {0, "aes-256-cfb"} },
	{ "local_addr", TYP_STRING, &configuration.local_addr, {0, "127.0.0.1"} },
	{ "local_port", TYP_INT4, &configuration.local_port, {1080, NULL} },
	{ "remote_addr", TYP_STRING, &configuration.remote_addr, {0, NULL} },
	{ "remote_port", TYP_INT4, &configuration.remote_port, {0, NULL} },
	{ "nthread", TYP_INT4, &configuration.nthread, {8, NULL} },
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
		logi("Accept incoming from %s:%d",
			inet_ntoa(sock_addr.sin_addr), ntohs(sock_addr.sin_port));

		set_nonblocking(fd);
		tcp_conn = new_tcp_connection(fd, BUFF_SIZE, recvfrom_client_cb, sendto_client_cb);
		el_watch(xproxy->els[fd % xproxy->nthread], tcp_conn);
	}

	if (errno != EAGAIN && errno != EWOULDBLOCK)
		loge("accept(): %s", strerror(errno));
}

#define CHECK_END()       \
	if (buf == end)   \
		return 0;

static inline uint16_t parse_port(const char *buf, long len)
{
	uint16_t r = 0;
	for (long i = 0; i < len; ++i)
		r = r * 10 + (uint16_t)(buf[i] - '0');
	return r;
}

static int handle_client_request(struct el *el, struct tcp_connection *client)
{
	uint8_t *data = client->rxbuf;
	uint32_t data_len = client->rxbuf_length;
	uint8_t *buf = data;
	uint8_t *end = data + data_len;
	uint8_t *pos;
	int len;

	uint8_t version = SOCKS5_VER;
	uint8_t cmd = SOCKS5_CMD_CONNECT;
	uint8_t rsv = 0;
	uint8_t atyp = 0;

	/* the method */
	while (*buf != ' ') {
		buf++;
		CHECK_END();
	}

	buf++;
	CHECK_END();
	pos = buf;

	/* if begin with 'http://', the request is HTTP */
	if (strncmp((const char *)buf, "http://", 7) == 0) {
		buf += 7;
		pos = buf;
		client->type = REQ_TYPE_HTTP;
	} else {
		tcp_connection_reset_rxbuf(client);
		client->type = REQ_TYPE_HTTPS;
	}

	// ipv6
	if (*buf == '[') {
		CHECK_END();
		buf++;
		pos = buf;

		while (*buf != ']') {
			CHECK_END();
			buf++;
		}

		atyp = SOCKS5_ATYP_IPv6;

		len = (int)(buf - pos);
		strncpy(client->host, (const char *)pos, len);
		client->host[len] = '\0';
		client->port = 80;

		CHECK_END();
		buf++;
		if (*buf == ':') {
			buf++;
			pos = buf;

			while (*buf != '/') {
				buf++;
				CHECK_END();
			}

			len = (int)(buf - pos);
			client->port = parse_port((const char *)pos, len);
		} else {
			client->port = 80;
		}
	} else {
		while (*buf != ':' && *buf != ' ' && *buf != '/') {
			buf++;
			CHECK_END();
		}

		if (*buf == '/' || *buf == ' ') {
			len = (int)(buf - pos);
			strncpy(client->host, (const char *)pos, len);
			client->host[len] = '\0';
			client->port = 80;
		} else if (*buf == ':') {
			len = (int)(buf - pos);
			strncpy(client->host, (const char *)pos, len);
			client->host[len] = '\0';

			buf++;
			pos = buf;

			while (*buf != ' ') {
				buf++;
				CHECK_END();
			}

			len = (int)(buf - pos);
			client->port = parse_port((const char *)pos, len);
		}
	}

	int fd;
	struct tcp_connection *remote;

	fd = connect_nonblocking(configuration.remote_addr, configuration.remote_port, 3000);
	if (slow(fd < 0)) {
		loge("connect to remote-proxy failed: %s", strerror(errno));
#if defined(__APPLE__)
		notify_post(REMOTE_PROXY_CONNCECT_FAILURE);
#endif
		return -1;
	}

	logi("Connected to remote-proxy (%s:%d)", configuration.remote_addr, configuration.remote_port);

	remote = new_tcp_connection(fd, BUFF_SIZE, recvfrom_remote_cb, sendto_remote_cb);
	remote->peer = client;
	client->peer = remote;
	el_watch(el, remote);

	uint8_t request[512];
	uint32_t req_len = SOCKS5_REQ_HEAD_SIZE;

	if (atyp != SOCKS5_ATYP_IPv6) {
		struct sockaddr_in sa;
    		if (inet_pton(AF_INET, client->host, &sa.sin_addr) == 1) {
			atyp = SOCKS5_ATYP_IPv4;
			memcpy(request + req_len, &sa.sin_addr.s_addr, 4);
			req_len += 4;
		} else {
			atyp = SOCKS5_ATYP_DONAME;
			uint8_t domain_name_len = (uint8_t)strlen(client->host);
			memcpy(request + req_len, &domain_name_len, 1);
			req_len += 1;
			memcpy(request + req_len, client->host, domain_name_len);
			req_len += domain_name_len;
		}
	} else {
		struct sockaddr_in6 sa;
		if (inet_pton(AF_INET6, client->host, &sa.sin6_addr) == 1) {
			memcpy(request + req_len, &sa.sin6_addr, 16);
			req_len += 16;
		} else {
			return -1;
		}
	}

	request[0] = version;
	request[1] = cmd;
	request[2] = rsv;
	request[3] = atyp;

	uint16_t port = (uint16_t)(client->port >> 8) | (uint16_t)(client->port << 8);
	memcpy(request + req_len, &port, 2);
	req_len += 2;

	uint8_t *ciphertext;
	uint32_t ciphertext_len;
	int ret = cryptor.encrypt(&cryptor, &ciphertext, &ciphertext_len, request, req_len);
	if (slow(ret < 0)) {
		loge("Encryption failure");
		return -1;
	}

	tcp_connection_append_txbuf(remote, ciphertext, ciphertext_len);

	free(ciphertext);

	data = remote->txbuf;
	data_len = remote->txbuf_length;
	ssize_t tx = send(remote->fd, data, data_len, 0);
	if (fast(tx > 0)) {
		tcp_connection_move_txbuf(remote, (uint32_t)tx);
		if ((uint32_t)tx == data_len) {
			remote->stage = STAGE_HANDSHAKE;
			client->stage = STAGE_STREAMING;
		} else {
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, remote->fd, remote);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, remote->fd, remote);
			return 0;
		} else {
			return -1;
		}
	}
}

static int stream_to_remote(struct el *el, struct tcp_connection *client, struct tcp_connection *remote)
{
	int ret;
	uint8_t *ciphertext;
	uint32_t ciphertext_len;
	uint8_t *data = client->rxbuf;
	uint32_t data_len = client->rxbuf_length;
	ssize_t tx;

	ret = cryptor.encrypt(&cryptor, &ciphertext, &ciphertext_len, data, data_len);
	if (slow(ret < 0)) {
		loge("Encryption failuer");
		return -1;
	}

	if (!remote)
		return -1;

	tcp_connection_append_txbuf(remote, ciphertext, (uint32_t)ciphertext_len);

	tcp_connection_reset_rxbuf(client);
	free(ciphertext);

	data = remote->txbuf;
	data_len = remote->txbuf_length;

	tx = send(remote->fd, data, data_len, 0);

	if (fast(tx > 0)) {
		if (fast(tx == data_len)) {
			tcp_connection_reset_txbuf(remote);
		} else {
			tcp_connection_move_txbuf(remote, (uint32_t)tx);
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, remote->fd, remote);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
			poller_unwatch_read(el->poller, client->fd, client);
			poller_watch_write(el->poller, remote->fd, remote);
			return 0;
		} else {
			return -1;
		}
	}
}

static int recvfrom_client_cb(struct el *el, struct tcp_connection *client)
{
	int ret = -1;
	struct tcp_connection *remote = NULL;

	while (1) {
		uint8_t buf[BUFF_SIZE];
		ssize_t rx = recv(client->fd, buf, BUFF_SIZE - 1, 0);
		if (fast(rx > 0)) {
			tcp_connection_append_rxbuf(client, buf, (uint32_t)rx);
			if (rx < BUFF_SIZE - 1)
				break;
		} else if (rx < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
				break;

			return -1;  /* error */
		} else {
			return -1;  /* eof */
		}
	}

	switch (client->stage) {
	case STAGE_HANDSHAKE:
		ret = handle_client_request(el, client);
		break;

	case STAGE_STREAMING:
		remote = client->peer;
		ret = stream_to_remote(el, client, remote);
		break;

	default:
		break;
	}

	return ret;
}

static int sendto_client_cb(struct el *el, struct tcp_connection *client)
{
	struct tcp_connection *remote = client->peer;
	uint8_t *data = client->txbuf;
	uint32_t data_len = client->txbuf_length;
	ssize_t tx = send(client->fd, data, data_len, 0);
	if (fast(tx > 0)) {
		if (fast((uint32_t)tx == data_len)) {
			tcp_connection_reset_txbuf(client);
		} else {
			tcp_connection_move_txbuf(client, (uint32_t)tx);
			poller_unwatch_write(el->poller, client->fd, client);
			poller_watch_read(el->poller, remote->fd, remote);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
			return 0;
		return -1;
	}
}

static int handle_handshake_response(struct el *el, struct tcp_connection *remote)
{
	int ret;
	struct tcp_connection *client = remote->peer;
	uint8_t *data = remote->rxbuf;
	uint32_t data_len = remote->rxbuf_length;
	uint32_t plaintext_len;
	uint8_t *plaintext;
	uint8_t reply[256];

	if (slow(data_len < 4))
		return 0;

	ret = cryptor.decrypt(&cryptor, &plaintext, &plaintext_len, data, data_len);
	if (slow(ret < 0)) {
		loge("Decryption failure");
		return -1;
	} else if (slow(ret == 0)) {
		logi("need more data");
		return 0;
	}

	tcp_connection_reset_rxbuf(remote);

	uint8_t ver = plaintext[0];
	uint8_t rsp = plaintext[1];
	uint8_t rsv = plaintext[2];
	uint8_t typ = plaintext[3];

	SHUTUP_WARNING(ver);
	SHUTUP_WARNING(rsp);
	SHUTUP_WARNING(rsv);

	if (typ == SOCKS5_ATYP_IPv4) {
		memcpy(reply, plaintext, SOCKS5_IPV4_REQ_SIZE);
		tcp_connection_append_txbuf(client, reply, SOCKS5_IPV4_REQ_SIZE);
	} else if (typ == SOCKS5_ATYP_DONAME) {
		uint8_t domain_name_len = (uint8_t)plaintext[SOCKS5_RSP_HEAD_SIZE];
		memcpy(reply, plaintext, SOCKS5_RSP_HEAD_SIZE + 1 + domain_name_len + SOCKS5_PORT_SIZE);
		tcp_connection_append_txbuf(client, reply,
                                    SOCKS5_RSP_HEAD_SIZE + 1 + domain_name_len + SOCKS5_PORT_SIZE);
	} else if (typ == SOCKS5_ATYP_IPv6) {
		memcpy(reply, plaintext, SOCKS5_IPV6_REQ_SIZE);
		tcp_connection_append_txbuf(client, reply, SOCKS5_IPV6_REQ_SIZE);
	} else {
		loge("Unknown address type: %d", typ);
		return -1;
	}

	free(plaintext);

	tcp_connection_reset_txbuf(client);

	client->stage = STAGE_STREAMING;
	remote->stage = STAGE_STREAMING;

	if (client->type == REQ_TYPE_HTTP)
		return stream_to_remote(el, client, remote);

	tcp_connection_append_txbuf(client, (uint8_t *)"HTTP/1.1 200 Connection Established\r\n\r\n", 39);

	data = client->txbuf;
	data_len = client->txbuf_length;
	
	ssize_t tx = send(client->fd, data, data_len, 0);

	if (fast(tx > 0)) {
		tcp_connection_reset_txbuf(client);
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
			poller_unwatch_read(el->poller, remote->fd, remote);
			poller_watch_write(el->poller, client->fd, client);
			return 0;
		} else {
			return -1;
		}
	}
}

static int stream_to_client(struct el *el, struct tcp_connection *remote)
{
	int ret;
	struct tcp_connection *client = remote->peer;
	uint8_t *data = NULL;
	uint32_t data_len = 0;
	uint32_t plaintext_len = 0;
	uint8_t *plaintext = NULL;
	ssize_t tx = 0;

	while (1) {
		data = remote->rxbuf;
		data_len = remote->rxbuf_length;

		if (slow(data_len < 4))
			return 0;

		ret = cryptor.decrypt(&cryptor, &plaintext, &plaintext_len, data, data_len);
		if (slow(ret < 0)) {
			loge("Decryption failure");
			return -1;
		} else if (slow(ret == 0)) {
			return 0;
		}

		tcp_connection_move_rxbuf(remote, 4 + plaintext_len);

		tcp_connection_append_txbuf(client, plaintext, plaintext_len);
		free(plaintext);
		data = client->txbuf;
		data_len = client->txbuf_length;
		tx = send(client->fd, data, data_len, 0);

		if (fast(tx > 0)) {
			if (fast(tx == data_len)) {
				tcp_connection_reset_txbuf(client);
			} else {
				tcp_connection_move_txbuf(client, (uint32_t)tx);
				poller_unwatch_read(el->poller, remote->fd, remote);
				poller_watch_write(el->poller, client->fd, client);
				return 0;
			}
		} else {
			if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
				poller_unwatch_read(el->poller, remote->fd, remote);
				poller_watch_write(el->poller, client->fd, client);
				return 0;
			}
			
			return -1;
		}
	}
}

static int recvfrom_remote_cb(struct el *el, struct tcp_connection *remote)
{
	int ret = -1;
	while (1) {
		uint8_t buf[BUFF_SIZE];
		ssize_t rx = recv(remote->fd, buf, BUFF_SIZE - 1, 0);
		if (fast(rx > 0)) {
			tcp_connection_append_rxbuf(remote, buf, (uint32_t)rx);
			switch (remote->stage) {
			case STAGE_HANDSHAKE:
				ret = handle_handshake_response(el, remote);
				break;
			case STAGE_STREAMING:
				ret = stream_to_client(el, remote);
				break;
			default:
				ret = -1;
				break;
			}
			if (rx < BUFF_SIZE - 1)
				break;
		} else if (rx < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
				break;
			return -1;
		} else {
			return -1;
		}
	}

	return ret;
}

static int sendto_remote_cb(struct el *el, struct tcp_connection *remote)
{
	struct tcp_connection *client = remote->peer;
	uint8_t *data = remote->txbuf;
	uint32_t data_len = remote->txbuf_length;
	ssize_t tx = send(remote->fd, data, data_len, 0);
	if (fast(tx > 0)) {
		if ((uint32_t)tx == data_len) {
			tcp_connection_reset_txbuf(remote);
		} else {
			tcp_connection_move_txbuf(remote, (uint32_t)tx);
			poller_unwatch_write(el->poller, remote->fd, remote);
			poller_watch_read(el->poller, client->fd, client);
		}
		return 0;
	} else {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
			return 0;
		return -1;
	}
}


static int server_fd = 0;

_Atomic int running = 0;
struct xproxy *xproxy = NULL;

int start_local_proxy(const char *local_address, uint16_t local_port,
		      const char *server_address, uint16_t server_port,
		      const char *password, const char *method)
{
	signals_init();
	coredump_init();
	crypt_setup();

	configuration.password = strdup(password);
	configuration.method = strdup(method);
	configuration.nthread = 6;
	configuration.local_addr = strdup(local_address);
	configuration.local_port = local_port;
	configuration.remote_addr = strdup(server_address);
	configuration.remote_port = server_port;
	configuration.maxfiles = 1024;

	if (cryptor_init(&cryptor, configuration.method, configuration.password) == -1) {
		loge("Unsupport method: %s", configuration.method);
		return ERR_UNSUPPORT_METHOD;
	}

	if (openfiles_init(configuration.maxfiles) != 0) {
		loge("Set max open files to %d failed: %s",
		      configuration.maxfiles, strerror(errno));
		return ERR_MAX_OPENFILES;
	}

	server_fd = listen_and_bind(configuration.local_addr, configuration.local_port);
	if (server_fd < 0) {
		loge("listen_and_bind(): %s", strerror(errno));
		return ERR_ADDRESS_IN_USE;
	}

	set_nonblocking(server_fd);

	xproxy = xproxy_new(server_fd, configuration.nthread, accept_cb);
	if (!xproxy) {
		close(server_fd);
		return ERR_SYSTEM;
	}

	logi("Listening on port %d", configuration.local_port);
	running = 1;
	xproxy_run(xproxy);

    return ERR_NONE;
}

void stop_local_proxy(void)
{
	running = 0;

	if (server_fd > 0)
		close(server_fd);
    
	if (xproxy)
		xproxy_free(xproxy);

	free(configuration.remote_addr);
	free(configuration.password);
	free(configuration.method);
	
	cryptor_deinit(&cryptor);
	crypt_cleanup();
}

#if defined(__APPLE__)
const char *remote_proxy_connect_failure_name(void)
{
	return REMOTE_PROXY_CONNCECT_FAILURE;
}
#endif

#if defined(HAS_MAIN)

static void usage(void)
{
	printf("Usage:\n");
	printf("    local-xproxy\n");
	printf("        -c <config>           Use configure file to start.\n");
	printf("        -b <local-address>    Local address to bind: 127.0.0.1 or 0.0.0.0.\n");
	printf("        -l <local-port>       Port number for listen.\n");
	printf("        -r <remote-address>   Host name or IP address of remote xproxy.\n");
	printf("        -p <remote-port>      Port number of remote xproxy.\n");
	printf("        -k <password>         Password.\n");
	printf("        [-e <method>]         Cipher suite: aes-128-cfb, aes-192-cfb, aes-256-cfb.\n");
	printf("        [-t <nthread>         I/O thread number. Defaults to 8.\n");
	printf("        [-m <max-open-files>  Max open files number. Defaults to 1024.\n");
	printf("        [-d]                  Debug mode, print debug information.\n");
	printf("        [-v]                  Print version info and quit.\n");
	printf("        [-h]                  Print this message and quit.\n");
	exit(-1);
}

int main(int argc, char **argv)
{
	int bflag = 0;
	int lflag = 0;
	int rflag = 0;
	int pflag = 0;
	int kflag = 0;
	int vflag = 0;  /* version */
	int cflag = 0;
	int hflag = 0;
	int ch;
	const char *conf_file;

	cfg_load_defaults(cfg_opts);

	while ((ch = getopt(argc, argv, "b:l:r:p:k:e:t:m:c:vhd")) != -1) {
		switch (ch) {
		case 'b':
			bflag = 1;
			configuration.local_addr = optarg;
			break;

		case 'l':
			lflag = 1;
			configuration.local_port = (uint16_t)atoi(optarg);
			break;

		case 'r':
			rflag = 1;
			configuration.remote_addr = optarg;
			break;

		case 'p':
			pflag = 1;
			configuration.remote_port = (uint16_t)atoi(optarg);
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

		case 'd':
			configuration.debug = 1;
			break;

		case '?':
		default:
			usage();
		}
	}

	argc -= optind;
	argv += optind;

	if (vflag) {
		return 0;
	}

	if (hflag)
		usage();

	/*  We load the config file first. */
	if (cflag) {
		cfg_load_file(conf_file, cfg_opts);
	} else {
		if (!bflag || !lflag || !rflag || !pflag || !kflag)
			usage();
	}

	signals_init();
	coredump_init();
	crypt_setup();

	if (cryptor_init(&cryptor, configuration.method, configuration.password) == -1) {
		loge("Unsupport method: %s", configuration.method);
		return -1;
	}

	if (openfiles_init(configuration.maxfiles) != 0) {
		loge("Set max open files to %d failed: %s", configuration.maxfiles, strerror(errno));
		return -1;
	}

	int sfd = listen_and_bind(configuration.local_addr, configuration.local_port);
	if (sfd < 0) {
		loge("listen_and_bind(): %s", strerror(errno));
		return -1;
	}

	logi("Listening on port %d", configuration.local_port);
	running = 1;
	xproxy = xproxy_new(sfd, configuration.nthread, accept_cb);
	if (!xproxy)
		goto cleanup;

	xproxy_run(xproxy);

cleanup:
	if (sfd)
		close(sfd);

	if (xproxy)
		xproxy_free(xproxy);

	cryptor_deinit(&cryptor);
	crypt_cleanup();

	return 0;
}

#endif

