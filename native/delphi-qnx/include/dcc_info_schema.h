#ifndef DCC_INFO_SCHEMA_H
#define DCC_INFO_SCHEMA_H

#include "dcc_qnx.h"

/* Core Foundation types of the stock AirPlay plug-in (opaque here). */
typedef const void *CFTypeRef;
typedef const void *CFStringRef;
typedef const void *CFDictionaryRef;
typedef void *CFMutableDictionaryRef;
typedef const void *CFArrayRef;
typedef void *CFMutableArrayRef;
typedef long CFIndex;
typedef int32_t OSStatus;
typedef unsigned char Boolean;

/* The CF functions the schema code needs, resolved by the caller (airplay_hook.c) or faked by the host test. */
typedef struct {
    CFStringRef (*string)(void *, const char *, uint32_t);
    void (*release)(CFTypeRef);
    CFTypeRef (*dict_get)(CFDictionaryRef, CFTypeRef);
    void (*dict_set)(CFMutableDictionaryRef, CFTypeRef, CFTypeRef);
    void (*dict_set_i64)(CFMutableDictionaryRef, CFTypeRef, int64_t);
    CFIndex (*dict_count)(CFDictionaryRef);
    void (*dict_pairs)(CFDictionaryRef, const void **, const void **);
    CFMutableDictionaryRef (*dict_new)(void *, CFIndex, const void *, const void *);
    CFIndex (*array_count)(CFArrayRef);
    CFTypeRef (*array_get)(CFArrayRef, CFIndex);
    void (*array_append)(CFMutableArrayRef, CFTypeRef);
    CFMutableArrayRef (*array_new)(void *, CFIndex, const void *);
    const void *dict_key_callbacks;
    const void *dict_value_callbacks;
    const void *array_callbacks;
    const CFTypeRef *true_value;      /* optional: address of kCFLBooleanTrue; NULL = leave the flag out */
} DccCfApi;

typedef struct {
    const char *uuid;                 /* identity of the cluster display */
    const char *name;
    const char *url;                  /* initialURL */
    int width, height, width_mm, height_mm, max_fps;
    int safe_x, safe_y, safe_w, safe_h;
} DccClusterDisplay;

/* "Schema B": describe the cluster display the way perkthefox/mst2-cluster-nav does for the same plug-in (SDK 210.81), which was
 * tried in a car on a TechniSat unit:
 *  - /info gets extendedFeatures = [altScreen, viewAreas] (not enabledFeatures);
 *  - displays AND displayPanels = [main display, cluster display]; the main display keeps all its stock keys and gains uid (= its
 *    uuid) and initialVideoStreams;
 *  - the cluster display has uuid, uid, name, properties, size, physical size, maxFPS, features 0, initialVideoStreams, viewAreas
 *    (with safeArea and, when available, drawUIOutsideSafeArea), initialViewArea and initialURL, and NO type key.
 * Returns 1 when /info was changed. Nothing is changed (0) unless the stock list holds exactly one display with a uuid. */
int dcc_info_schema_b(const DccCfApi *cf, CFMutableDictionaryRef info, const DccClusterDisplay *cluster);

#endif
