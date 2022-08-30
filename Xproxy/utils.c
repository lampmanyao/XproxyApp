#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <fcntl.h>
#include <signal.h>
#include <netdb.h>
#include <poll.h>
#include <errno.h>
#include <string.h>
#include <strings.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>

#if defined(__APPLE__)
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/thread_act.h>
#endif

#include "utils.h"
#include "log.h"

#define BACKLOG 65535

int set_nonblocking(int fd)
{
	int flags = fcntl(fd, F_GETFL, 0);
	if (flags == -1)
		return -1;

	return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int listen_and_bind(const char *address, uint16_t port)
{
	int sfd;
    int reuse = 1;
    int on = 5;
	struct sockaddr_in serv_addr;

	sfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sfd == -1) {
		loge("socket(): %s", strerror(errno));
		return -1;
	}
    
    setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &reuse, (socklen_t)sizeof(reuse));
    setsockopt(sfd, SOL_SOCKET, SO_REUSEPORT, &reuse, (socklen_t)sizeof(reuse));
    setsockopt(sfd, IPPROTO_TCP, TCP_FASTOPEN, &on, sizeof(on));

	bzero(&serv_addr, sizeof(struct sockaddr_in));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = inet_addr(address);
	serv_addr.sin_port = htons(port);

	if (bind(sfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) == -1) {
		loge("bind(): %s", strerror(errno));
		close(sfd);
		return -1;
	}

	set_nonblocking(sfd);

	if (listen(sfd, BACKLOG) == -1) {
		loge("listen(): %s", strerror(errno));
		close(sfd);
		return -1;
	}

	return sfd;
}

static int _connect(int fd, const struct sockaddr *address, socklen_t address_len, int ms)
{
	int ret, nready, error = 0;
	socklen_t len;
	struct pollfd pollfd;

	ret = connect(fd, address, address_len);
	if (ret == 0)
		return 0;

	if (ret < 0 && errno != EINPROGRESS)
		return -1;

	pollfd.fd = fd;
	pollfd.events = POLLIN | POLLOUT;

	nready = poll(&pollfd, 1, ms);
	if (nready <= 0)
		return -1;

	len = sizeof(error);
	if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len) < 0)
		return -1;

	if (error) {
		errno = error;
		return -1;
	}

	errno = 0;
	return 0;
}

int connect_nonblocking(const char *host, uint16_t port, int ms)
{
	struct sockaddr_in ipv4addr;
	struct addrinfo hints;
	struct addrinfo *result;
	struct addrinfo *rp;
	int sock = -1;

	/* Check the host parameter whether is an IP address first. */
	if (inet_aton(host, &ipv4addr.sin_addr) == 1) {
		sock = socket(AF_INET, SOCK_STREAM, 0);
		if (slow(sock == -1))
			return -1;

		set_nonblocking(sock);

		ipv4addr.sin_family = AF_INET;
		ipv4addr.sin_port = htons(port);

		if (_connect(sock, (const struct sockaddr*)&ipv4addr, sizeof(struct sockaddr), ms) == 0)
			return sock;

		close(sock);
		return -1;
	}

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;

	char portptr[6];
	snprintf(portptr, 6, "%d", port);

	if (getaddrinfo(host, portptr, &hints, &result) != 0)
		return -1;

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		sock = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
		if (slow(sock == -1))
			continue;

		set_nonblocking(sock);

		if (_connect(sock, rp->ai_addr, rp->ai_addrlen, ms) == 0)
			break;

		close(sock);
		continue;
	}

	freeaddrinfo(result);
	return (rp == NULL) ? -1 : sock;
}

int connect6_nonblocking(const char *address, uint16_t port, int ms)
{
	struct sockaddr_in6 sa;
	int sock = -1;

	sock = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	if (slow(sock == -1))
		return -1;

	set_nonblocking(sock);

	sa.sin6_family = AF_INET6;
	inet_pton(AF_INET6, address, &sa.sin6_addr);
	sa.sin6_port = htons(port);

	if (_connect(sock, (const struct sockaddr*)&sa, sizeof(sa), ms) == 0)
		return sock;

	close(sock);
	return -1;
}

void wait_milliseconds(int milliseconds)
{
	poll(NULL, 0, milliseconds);
}

void oom(size_t size)
{
	fprintf(stderr, "Out of memory trying to allocate %lu bytes.\n", size);
	fflush(stderr);
	abort();
}

inline int online_cpus(void)
{
	int cores = (int)sysconf(_SC_NPROCESSORS_ONLN);
	return cores > 0 ? cores : 1;
}

inline int bind_to_cpu(pthread_t tid, int cpuid)
{
#if defined(__APPLE__)
	mach_port_t mach_tid = pthread_mach_thread_np(tid);
	thread_affinity_policy_data_t policy = { cpuid };
	thread_policy_set(mach_tid, THREAD_AFFINITY_POLICY,
			  (thread_policy_t)&policy, 1);
	return 0;
#else
	cpu_set_t mask;
	CPU_ZERO(&mask);
	CPU_SET(cpuid, &mask);
	return pthread_setaffinity_np(tid, sizeof(mask), &mask);
#endif
}

inline int bound_cpuid(pthread_t tid)
{
#if defined(__APPLE__)
	mach_port_t mach_tid = pthread_mach_thread_np(tid);
	thread_affinity_policy_data_t policy;
	mach_msg_type_number_t count;
	boolean_t get_default = 0;
	thread_policy_get(mach_tid, THREAD_AFFINITY_POLICY,
			  (thread_policy_t)&policy, &count, &get_default);
	return policy.affinity_tag;
#else
	cpu_set_t mask;
	CPU_ZERO(&mask);
	pthread_getaffinity_np(tid, sizeof(mask), &mask);
	int cpus = online_cpus();
	for (int i = 0; i < cpus; i++) {
		if (CPU_ISSET(i, &mask)) {
			return i;
		}
	}
	return -1;
#endif
}

inline long gettime(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec * 1000000 + tv.tv_usec;
}

void coredump_init(void)
{
	struct rlimit rlimit;
	rlimit.rlim_cur = RLIM_INFINITY;
	rlimit.rlim_max = RLIM_INFINITY;
	setrlimit(RLIMIT_CORE, &rlimit);
}

int openfiles_init(long max_open_files)
{
	long max = max_open_files;
	long sc_open_max = sysconf(_SC_OPEN_MAX);

	if (max_open_files > sc_open_max)
		max = sc_open_max;

	struct rlimit rlimit;
	rlimit.rlim_cur = (unsigned long long)max;
	rlimit.rlim_max = (unsigned long long)max;
	return setrlimit(RLIMIT_NOFILE, &rlimit);
}

void signals_init(void)
{
	signal(SIGHUP, SIG_IGN);
	signal(SIGPIPE, SIG_IGN);  /* avoid send() crashes */
	signal(SIGTTOU, SIG_IGN);
	signal(SIGTTIN, SIG_IGN);
	signal(SIGCHLD, SIG_IGN);
	signal(SIGTERM, SIG_IGN);
}

const char *openssl_version(void)
{
	return OpenSSL_version(OPENSSL_VERSION);
}

const char *openssl_built_on(void)
{
	return OpenSSL_version(OPENSSL_BUILT_ON);
}

