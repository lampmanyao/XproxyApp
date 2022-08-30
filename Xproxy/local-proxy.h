//
//  local-proxy.h
//  Xproxy
//
//  Created by lampman on 2022/3/10.
//

#ifndef local_proxy_h
#define local_proxy_h

#if defined(__APPLE__)
#include <mach/message.h>
#include <notify.h>
#define REMOTE_PROXY_CONNCECT_FAILURE "Cannot connect to remote-proxy"
const char *remote_proxy_connect_failure_name(void);
#endif

extern struct xproxy *xproxy;

enum {
	ERR_UNSUPPORT_METHOD = -4,
	ERR_MAX_OPENFILES    = -3,
	ERR_ADDRESS_IN_USE   = -2,
	ERR_SYSTEM           = -1,
	ERR_NONE             = 0,
};

int start_local_proxy(const char *address, uint16_t port, const char *password, const char *method);
void stop_local_proxy(void);

#endif /* local_proxy_h */

