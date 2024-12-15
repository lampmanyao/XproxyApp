//
//  statstic.h
//  Xproxy
//
//  Created by lampman on 12/13/24.
//

#ifndef statstic_h
#define statstic_h

#include <stdint.h>

struct statstic {
	int sent_bytes_shared_mem_used;
	int recv_bytes_shared_mem_used;
	uint64_t *sent_bytes;
	uint64_t *recv_bytes;
};

struct statstic *statstic_new(const char *shared_sent_path, const char *shared_recv_path);
void statstic_free(struct statstic *statstic);

#endif /* statstic_h */
