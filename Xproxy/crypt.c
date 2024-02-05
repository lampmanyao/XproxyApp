#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <pthread.h>
#include <openssl/md5.h>
#include <openssl/ssl.h>
#include <openssl/evp.h>
#include <openssl/err.h>

#include "crypt.h"
#include "utils.h"
#include "log.h"

/*
 * Using openssl in multi-threaded applications:
 * https://www.openssl.org/blog/blog/2017/02/21/threads/
 */
#if (OPENSSL_VERSION_NUMBER <= 0x10002000l)
static pthread_mutex_t *lock_cs;
static long *lock_count;

static void pthreads_locking_callback(int mode, int type, char *file, int line)
{
	SHUTUP_WARNING(file);
	SHUTUP_WARNING(line);
	if (mode & CRYPTO_LOCK) {
		pthread_mutex_lock(&lock_cs[type]);
		lock_count[type]++;
	} else {
		pthread_mutex_unlock(&lock_cs[type]);
	}
}

static unsigned long pthreads_thread_id(void)
{
	unsigned long ret = (unsigned long)pthread_self();
	return ret;
}
#endif

void crypt_setup(void)
{
/*
 * SSL_library_init() and OpenSSL_add_all_algorithms() were deprecated since 1.1.0
 */
#if (OPENSSL_VERSION_NUMBER < 0x10100000l)
	SSL_library_init();
	OpenSSL_add_all_algorithms();
	SSL_load_error_strings();
#else
	if (OPENSSL_init_ssl(OPENSSL_INIT_ENGINE_ALL_BUILTIN, NULL) != 1)
		logf("openssl init failed");
#endif

#if (OPENSSL_VERSION_NUMBER <= 0x10002000l)
	int num_locks = CRYPTO_num_locks();

	lock_cs = OPENSSL_malloc((size_t)num_locks * sizeof(pthread_mutex_t));
	lock_count = (long *)OPENSSL_malloc((size_t)num_locks * sizeof(long));

	if (!lock_cs || !lock_count) {
		if (lock_cs)
			OPENSSL_free(lock_cs);

		if (lock_count)
			OPENSSL_free(lock_count);

		return;
	}

	for (int i = 0; i < num_locks; i++) {
		lock_count[i] = 0;
		pthread_mutex_init(&lock_cs[i], NULL);
	}

	CRYPTO_set_id_callback((unsigned long (*)())pthreads_thread_id);
	CRYPTO_set_locking_callback((void (*)(int, int, const char *, int))pthreads_locking_callback);
#endif
}

void crypt_cleanup(void)
{
#if (OPENSSL_VERSION_NUMBER <= 0x10002000l)
	CRYPTO_set_locking_callback(NULL);
	for (int i = 0; i < CRYPTO_num_locks(); i++)
		pthread_mutex_destroy(&(lock_cs[i]));

	OPENSSL_free(lock_cs);
	OPENSSL_free(lock_count);
#endif

#if (OPENSSL_VERSION_NUMBER < 0x10100000l)
	ERR_free_strings();
#endif
}

static int encrypt_cfb(struct cryptor *c, uint8_t **outbuf, uint32_t *outlen, const uint8_t *inbuf, uint32_t inlen);
static int decrypt_cfb(struct cryptor *c, uint8_t **outbuf, uint32_t *outlen, const uint8_t *inbuf, uint32_t inlen);


static void generate_key(uint8_t *key, int key_size, const char *password)
{
	int i, j;
	uint8_t buffer[MD5_DIGEST_LENGTH] = {0};
	MD5_CTX md5_ctx;
	MD5_Init(&md5_ctx);
	MD5_Update(&md5_ctx, password, strlen(password));
	MD5_Final(buffer, &md5_ctx);

	i = MD5_DIGEST_LENGTH;
	j = 0;

	while (i--)
		key[i] = buffer[j++];

	j = 0;
	for (i = MD5_DIGEST_LENGTH; i < key_size; i++)
		key[i] = buffer[j++];

	key[key_size] = '\0';
}

static void generate_iv(uint8_t *iv, int iv_size, const uint8_t *str, unsigned long len)
{
	int i;
	uint8_t buffer[MD5_DIGEST_LENGTH] = {0};
	MD5_CTX md5_ctx;
	MD5_Init(&md5_ctx);
	MD5_Update(&md5_ctx, str, len);
	MD5_Final(buffer, &md5_ctx);

	for (i = 0; i < MD5_DIGEST_LENGTH; i++)
		iv[i] = buffer[i];

	while (i++ < iv_size - 1)
		iv[i] = buffer[i - MD5_DIGEST_LENGTH];
}

struct cipher {
	const char *name;
	int method;
	int key_size;
	int iv_size;
	int (*encrypt)(struct cryptor *, uint8_t **, uint32_t *, const uint8_t *, uint32_t);
	int (*decrypt)(struct cryptor *, uint8_t **, uint32_t *, const uint8_t *, uint32_t);
};

static struct cipher ciphers[] = {
	/* name         method              key_size iv_size encrypt_cb   decrypt_cb */
	{"aes-128-cfb", AES_128_CFB_METHOD, 16,      16,     encrypt_cfb, decrypt_cfb},
	{"aes-192-cfb", AES_192_CFB_METHOD, 24,      24,     encrypt_cfb, decrypt_cfb},
	{"aes-256-cfb", AES_256_CFB_METHOD, 32,      32,     encrypt_cfb, decrypt_cfb},
	{NULL,          0,                  0,       0,      NULL,            NULL}
};

int cryptor_init(struct cryptor *c, const char *method, const char *password)
{
	assert(c != NULL);
	assert(method != NULL);
	assert(password != NULL);

	const struct cipher* cipher = ciphers;

	while (cipher->name) {
		if (strncmp(cipher->name, method, strlen(method)) == 0)
			break;
		cipher++;
	}

	if (!cipher->name)
		return -1;

	c->method = cipher->method;
	c->key = malloc((size_t)cipher->key_size + 1);
	c->key_size = cipher->key_size;
	generate_key(c->key, c->key_size, password);

	c->iv = malloc((size_t)cipher->iv_size);
	c->iv_size = cipher->iv_size;
	generate_iv(c->iv, c->iv_size, c->key, (unsigned long)cipher->key_size);

	c->encrypt = cipher->encrypt;
	c->decrypt = cipher->decrypt;

	if (c->method == AES_128_CFB_METHOD)
		c->evp_cipher = EVP_aes_128_cfb();
	else if (c->method == AES_192_CFB_METHOD)
		c->evp_cipher = EVP_aes_192_cfb();
	else if (c->method == AES_256_CFB_METHOD)
		c->evp_cipher = EVP_aes_256_cfb();

	return 0;
}

void cryptor_deinit(struct cryptor *c)
{
	assert(c != NULL);
	free(c->key);
	free(c->iv);
}

EVP_CIPHER_CTX *new_encrypt_cipher_ctx(struct cryptor *c)
{
	EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
	if (!ctx)
		return NULL;

	if (EVP_EncryptInit_ex(ctx, c->evp_cipher, NULL,
			       (const uint8_t *)c->key,
			       (const uint8_t *)c->iv) != 1) {
		EVP_CIPHER_CTX_free(ctx);
		return NULL;
	}

	return ctx;
}

EVP_CIPHER_CTX *new_decrypt_cipher_ctx(struct cryptor *c)
{
	EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
	if (!ctx)
		return NULL;

	if (EVP_DecryptInit_ex(ctx, c->evp_cipher, NULL,
			       (const uint8_t *)c->key,
			       (const uint8_t *)c->iv) != 1) {
		EVP_CIPHER_CTX_free(ctx);
		return NULL;
	}

	return ctx;
}

static int encrypt_cfb(struct cryptor *c, uint8_t **outbuf, uint32_t *outlen,
			const uint8_t *inbuf, uint32_t inlen)
{
	EVP_CIPHER_CTX *ctx = new_encrypt_cipher_ctx(c);
	if (!ctx) {
		return -1;
	}

	int len = 0;
	*outlen = 0;
	*outbuf = malloc(inlen + EVP_MAX_BLOCK_LENGTH);

	/* encrypt the inlen to the first 4 bytes of outbuf */
	if (EVP_EncryptUpdate(ctx, *outbuf, &len, (const uint8_t *)&inlen, sizeof(uint32_t)) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}

	if (EVP_EncryptUpdate(ctx, *outbuf + sizeof(uint32_t), &len, inbuf, (int)inlen) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}

	*outlen = len;
	if (EVP_EncryptFinal_ex(ctx, *outbuf + sizeof(uint32_t) + len, &len) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}

	*outlen += len + sizeof(uint32_t);
	EVP_CIPHER_CTX_free(ctx);

	return *outlen;
}

static int decrypt_cfb(struct cryptor *c, uint8_t **outbuf, uint32_t *outlen,
			const uint8_t *inbuf, uint32_t inlen)
{
	EVP_CIPHER_CTX *ctx = new_decrypt_cipher_ctx(c);
	if (!ctx)
		return -1;
	
	uint32_t encrypted_len = 0;
	int len = 0;
	*outlen = 0;
	*outbuf = malloc(inlen + EVP_MAX_BLOCK_LENGTH);

	/* need 4 bytes at least to decrypte */
	if (slow(inlen < sizeof(uint32_t))) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return 0;
	}

	if (EVP_DecryptUpdate(ctx, (uint8_t *)&encrypted_len, &len, inbuf, sizeof(uint32_t)) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}


	/* need more data to decrypt */
	if (encrypted_len > inlen - sizeof(uint32_t)) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return 0;
	}

	if (EVP_DecryptUpdate(ctx, *outbuf, &len, inbuf + sizeof(uint32_t), (int)encrypted_len) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}

	*outlen = len;
	if (EVP_DecryptFinal_ex(ctx, *outbuf + len, &len) != 1) {
		free(*outbuf);
		EVP_CIPHER_CTX_free(ctx);
		return -1;
	}

	*outlen += len;
	EVP_CIPHER_CTX_free(ctx);

	return *outlen;
}

