#include "dcc_avc.h"
#include <stdio.h>
#include <string.h>

int main(void)
{
    static const uint8_t config[] = {
        1,0x42,0,0x1f,0xff,0xe1, 0,4,0x67,0x42,0,0x1f,
        1, 0,4,0x68,0xce,6,0xe2
    };
    static const uint8_t idr[] = {0,0,0,3,0x65,0x88,0x84, 0,0,0,2,0x06,5};
    static const uint8_t pframe[] = {0,0,0,2,0x41,0x9a};
    static const uint8_t expected_prefix[] = {0,0,0,1,0x67,0x42,0,0x1f,0,0,0,1,0x68,0xce,6,0xe2,0,0,0,1,0x65};
    struct dcc_avc avc;
    uint8_t output[128];
    size_t n;
    int is_idr = 0;
    dcc_avc_init(&avc);
    if (dcc_avc_configure(&avc,config,sizeof(config))) return 1;
    n = dcc_avc_to_annexb(&avc,idr,sizeof(idr),output,sizeof(output),&is_idr);
    if (!n || !is_idr || n != avc.config_length + 13u) return 2;
    if (memcmp(output,expected_prefix,sizeof(expected_prefix))) return 3;
    n = dcc_avc_to_annexb(&avc,pframe,sizeof(pframe),output,sizeof(output),&is_idr);
    if (n != 6u || is_idr || memcmp(output,"\0\0\0\1\x41\x9a",6)) return 4;
    if (dcc_avc_to_annexb(&avc,idr,sizeof(idr)-1u,output,sizeof(output),&is_idr)) return 5;
    if (dcc_avc_to_annexb(&avc,idr,sizeof(idr),output,4,&is_idr)) return 6;
    {   /* a real x264 High 3.1 avcC (ffprobe-verified stream): it ends with the four extension bytes fd f8 f8 00 */
        static const uint8_t high[] = {
            0x01,0x64,0x00,0x1f,0xff,0xe1,0x00,0x1b,0x67,0x64,0x00,0x1f,0xac,0xb2,0x00,0x80,0x18,0xf1,0x12,0xe0,0x22,0x00,0x00,0x03,0x00,
            0x02,0x00,0x00,0x03,0x00,0x64,0x1e,0x30,0x64,0x90,0x01,0x00,0x06,0x68,0xeb,0xc3,0xcb,0x22,0xc0,0xfd,0xf8,0xf8,0x00};
        uint8_t bad[sizeof(high)];
        struct dcc_avc h;
        dcc_avc_init(&h);
        if (dcc_avc_configure(&h,high,sizeof(high)) || h.length_bytes != 4u) return 7;
        memcpy(bad,high,sizeof(high)); bad[sizeof(high)-1u] = 1u;                 /* extension with a SPS-extension count: refused */
        if (!dcc_avc_configure(&h,bad,sizeof(high))) return 8;
        if (!dcc_avc_configure(&h,high,sizeof(high)-1u)) return 9;                 /* truncated extension: refused */
        memcpy(bad,high,sizeof(high)); bad[1] = 0x42;                              /* extension bytes on a non-High profile: refused */
        if (!dcc_avc_configure(&h,bad,sizeof(high))) return 10;
    }
    puts("avcC and AVCC-to-Annex-B checks passed");
    return 0;
}
