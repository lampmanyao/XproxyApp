#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <strings.h>

#include "platform.h"
#include "xproxy.h"
#include "utils.h"
#include "tcp-connection.h"
#include "poller.h"
#include "log.h"

#define CPUID_MASK 127

extern int running;

struct xproxy *xproxy_new(int sfd, int nthread, accept_callback accept_cb)
{
	struct xproxy *xproxy = NULL;

	int poller = poller_open();
	if (poller == -1)
		return NULL;

	size_t size = sizeof(struct xproxy) + (size_t)nthread * sizeof(struct el *);

	xproxy = malloc(size);
	if (!xproxy)
		oom(size);

	xproxy->nthread = nthread;
	xproxy->poller = poller;
	xproxy->sfd = sfd;
	poller_watch(xproxy->poller, xproxy->sfd, NULL);

	xproxy->accept_cb = accept_cb;
	for (int i = 0; i < nthread; i++)
		xproxy->els[i] = el_new();

	return xproxy;
}

#ifndef HAS_MAIN
static void *_accept_thread(void *arg)
{
	struct xproxy *xproxy = (struct xproxy *)arg;

	while (running) {
		struct poller_event ev[128];
		int n = poller_wait(xproxy->poller, ev, 128, 1000);
		for (int i = 0; i < n; ++i) {
			if (ev[i].read) {
				xproxy->accept_cb(xproxy);
			}
		}

		if (n == -1) {
			if (errno == EINTR)
				continue;
			break;
		}
	}

	return NULL;
}
#endif

void xproxy_run(struct xproxy *xproxy)
{
	int cpus = online_cpus();

	for (int i = 0; i < xproxy->nthread; i++) {
		el_run(xproxy->els[i]);
		bind_to_cpu(xproxy->els[i]->tid, i % cpus);
	}

#if defined(HAS_MAIN)
	while (running) {
		struct poller_event ev[128];
		int n = poller_wait(xproxy->poller, ev, 128, 1000);
		for (int i = 0; i < n; ++i) {
			if (ev[i].read) {
				xproxy->accept_cb(xproxy);
			}
		}

		if (n == -1) {
			if (errno == EINTR)
				continue;
			break;
		}
	}
#else
	pthread_create(&xproxy->tid, NULL, _accept_thread, xproxy);
#endif
}

void xproxy_free(struct xproxy *xproxy)
{
	pthread_join(xproxy->tid, NULL);
	for (int i = 0; i < xproxy->nthread; i++) {
		pthread_join(xproxy->els[i]->tid, NULL);
		el_free(xproxy->els[i]);
	}
	free(xproxy);
}

