#ifndef tcp_connection_h
#define tcp_connection_h

#include <stdint.h>
#include <stddef.h>

struct el;
struct tcp_connection;

typedef int (*recv_callback) (struct el *, struct tcp_connection *);
typedef int (*send_callback) (struct el *, struct tcp_connection *);

#define REQ_TYPE_UNKNOWN (-1)
#define REQ_TYPE_HTTP    (0)
#define REQ_TYPE_HTTPS   (1)

#define STAGE_HANDSHAKE 0
#define STAGE_STREAMING 1

struct tcp_connection {
	struct tcp_connection *peer;

	int fd;
	int stage: 28;
	int type: 4;

	uint8_t *rxbuf;
	uint32_t rxbuf_capacity;
	uint32_t rxbuf_length;

	uint8_t *txbuf;
	uint32_t txbuf_capacity;
	uint32_t txbuf_length;

	recv_callback recv_cb;
	send_callback send_cb;

	uint16_t port;
	char host[256];
};

struct tcp_connection *new_tcp_connection(int, uint32_t, recv_callback, send_callback);
void free_tcp_connection(struct tcp_connection *);

void tcp_connection_append_rxbuf(struct tcp_connection *, const uint8_t *, uint32_t);
void tcp_connection_append_txbuf(struct tcp_connection *, const uint8_t *, uint32_t);

void tcp_connection_reset_rxbuf(struct tcp_connection *);
void tcp_connection_reset_txbuf(struct tcp_connection *);

void tcp_connection_move_rxbuf(struct tcp_connection *, uint32_t);
void tcp_connection_move_txbuf(struct tcp_connection *, uint32_t);

#endif  /* tcp_connection_h */

