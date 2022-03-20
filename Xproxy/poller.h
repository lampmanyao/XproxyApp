#ifndef poller_h
#define poller_h

#include <stdbool.h>

struct poller_event {
	bool read;
	bool write;
	bool eof;
	bool error;
	void *ptr;
};

int poller_open(void);
void poller_close(int poller);

int poller_wait(int poller, struct poller_event *e, int max, int ms);

int poller_watch(int poller, int fd, void *ud);
int poller_watch_read(int poller, int fd, void *ud);
int poller_watch_write(int poller, int fd, void *ud);
int poller_unwatch(int poller, int fd, void *ud);
int poller_unwatch_read(int poller, int fd, void *ud);
int poller_unwatch_write(int poller, int fd, void *ud);

#endif  /* poller_h */

