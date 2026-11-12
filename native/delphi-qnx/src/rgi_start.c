/* Sender for "StartRouteGuidanceUpdate" (iAP2 message 0x5200), runs inside the CarPlay process (libmst2_eu_airplay.so).
 *
 * Why: the iPhone sends route guidance (0x5201/0x5202/0x5204) only AFTER the car has sent 0x5200. Announcing the IDs in iap2.cfg and
 * offering the "Instrument Cluster" component in the identification (libmst2_eu_ipod.so) is not enough; the stock Delphi driver never
 * sends it either. The TechniSat project perkthefox/mst2-cluster-nav does exactly this from its SAL process.
 *
 * How (Delphi P0879D, read from the firmware, see wissen/10-vergleich-technisat-delphi-luecken.md): /bin/CarPlay imports
 * libiap2client.so.1 and calls iap2_connect(<fixed path>, 0). iap2_raw_msg_send (0x16e8) sends the frame to mm-ipod with MsgSendv
 * type 0x3000. We open a short-lived client of our own, send one 12-byte frame, disconnect. The path /dev/ipod0 is the string the
 * CarPlay binary contains; that this exact string is passed at the call sites was not resolved down to the address.
 *
 * Safety:
 *  - Sends only while the ipod hook says "offered" (/dev/shmem/mst2-eu-rgi-ready). After a rejection the hook writes "omitted", before
 *    the first identification "pending": then nothing is sent.
 *  - Stops as soon as the relay marks the first valid 0x52xx as seen (/dev/shmem/mst2-eu-rgi-seen = "1").
 *  - A file /dev/shmem/mst2-eu-rgi-nosend switches the sender off (RAM only, gone after a restart).
 *  - Everything runs in its own thread; every function pointer is checked before use.
 *  - Retry like the reference project: 10 times every 2 s, then every 30 s.
 */
#include "dcc_qnx.h"
#include "dcc_resolve.h"
#include "dcc_guard.h"

#define RGI_READY "/dev/shmem/mst2-eu-rgi-ready"
#define RGI_SEEN "/dev/shmem/mst2-eu-rgi-seen"
#define RGI_NOSEND "/dev/shmem/mst2-eu-rgi-nosend"
#define RGI_LOG "/dev/shmem/mst2-eu-rgi.log"
#define RGI_CLIENT_LIB "libiap2client.so.1"
#define RGI_DEVICE "/dev/ipod0"
#define RGI_LOG_LIMIT 3000
#define RGI_TICK_MS 500u

typedef struct {
    void *(*connect_client)(const char *, int);
    int (*raw_send)(void *, const void *, unsigned);
    int (*disconnect_client)(void *);
} RgiStartOps;

typedef struct {
    unsigned attempts;
    unsigned long last_ms;
    int was_seen;
} RgiStartState;

/* iAP2 control frame: 0x4040, length 12, message 0x5200, one parameter (id 0, 6 bytes): component 0x0010 (our component). */
static const uint8_t rgi_start_frame[12] = {0x40, 0x40, 0x00, 0x0c, 0x52, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x10};

static void rgi_note(const char *text)
{
    int fd = open(RGI_LOG, O_WRONLY | O_CREAT, 0666);
    off_t end;
    if (fd < 0) return;
    end = lseek(fd, 0, SEEK_END);
    if (end > RGI_LOG_LIMIT) {
        close(fd);
        fd = open(RGI_LOG, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd < 0) return;
    }
    write(fd, text, strlen(text));
    close(fd);
}

/* Does the file exist and start with the given text? */
static int rgi_file_starts(const char *path, const char *text)
{
    char buffer[16];
    int fd = open(path, O_RDONLY), ok = 1;
    ssize_t n;
    size_t i, want = strlen(text);
    if (fd < 0) return 0;
    n = read(fd, buffer, sizeof(buffer));
    close(fd);
    if (n < 0 || (size_t)n < want) return 0;
    for (i = 0; i < want; ++i)
        if (buffer[i] != text[i]) ok = 0;
    return ok;
}

static int rgi_file_exists(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;
    close(fd);
    return 1;
}

/* One step. now_ms only needs to grow; it is counted from the thread's own ticks. Returns 1 when a frame was sent. */
static int rgi_start_step(RgiStartState *state, unsigned long now_ms, const RgiStartOps *ops)
{
    int seen, result;
    unsigned long interval;
    void *client;
    if (!state || !ops || !ops->connect_client || !ops->raw_send || !ops->disconnect_client) return 0;
    if (rgi_file_exists(RGI_NOSEND) || dcc_guard_killed()) return 0;
    if (!rgi_file_starts(RGI_READY, "offered")) return 0;
    seen = rgi_file_starts(RGI_SEEN, "1");
    if (seen) {
        state->was_seen = 1;
        return 0;
    }
    if (state->was_seen) {          /* the phone has to be asked again (new identification) */
        state->was_seen = 0;
        state->attempts = 0;
        state->last_ms = now_ms > 2000ul ? now_ms - 2000ul : 0ul;
    }
    interval = state->attempts < 10 ? 2000ul : 30000ul;
    if (state->attempts && now_ms - state->last_ms < interval) return 0;
    state->last_ms = now_ms;
    state->attempts++;
    client = ops->connect_client(RGI_DEVICE, 0);
    if (!client) {
        if (state->attempts <= 3 || state->attempts == 10) rgi_note("0x5200: iap2_connect failed, will retry\n");
        return 0;
    }
    result = ops->raw_send(client, rgi_start_frame, (unsigned)sizeof(rgi_start_frame));
    (void)ops->disconnect_client(client);
    if (state->attempts <= 3 || state->attempts == 10)
        rgi_note(result < 0 ? "0x5200: raw send failed, will retry\n" : "0x5200 sent through the stock iAP2 client\n");
    return result >= 0;
}

static void *rgi_start_thread(void *unused)
{
    RgiStartOps ops;
    RgiStartState state;
    unsigned long now = 0;
    void *library = NULL;
    int resolved = 0;
    (void)unused;
    state.attempts = 0;
    state.last_ms = 0;
    state.was_seen = 0;
    ops.connect_client = NULL;
    ops.raw_send = NULL;
    ops.disconnect_client = NULL;
    for (;;) {
        delay(RGI_TICK_MS);
        now += RGI_TICK_MS;
        if (!resolved) {
            /* Resolve only after the ipod hook offered its component: never during process start-up. */
            if (!rgi_file_starts(RGI_READY, "offered")) continue;
            library = dlopen(RGI_CLIENT_LIB, RTLD_LAZY);
            if (library) {
                ops.connect_client = (void *(*)(const char *, int))dlsym(library, "iap2_connect");
                ops.raw_send = (int (*)(void *, const void *, unsigned))dlsym(library, "iap2_raw_msg_send");
                ops.disconnect_client = (int (*)(void *))dlsym(library, "iap2_disconnect");
            }
            if (!ops.connect_client || !ops.raw_send || !ops.disconnect_client) {
                rgi_note("0x5200: libiap2client functions not found; sender off\n");
                return NULL;
            }
            resolved = 1;
        }
        (void)rgi_start_step(&state, now, &ops);
    }
    return NULL;
}

void dcc_rgi_start_init(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, rgi_start_thread, NULL) == 0) (void)pthread_detach(thread);
}
