//
//  statstic.c
//  Xproxy
//
//  Created by lampman on 12/13/24.
//

#include "statstic.h"
#include "log.h"

#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>

struct statstic *statstic_new(const char *shared_sent_path, const char *shared_recv_path)
{
	int sfd = 0;
	int rfd = 0;
	struct statstic *stat = NULL;
	stat = malloc(sizeof(*stat));

	if (shared_sent_path) {
		sfd = open(shared_sent_path, O_CREAT | O_RDWR);
		if (sfd < 0) {
			loge("Can not open file: %s, errno: %d (%s)", shared_sent_path, errno, strerror(errno));
			stat->sent_bytes_shared_mem_used = 0;
		} else {
			stat->sent_bytes = mmap(NULL, sizeof(uint64_t), PROT_READ | PROT_WRITE, MAP_SHARED, sfd, 0);
			if (stat->sent_bytes == MAP_FAILED) {
				loge("mmap() failed, errno: %d (%s)", errno, strerror(errno));
				stat->sent_bytes_shared_mem_used = 0;
			} else {
				stat->sent_bytes_shared_mem_used = 1;
			}
		}
	} else {
		stat->sent_bytes_shared_mem_used = 0;
	}

	if (shared_recv_path) {
		rfd = open(shared_recv_path, O_CREAT | O_RDWR);
		if (rfd < 0) {
			loge("Can not open file: %s, errno: %d (%s)", shared_recv_path, errno, strerror(errno));
			stat->recv_bytes_shared_mem_used = 0;
		} else {
			stat->recv_bytes = mmap(NULL, sizeof(uint64_t), PROT_READ | PROT_WRITE, MAP_SHARED, rfd, 0);
			if (stat->recv_bytes == MAP_FAILED) {
				loge("mmap() failed, errno: %d (%s)", errno, strerror(errno));
				stat->recv_bytes_shared_mem_used = 0;
			} else {
				stat->recv_bytes_shared_mem_used = 1;
			}
		}
	} else {
		stat->recv_bytes_shared_mem_used = 0;
	}

	if (!stat->sent_bytes_shared_mem_used) {
		stat->sent_bytes = malloc(sizeof(uint64_t));
	}

	if (!stat->recv_bytes_shared_mem_used) {
		stat->recv_bytes = malloc(sizeof(uint64_t));
	}

	*stat->sent_bytes = 0;
	*stat->recv_bytes = 0;

	if (sfd > 0) {
		close(sfd);
	}
	if (rfd > 0) {
		close(rfd);
	}
	return stat;
}

void statstic_free(struct statstic *stat)
{
	if (stat->sent_bytes_shared_mem_used) {
		munmap(stat->sent_bytes, sizeof(uint64_t));
	} else {
		free(stat->sent_bytes);
	}

	if (stat->recv_bytes_shared_mem_used) {
		munmap(stat->recv_bytes, sizeof(uint64_t));
	} else {
		free(stat->recv_bytes);
	}
	free(stat);
}


