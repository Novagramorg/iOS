/*
 * TweetNaCl declares `randombytes` extern and leaves it to the integrator.
 *
 * Backed by arc4random_buf, which is the platform CSPRNG on Darwin, cannot fail,
 * and needs no error handling — unlike SecRandomCopyBytes, which returns a status
 * TweetNaCl's void signature gives us nowhere to report.
 */
#include <stdlib.h>

void randombytes(unsigned char *buffer, unsigned long long length) {
    arc4random_buf(buffer, (size_t)length);
}
