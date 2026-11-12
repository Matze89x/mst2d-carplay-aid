/* Host test (freestanding) for include/dcc_guard.h with a fake file system: kill switch, crash marks, strikes, independence of parts. */
#include "dcc_guard.h"

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
struct ffile{char name[96];char data[4096];long size;int used;};
static struct ffile files[24];
static struct{int file;long pos;int open;}fds[8];
static int same(const char *a,const char *b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
void *memcpy(void *d,const void *s,size_t n){char *x=d;const char *y=s;while(n--)*x++=*y++;return d;}
void *memset(void *d,int c,size_t n){char *x=d;while(n--)*x++=(char)c;return d;}
int memcmp(const void *a,const void *b,size_t n){const unsigned char *x=a,*y=b;while(n--){if(*x!=*y)return *x-*y;x++;y++;}return 0;}
size_t strlen(const char *s){size_t n=0;while(s[n])n++;return n;}
int open(const char *path,int flags,...){
    int f=-1,i;
    for(i=0;i<24;i++)if(files[i].used&&same(files[i].name,path))f=i;
    if(f<0){
        if(!(flags&O_CREAT))return -1;
        for(i=0;i<24;i++)if(!files[i].used){f=i;files[i].used=1;files[i].size=0;{int k=0;for(;path[k]&&k<95;k++)files[i].name[k]=path[k];files[i].name[k]=0;}break;}
    }
    if(f<0)return -1;
    if(flags&O_TRUNC)files[f].size=0;
    for(i=0;i<8;i++)if(!fds[i].open){fds[i].open=1;fds[i].file=f;fds[i].pos=0;return i;}
    return -1;
}
int close(int fd){fds[fd].open=0;return 0;}
off_t lseek(int fd,off_t off,int w){if(w==SEEK_END)fds[fd].pos=files[fds[fd].file].size+off;else fds[fd].pos=off;return fds[fd].pos;}
ssize_t write(int fd,const void *b,size_t n){struct ffile *f=&files[fds[fd].file];
    if(fds[fd].pos+(long)n>(long)sizeof(f->data))return -1;
    memcpy(f->data+fds[fd].pos,b,n);fds[fd].pos+=(long)n;if(fds[fd].pos>f->size)f->size=fds[fd].pos;return (ssize_t)n;}
ssize_t read(int fd,void *b,size_t n){struct ffile *f=&files[fds[fd].file];long left=f->size-fds[fd].pos;
    if(left<=0)return 0;if((long)n<left)left=(long)n;memcpy(b,f->data+fds[fd].pos,(size_t)left);fds[fd].pos+=left;return left;}
void *dlopen(const char *p,int f){(void)p;(void)f;return 0;}
void *dlsym(void *h,const char *s){(void)h;(void)s;return 0;}

static int failures;
static void check(int ok,const char *what){out(ok?"  ok   ":"  FAIL ");out(what);out("\n");if(!ok)failures++;}
static int has_file(const char *n){for(int i=0;i<24;i++)if(files[i].used&&same(files[i].name,n))return 1;return 0;}
static void reset(void){for(int i=0;i<24;i++)files[i].used=0;}
static char first_of(const char *n){for(int i=0;i<24;i++)if(files[i].used&&same(files[i].name,n))return files[i].size?files[i].data[0]:0;return 0;}

void test_main(void){
    int i;
    out("guard (host test with a fake file system)\n");

    reset();
    check(!dcc_guard_killed(),"no kill switch: not killed");
    check(dcc_guard_start("gate")==1&&first_of("/dev/shmem/mst2-eu-busy-gate")=='1',"first start: allowed, busy mark = 1");
    dcc_guard_end("gate");
    check(first_of("/dev/shmem/mst2-eu-busy-gate")=='0',"clean end: busy mark = 0");
    check(dcc_guard_start("gate")==1&&!has_file("/dev/shmem/mst2-eu-strikes-gate"),"start after a clean end: no strike");

    /* the part keeps dying: busy stays 1 */
    check(dcc_guard_start("gate")==1&&first_of("/dev/shmem/mst2-eu-strikes-gate")=='1',"died once: strike 1, still allowed");
    check(dcc_guard_start("gate")==1&&first_of("/dev/shmem/mst2-eu-strikes-gate")=='2',"died twice: strike 2, still allowed");
    check(dcc_guard_start("gate")==0&&has_file("/dev/shmem/mst2-eu-off-gate"),"died three times in a row: part switched off");
    check(dcc_guard_start("gate")==0,"stays off");
    check(dcc_guard_start("ipod")==1,"another part is not affected");
    check(has_file("/dev/shmem/mst2-eu-rgi.log"),"the guard logs why it switched a part off");

    /* strikes are 'in a row': a clean end resets them */
    reset();
    dcc_guard_start("airplay");dcc_guard_start("airplay");           /* strike 1 */
    dcc_guard_start("airplay");                                       /* strike 2 */
    dcc_guard_end("airplay");
    check(first_of("/dev/shmem/mst2-eu-strikes-airplay")=='0',"clean end resets the strikes");
    dcc_guard_start("airplay");                                       /* dies again */
    check(dcc_guard_start("airplay")==1,"one strike after a clean end is still allowed");

    /* kill switch files */
    {   static const char *paths[3]={"/dev/shmem/mst2-eu-disable","/sdc0/mst2-eu-disable","/sdc1/mst2-eu-disable"};
        for(i=0;i<3;i++){
            reset();
            check(!dcc_guard_killed(),"kill switch absent");
            { int fd=open(paths[i],O_WRONLY|O_CREAT,0666);if(fd>=0)close(fd); }
            check(dcc_guard_killed()==1,"kill switch file detected");
            check(dcc_guard_start("launch")==0,"kill switch: part does not start");
            check(!has_file("/dev/shmem/mst2-eu-busy-launch"),"kill switch: no busy mark written");
        }
    }
    out(failures?"=== FAILED\n":"=== ALL OK\n");
    sys3(SYS_exit,failures?1:0,0,0);
}
__attribute__((naked)) void _start(void){__asm__ volatile(ENTRY_ASM);}
