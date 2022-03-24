#ifndef crypt_h
#define crypt_h

#include <stdint.h>
#include <stddef.h>

#include <openssl/evp.h>

#define AES_128_CFB_METHOD 0
#define AES_192_CFB_METHOD 1
#define AES_256_CFB_METHOD 2

void crypt_setup(void);
void crypt_cleanup(void);

struct cryptor {
	int method;
	uint8_t *key;
	int key_size;
	uint8_t *iv;
	int iv_size;
	const EVP_CIPHER *evp_cipher;
	int (*encrypt)(struct cryptor *, uint8_t **, uint32_t *, const uint8_t *, uint32_t);
	int (*decrypt)(struct cryptor *, uint8_t **, uint32_t *, const uint8_t *, uint32_t);
};

int cryptor_init(struct cryptor *c, const char *method, const char *password);
void cryptor_deinit(struct cryptor *c);

EVP_CIPHER_CTX *new_encrypt_cipher_ctx(struct cryptor *c);
EVP_CIPHER_CTX *new_decrypt_cipher_ctx(struct cryptor *c);

#endif  /* crypt_h */

