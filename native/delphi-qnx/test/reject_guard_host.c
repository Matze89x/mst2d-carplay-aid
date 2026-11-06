/* Host test (x86-64, freestanding) for the rejection guard in src/ipod_hook.c. The hook source is included
 * directly; the C library and the stock driver pieces are replaced by small fakes. It checks:
 *  - counter 0: the RGI component is added and the ready file says "offered"
 *  - counter 1..7: the component is NOT added, the ready file says "omitted", the log names the counter
 *  - the log is appended to, and starts over once it is larger than LOG_LIMIT
 * It does NOT prove what a real iPhone or the real driver does. */
#include "../src/ipod_hook.c"

#if defined(__aarch64__)
#define SYS_write 64
#define SYS_exit 93
static long sys3(long n,long a,long b,long c){
    register long x8 __asm__("x8")=n;register long x0 __asm__("x0")=a;register long x1 __asm__("x1")=b;register long x2 __asm__("x2")=c;
    __asm__ volatile("svc 0":"+r"(x0):"r"(x8),"r"(x1),"r"(x2):"memory");return x0;}
#define ENTRY_ASM "bl test_main"
#else
#define SYS_write 1
#define SYS_exit 60
static long sys3(long n,long a,long b,long c){long r;__asm__ volatile("syscall":"=a"(r):"0"(n),"D"(a),"S"(b),"d"(c):"rcx","r11","memory");return r;}
#define ENTRY_ASM "and $-16,%rsp\n call test_main"
#endif
static void out(const char *s){size_t n=0;while(s[n])n++;sys3(SYS_write,1,(long)s,(long)n);}

struct ffile{char name[64];char data[8192];long size;int used;};
static struct ffile files[4];
static struct{int file;long pos;int open;}fds[8];
static int same(const char *a,const char *b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
void *memcpy(void *d,const void *s,size_t n){char *x=d;const char *y=s;while(n--)*x++=*y++;return d;}
void *memset(void *d,int c,size_t n){char *x=d;while(n--)*x++=(char)c;return d;}
int memcmp(const void *a,const void *b,size_t n){const unsigned char *x=a,*y=b;while(n--){if(*x!=*y)return *x-*y;x++;y++;}return 0;}
size_t strlen(const char *s){size_t n=0;while(s[n])n++;return n;}
int open(const char *path,int flags,...){
    int f=-1,i;
    for(i=0;i<4;i++)if(files[i].used&&same(files[i].name,path))f=i;
    if(f<0){
        if(!(flags&O_CREAT))return -1;
        for(i=0;i<4;i++)if(!files[i].used){f=i;files[i].used=1;files[i].size=0;
            for(int k=0;path[k]&&k<63;k++)files[i].name[k]=path[k];break;}
    }
    if(f<0)return -1;
    if(flags&O_TRUNC)files[f].size=0;
    for(i=0;i<8;i++)if(!fds[i].open){fds[i].open=1;fds[i].file=f;fds[i].pos=0;return i;}
    return -1;
}
int close(int fd){fds[fd].open=0;return 0;}
off_t lseek(int fd,off_t off,int whence){if(whence==SEEK_END)fds[fd].pos=files[fds[fd].file].size+off;else fds[fd].pos=off;return fds[fd].pos;}
ssize_t write(int fd,const void *b,size_t n){struct ffile *f=&files[fds[fd].file];
    if(fds[fd].pos+(long)n>(long)sizeof(f->data))return -1;
    memcpy(f->data+fds[fd].pos,b,n);fds[fd].pos+=(long)n;if(fds[fd].pos>f->size)f->size=fds[fd].pos;return (ssize_t)n;}
void *dlopen(const char *p,int f){(void)p;(void)f;return 0;}
void *dlsym(void *h,const char *s){(void)h;(void)s;return 0;}
int pthread_create(pthread_t *t,const void *a,void *(*f)(void *),void *x){(void)t;(void)a;(void)f;(void)x;return 0;}
int pthread_detach(pthread_t t){(void)t;return 0;}
int delay(unsigned ms){(void)ms;return 0;}
int rename(const char *a,const char *b){(void)a;(void)b;return 0;}
ssize_t read(int fd,void *b,size_t n){(void)fd;(void)b;(void)n;return 0;}
int dcc_relay_start(void){return 0;}

static int blobs;
static int fake_builder(void *d,void *p){(void)d;(void)p;return 0;}
static int fake_blob(void *d,void *p,unsigned id,const void *b,unsigned n){(void)d;(void)p;(void)b;(void)n;if(id==0x1e)blobs++;return 0;}

static struct ffile *file_named(const char *n){for(int i=0;i<4;i++)if(files[i].used&&same(files[i].name,n))return &files[i];return 0;}
static int has(const struct ffile *f,const char *needle){
    long n=(long)strlen(needle);
    if(!f)return 0;
    for(long i=0;i+n<=f->size;i++)if(memcmp(f->data+i,needle,(size_t)n)==0)return 1;
    return 0;
}
static int failures;
static void check(int ok,const char *what){out(ok?"  ok   ":"  FAIL ");out(what);out("\n");if(!ok)failures++;}

static void run(uint32_t counter){
    /* the fake device is a block of memory whose word at +0xb0 is the driver's rejection counter */
    static uint32_t device[64];
    device[REJECT_COUNT_OFFSET/4]=counter;
    stock_gps_builder=fake_builder;
    packet_add_blob=fake_blob;
    blobs=0;
    add_route_component(device,device);
}

void test_main(void){
    struct ffile *ready,*log;
    out("rejection guard (host test with fakes)\n");
    run(0);
    ready=file_named(READY);log=file_named(LOG_FILE);
    check(blobs==1,"counter 0: component is added");
    check(has(ready,"offered"),"counter 0: ready file says offered");
    check(has(log,"offered (rejections so far: 0)"),"counter 0: log line");
    for(uint32_t c=1;c<=7;c++){
        run(c);
        check(blobs==0,"counter >0: component is NOT added");
    }
    ready=file_named(READY);log=file_named(LOG_FILE);
    check(has(ready,"omitted"),"counter >0: ready file says omitted");
    check(has(log,"rejections so far: 1\n"),"log names counter 1");
    check(has(log,"rejections so far: 7\n"),"log names counter 7");
    check(has(log,"offered (rejections so far: 0)"),"log is appended to, earlier line still there");
    for(int i=0;i<200;i++)run(3);
    log=file_named(LOG_FILE);
    check(log->size<=LOG_LIMIT+200,"log stays bounded");
    check(has(log,"rejections so far: 3\n"),"log still written after wrap-around");
    out(failures?"=== FAILED\n":"=== ALL OK\n");
    sys3(SYS_exit,failures?1:0,0,0);
}
__attribute__((naked)) void _start(void){__asm__ volatile(ENTRY_ASM);}
