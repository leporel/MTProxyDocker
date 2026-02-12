// Compatibility shims for musl libc which lacks several glibc extensions.
// On glibc this header is a no-op.
#ifndef MUSL_COMPAT_H
#define MUSL_COMPAT_H

#ifndef __GLIBC__

#include <stdlib.h>
#include <unistd.h>

// execinfo.h stubs — backtrace is not available in musl
static inline int backtrace(void **buffer, int size) {
  (void)buffer; (void)size;
  return 0;
}
static inline void backtrace_symbols_fd(void *const *buffer, int size, int fd) {
  (void)buffer; (void)size;
  write(fd, "(backtrace unavailable on musl)\n", 31);
}

struct drand48_data {
  unsigned short __x[3];
  unsigned short __old_x[3];
  unsigned short __c;
  unsigned short __init;
  unsigned long long __a;
};

static inline int srand48_r(long int seedval, struct drand48_data *buf) {
  (void)buf;
  srand48(seedval);
  return 0;
}

static inline int lrand48_r(struct drand48_data *buf, long int *result) {
  (void)buf;
  *result = lrand48();
  return 0;
}

static inline int mrand48_r(struct drand48_data *buf, long int *result) {
  (void)buf;
  *result = mrand48();
  return 0;
}

static inline int drand48_r(struct drand48_data *buf, double *result) {
  (void)buf;
  *result = drand48();
  return 0;
}

#endif // __GLIBC__
#endif // MUSL_COMPAT_H
