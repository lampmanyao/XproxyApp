#ifndef utils_h
#define utils_h

#include <pthread.h>
#include <openssl/crypto.h>

/*
 * See GCC-5.2 manual
 * 6.57 Other Built-in Functions Provided by GCC
 *  long __builtin_expect (long exp, long c)
 * for more details.
 */

#if defined(__GUN__) || defined(__llvm__)
# define fast(x) __builtin_expect(!!(x), 1)
# define slow(x) __builtin_expect(!!(x), 0)
#else
# define fast(x) (x)
# define slow(x) (x)
#endif

#define SHUTUP_WARNING(x) (void)(x);

void set_recv_buffer_size(int fd, int size);
void set_send_buffer_size(int fd, int size);
int set_nonblocking(int fd);
int listen_and_bind(const char * address, uint16_t port);
int connect_nonblocking(const char *host, uint16_t port, int ms);
int connect6_nonblocking(const char *address, uint16_t port, int ms);
void wait_milliseconds(int milliseconds);
long gettime(void);

void oom(size_t size);
int online_cpus(void);
int bind_to_cpu(pthread_t tid, int cpuid);
int bound_cpuid(pthread_t tid);
void coredump_init(void);
int openfiles_init(long);
void signals_init(void);

const char *openssl_version(void);
const char *openssl_built_on(void);

void create_shared_file(const char *path);

#endif  /* utils_h */

