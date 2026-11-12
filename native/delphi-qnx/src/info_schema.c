#include "dcc_info_schema.h"

#define CF_UTF8 0x08000100u

static CFStringRef str(const DccCfApi *cf, const char *text) { return cf->string(NULL, text, CF_UTF8); }

static void set(const DccCfApi *cf, CFMutableDictionaryRef dict, const char *name, CFTypeRef value)
{
    CFStringRef key = str(cf, name);
    if (key) { cf->dict_set(dict, key, value); cf->release(key); }
}

static void set_i64(const DccCfApi *cf, CFMutableDictionaryRef dict, const char *name, int64_t value)
{
    CFStringRef key = str(cf, name);
    if (key) { cf->dict_set_i64(dict, key, value); cf->release(key); }
}

static void set_string(const DccCfApi *cf, CFMutableDictionaryRef dict, const char *name, const char *value)
{
    CFStringRef text = str(cf, value);
    if (text) { set(cf, dict, name, text); cf->release(text); }
}

static CFTypeRef get(const DccCfApi *cf, CFDictionaryRef dict, const char *name)
{
    CFStringRef key = str(cf, name);
    CFTypeRef value = key && dict ? cf->dict_get(dict, key) : NULL;
    if (key) cf->release(key);
    return value;
}

static CFMutableDictionaryRef new_dict(const DccCfApi *cf)
{
    return cf->dict_new(NULL, 0, cf->dict_key_callbacks, cf->dict_value_callbacks);
}

static CFMutableDictionaryRef clone(const DccCfApi *cf, CFDictionaryRef source)
{
    const void *keys[64], *values[64];
    CFMutableDictionaryRef result;
    CFIndex count, i;
    if (!source) return NULL;
    count = cf->dict_count(source);
    if (count < 0 || count > 64) return NULL;
    result = new_dict(cf);
    if (!result) return NULL;
    cf->dict_pairs(source, keys, values);
    for (i = 0; i < count; ++i) cf->dict_set(result, keys[i], values[i]);
    return result;
}

static void set_area(const DccCfApi *cf, CFMutableDictionaryRef area, int x, int y, int w, int h)
{
    set_i64(cf, area, "originXPixels", x);
    set_i64(cf, area, "originYPixels", y);
    set_i64(cf, area, "widthPixels", w);
    set_i64(cf, area, "heightPixels", h);
}

/* [ { originXPixels 0, originYPixels 0, uuid, zIndex 0 } ] */
static CFMutableArrayRef video_streams(const DccCfApi *cf, CFTypeRef uuid)
{
    CFMutableArrayRef streams = cf->array_new(NULL, 0, cf->array_callbacks);
    CFMutableDictionaryRef stream = new_dict(cf);
    if (streams && stream) {
        set_i64(cf, stream, "originXPixels", 0);
        set_i64(cf, stream, "originYPixels", 0);
        set(cf, stream, "uuid", uuid);
        set_i64(cf, stream, "zIndex", 0);
        cf->array_append(streams, stream);
    }
    if (stream) cf->release(stream);
    return streams;
}

int dcc_info_schema_b(const DccCfApi *cf, CFMutableDictionaryRef info, const DccClusterDisplay *c)
{
    CFArrayRef stock;
    CFMutableDictionaryRef main_display = NULL, display = NULL, view = NULL, safe = NULL;
    CFMutableArrayRef displays = NULL, main_streams = NULL, streams = NULL, views = NULL, properties = NULL, features = NULL;
    CFStringRef cluster_uuid = NULL, alt = NULL, areas = NULL, cluster_name = NULL;
    CFTypeRef main_uuid;
    int changed = 0;
    if (!cf || !info || !c || !c->uuid || !c->name || !c->url) return 0;
    stock = (CFArrayRef)get(cf, info, "displays");
    if (!stock || cf->array_count(stock) != 1) return 0;
    main_display = clone(cf, (CFDictionaryRef)cf->array_get(stock, 0));
    if (!main_display) return 0;
    main_uuid = get(cf, main_display, "uuid");
    if (!main_uuid) goto done;

    cluster_uuid = str(cf, c->uuid);
    display = new_dict(cf);
    view = new_dict(cf);
    safe = new_dict(cf);
    displays = cf->array_new(NULL, 0, cf->array_callbacks);
    views = cf->array_new(NULL, 0, cf->array_callbacks);
    properties = cf->array_new(NULL, 0, cf->array_callbacks);
    features = cf->array_new(NULL, 0, cf->array_callbacks);
    main_streams = video_streams(cf, main_uuid);
    streams = cluster_uuid ? video_streams(cf, cluster_uuid) : NULL;
    cluster_name = str(cf, c->name);
    alt = str(cf, "altScreen");
    areas = str(cf, "viewAreas");
    if (!cluster_uuid || !display || !view || !safe || !displays || !views || !properties || !features || !main_streams ||
        !streams || !cluster_name || !alt || !areas)
        goto done;

    /* main display: stock keys plus uid and initialVideoStreams */
    set(cf, main_display, "uid", main_uuid);
    set(cf, main_display, "initialVideoStreams", main_streams);

    /* cluster display */
    set(cf, display, "uuid", cluster_uuid);
    set(cf, display, "uid", cluster_uuid);
    set(cf, display, "name", cluster_name);
    cf->array_append(properties, cluster_name);
    set(cf, display, "properties", properties);
    set_i64(cf, display, "widthPixels", c->width);
    set_i64(cf, display, "heightPixels", c->height);
    set_i64(cf, display, "widthPhysical", c->width_mm);
    set_i64(cf, display, "heightPhysical", c->height_mm);
    set_i64(cf, display, "maxFPS", c->max_fps);
    set_i64(cf, display, "features", 0);
    set(cf, display, "initialVideoStreams", streams);
    set_area(cf, view, 0, 0, c->width, c->height);
    set_area(cf, safe, c->safe_x, c->safe_y, c->safe_w, c->safe_h);
    if (cf->true_value) {
        set(cf, view, "drawUIOutsideSafeArea", *cf->true_value);
        set(cf, safe, "drawUIOutsideSafeArea", *cf->true_value);
    }
    set(cf, view, "safeArea", safe);
    cf->array_append(views, view);
    set(cf, display, "viewAreas", views);
    set_i64(cf, display, "initialViewArea", 0);
    set_string(cf, display, "initialURL", c->url);

    cf->array_append(displays, main_display);
    cf->array_append(displays, display);
    set(cf, info, "displays", displays);
    set(cf, info, "displayPanels", displays);
    cf->array_append(features, alt);
    cf->array_append(features, areas);
    set(cf, info, "extendedFeatures", features);
    changed = 1;
done:
    if (areas) cf->release(areas);
    if (alt) cf->release(alt);
    if (cluster_name) cf->release(cluster_name);
    if (streams) cf->release(streams);
    if (main_streams) cf->release(main_streams);
    if (features) cf->release(features);
    if (properties) cf->release(properties);
    if (views) cf->release(views);
    if (displays) cf->release(displays);
    if (safe) cf->release(safe);
    if (view) cf->release(view);
    if (display) cf->release(display);
    if (cluster_uuid) cf->release(cluster_uuid);
    if (main_display) cf->release(main_display);
    return changed;
}
