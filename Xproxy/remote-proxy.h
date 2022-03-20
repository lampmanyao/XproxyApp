#ifndef remote_proxy_h
#define remote_proxy_h

int start_remote_proxy(const char *address, uint16_t port, const char *password, const char *method);
void stop_remote_proxy(void);

#endif  /* remote_proxy_h */
