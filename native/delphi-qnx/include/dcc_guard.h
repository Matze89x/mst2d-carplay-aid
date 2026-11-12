#ifndef DCC_GUARD_H
#define DCC_GUARD_H

#include "dcc_qnx.h"

/* Self-protection of the hooks (the idea is taken from perkthefox/mst2-cluster-nav: whatever goes wrong, the mod takes itself out and the
 * unit runs stock). Everything lives in RAM (/dev/shmem), so it protects against a part that keeps dying within one boot; it does NOT
 * survive a reset of the whole unit (no known writable flash on the Delphi radio for hooks; the uninstall card remains the way out).
 *
 *  - Kill switch: a file named mst2-eu-disable in /dev/shmem, /sdc0 or /sdc1 (the SD card) makes every part pass through. Checked at the
 *    start of a part and at every decision point (never needs a restart for the parts that look again).
 *  - Crash marks: each part writes "1" to /dev/shmem/mst2-eu-busy-<part> when it starts working and "0" when it ends cleanly (DT_FINI, or
 *    for mm-ipod the end of the first identification). A "1" found at the next start means the previous start died at work: that is a
 *    strike (/dev/shmem/mst2-eu-strikes-<part>, one digit). Three strikes in one boot create /dev/shmem/mst2-eu-off-<part>, and the part
 *    stays off until the next boot. */

#define DCC_GUARD_LOG "/dev/shmem/mst2-eu-rgi.log"
#define DCC_GUARD_MAX_STRIKES 3

static inline void dcc_guard_cat(char *out, size_t cap, const char *a, const char *b)
{
    size_t n = 0;
    while (a && *a && n + 1 < cap) out[n++] = *a++;
    while (b && *b && n + 1 < cap) out[n++] = *b++;
    out[n] = 0;
}

static inline int dcc_guard_exists(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;
    close(fd);
    return 1;
}

static inline int dcc_guard_first(const char *path)
{
    char c = 0;
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;
    if (read(fd, &c, 1) != 1) c = 0;
    close(fd);
    return (unsigned char)c;
}

static inline void dcc_guard_put(const char *path, const char *text)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) return;
    write(fd, text, strlen(text));
    close(fd);
}

static inline void dcc_guard_note(const char *part, const char *text)
{
    char line[160];
    int fd;
    off_t end;
    size_t n = 0, i;
    const char *pieces[4] = {"guard ", part, ": ", text};
    int k;
    for (k = 0; k < 4; ++k)
        for (i = 0; pieces[k][i] && n + 2 < sizeof(line); ++i) line[n++] = pieces[k][i];
    line[n++] = '\n';
    line[n] = 0;
    fd = open(DCC_GUARD_LOG, O_WRONLY | O_CREAT, 0666);
    if (fd < 0) return;
    end = lseek(fd, 0, SEEK_END);
    if (end > 3000) {
        close(fd);
        fd = open(DCC_GUARD_LOG, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd < 0) return;
    }
    write(fd, line, n);
    close(fd);
}

/* 1 = a kill switch file exists */
static inline int dcc_guard_killed(void)
{
    return dcc_guard_exists("/dev/shmem/mst2-eu-disable") || dcc_guard_exists("/sdc0/mst2-eu-disable") ||
           dcc_guard_exists("/sdc1/mst2-eu-disable");
}

/* Start of a part. Returns 1 when the part may act, 0 when it must pass everything through. */
static inline int dcc_guard_start(const char *part)
{
    char busy[96], strikes[96], off[96];
    int count;
    if (dcc_guard_killed()) {
        dcc_guard_note(part, "kill switch file present, part off");
        return 0;
    }
    dcc_guard_cat(off, sizeof(off), "/dev/shmem/mst2-eu-off-", part);
    if (dcc_guard_exists(off)) return 0;
    dcc_guard_cat(busy, sizeof(busy), "/dev/shmem/mst2-eu-busy-", part);
    if (dcc_guard_first(busy) == '1') {
        char digit[2];
        dcc_guard_cat(strikes, sizeof(strikes), "/dev/shmem/mst2-eu-strikes-", part);
        count = dcc_guard_first(strikes);
        count = (count >= '0' && count <= '9') ? count - '0' : 0;
        count++;
        if (count > 9) count = 9;
        digit[0] = (char)('0' + count);
        digit[1] = 0;
        dcc_guard_put(strikes, digit);
        if (count >= DCC_GUARD_MAX_STRIKES) {
            dcc_guard_put(off, "3 starts in a row did not end cleanly\n");
            dcc_guard_put(busy, "0");
            dcc_guard_note(part, "3 starts in a row did not end cleanly, part off until the next boot");
            return 0;
        }
        dcc_guard_note(part, "the previous start did not end cleanly (strike)");
    }
    dcc_guard_put(busy, "1");
    return 1;
}

/* Clean end of the risky work of a part: the strikes in a row start from zero again. */
static inline void dcc_guard_end(const char *part)
{
    char busy[96], strikes[96];
    dcc_guard_cat(busy, sizeof(busy), "/dev/shmem/mst2-eu-busy-", part);
    dcc_guard_put(busy, "0");
    dcc_guard_cat(strikes, sizeof(strikes), "/dev/shmem/mst2-eu-strikes-", part);
    if (dcc_guard_exists(strikes)) dcc_guard_put(strikes, "0");
}

#endif
