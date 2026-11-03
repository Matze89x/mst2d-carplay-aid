#ifndef DCC_RESOLVE_H
#define DCC_RESOLVE_H

#include "dcc_qnx.h"

/* Finding the "real" function behind an interposed one (open, spawn, AES_CBCFrame_Init, ...).
 *
 * Both helpers return NULL when nothing is found. A caller must never call a NULL pointer (jump to address 0, signal 11
 * with ip 0): every caller checks the result. Neither helper can return the caller's own interposer: RTLD_NEXT starts
 * behind the calling library, and dlsym on a named library searches only that library and its dependencies.
 *
 * dcc_next_symbol: dlsym(RTLD_NEXT). RTLD_NEXT is (void *)-3 in the QNX 6.5 <dlfcn.h>; the earlier value (void *)-1
 *   made dlsym return NULL, and the unchecked call crashed the NavigationServer at startup in the first test in a car.
 * dcc_library_symbol: fallback through an explicitly named library, for the case that RTLD_NEXT does not find it from a
 *   preloaded library. Do not call it from inside open/close/write: dlopen may use those itself.
 */
static inline void *dcc_next_symbol(const char *name)
{
    return dlsym(RTLD_NEXT, name);
}

static inline void *dcc_library_symbol(const char *library, const char *name)
{
    void *handle = dlopen(library, RTLD_LAZY);
    return handle ? dlsym(handle, name) : NULL;
}

#endif
