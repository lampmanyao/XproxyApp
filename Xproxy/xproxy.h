#ifndef xproxy_h
#define xproxy_h

#include <pthread.h>
#include <stdatomic.h>

#include "el.h"
#include "statstic.h"

struct xproxy;
typedef void (*accept_callback) (struct xproxy *xproxy);

struct xproxy {
	pthread_t tid;
	int nthread;
	int sfd;
	int poller;
	accept_callback accept_cb;
	struct statstic *stat;
	struct el *els[0];

};

struct xproxy *xproxy_new(int sfd, int nthread, accept_callback accept_cb, const char *shared_sent_path, const char *shared_recv_path);
void xproxy_free(struct xproxy *);
void xproxy_run(struct xproxy *);

#endif  /* xproxy_h */

