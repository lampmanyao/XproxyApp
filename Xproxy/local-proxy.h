//
//  local-proxy.h
//  Xproxy
//
//  Created by lampman on 2022/3/10.
//

#ifndef local_proxy_h
#define local_proxy_h

int start_local_proxy(const char *address, uint16_t port, const char *password, const char *method);
void stop_local_proxy(void);

#endif /* local_proxy_h */

