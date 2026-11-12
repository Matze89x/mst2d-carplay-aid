/* Host test (freestanding) for the 0x5200 sender in src/rgi_start.c. The source is included directly; the C library and the
 * iap2 client functions are fakes. It checks WHEN a frame is sent and WHAT is sent. It does not prove that the real
 * libiap2client.so, mm-ipod or an iPhone behave this way. */
#include "../src/rgi_start.c"

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

struct ffile{char name[64];char data[4096];long size;int used;};
static struct ffile files[8];
static struct{int file;long pos;int open;}fds[8];
static int same(const char *a,const char *b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
void *memcpy(void *d,const void *s,size_t n){char *x=d;const char *y=s;while(n--)*x++=*y++;return d;}
void *memset(void *d,int c,size_t n){char *x=d;while(n--)*x++=(char)c;return d;}
int memcmp(const void *a,const void *b,size_t n){const unsigned char *x=a,*y=b;while(n--){if(*x!=*y)return *x-*y;x++;y++;}return 0;}
size_t strlen(const char *s){size_t n=0;while(s[n])n++;return n;}
int open(const char *path,int flags,...){
    int f=-1,i;
    for(i=0;i<8;i++)if(files[i].used&&same(files[i].name,path))f=i;
    if(f<0){
        if(!(flags&O_CREAT))return -1;
        for(i=0;i<8;i++)if(!files[i].used){f=i;files[i].used=1;files[i].size=0;
            {int k=0;for(;path[k]&&k<63;k++)files[i].name[k]=path[k];files[i].name[k]=0;}break;}
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
int pthread_create(pthread_t *t,const void *a,void *(*f)(void *),void *x){(void)t;(void)a;(void)f;(void)x;return -1;}
int pthread_detach(pthread_t t){(void)t;return 0;}
int delay(unsigned ms){(void)ms;return 0;}

static void put(const char *name,const char *text){
    int fd=open(name,O_WRONLY|O_CREAT|O_TRUNC,0666);
    if(fd>=0){write(fd,text,strlen(text));close(fd);}
}
static void drop(const char *name){for(int i=0;i<8;i++)if(files[i].used&&same(files[i].name,name))files[i].used=0;}
static struct ffile *file_named(const char *n){for(int i=0;i<8;i++)if(files[i].used&&same(files[i].name,n))return &files[i];return 0;}
static int has(const char *name,const char *needle){
    struct ffile *f=file_named(name);long n=(long)strlen(needle);
    if(!f)return 0;
    for(long i=0;i+n<=f->size;i++)if(memcmp(f->data+i,needle,(size_t)n)==0)return 1;
    return 0;
}

static unsigned connects,sends,disconnects;
static int connect_ok=1,send_result=12;
static unsigned char last_frame[16];
static unsigned last_len;
static const char *last_path;
static int last_flags=-1;
static int fake_token;
static void *fake_connect(const char *p,int f){connects++;last_path=p;last_flags=f;return connect_ok?&fake_token:0;}
static int fake_send(void *c,const void *b,unsigned n){(void)c;sends++;last_len=n;for(unsigned i=0;i<n&&i<16;i++)last_frame[i]=((const unsigned char *)b)[i];return send_result;}
static int fake_disconnect(void *c){(void)c;disconnects++;return 0;}
static const RgiStartOps ops={fake_connect,fake_send,fake_disconnect};

static int failures;
static void check(int ok,const char *what){out(ok?"  ok   ":"  FAIL ");out(what);out("\n");if(!ok)failures++;}

void test_main(void){
    RgiStartState st={0,0,0};
    unsigned long now=0;
    unsigned i,before;
    out("0x5200 sender (host test with fakes)\n");

    now+=500;rgi_start_step(&st,now,&ops);
    check(sends==0,"no ready file: nothing sent");
    put(RGI_READY,"pending\n");now+=500;rgi_start_step(&st,now,&ops);
    check(sends==0,"ready=pending: nothing sent");
    put(RGI_READY,"omitted\n");now+=500;rgi_start_step(&st,now,&ops);
    check(sends==0,"ready=omitted (after a rejection): nothing sent");

    put(RGI_READY,"offered\n");put(RGI_SEEN,"0\n");
    put(RGI_NOSEND,"x");now+=500;rgi_start_step(&st,now,&ops);
    check(sends==0,"nosend file present: nothing sent");
    drop(RGI_NOSEND);

    now+=500;rgi_start_step(&st,now,&ops);
    check(sends==1&&connects==1&&disconnects==1,"offered: first frame sent at once, client closed again");
    check(last_len==12&&last_frame[0]==0x40&&last_frame[1]==0x40&&last_frame[2]==0&&last_frame[3]==12&&last_frame[4]==0x52&&last_frame[5]==0
          &&last_frame[6]==0&&last_frame[7]==6&&last_frame[8]==0&&last_frame[9]==0&&last_frame[10]==0&&last_frame[11]==0x10,
          "frame is 40 40 00 0c 52 00 00 06 00 00 00 10");
    check(last_path&&same(last_path,"/dev/ipod0")&&last_flags==0,"device /dev/ipod0, flags 0");
    check(has(RGI_LOG,"0x5200 sent through the stock iAP2 client"),"log line written");

    now+=500;rgi_start_step(&st,now,&ops);now+=500;rgi_start_step(&st,now,&ops);now+=500;rgi_start_step(&st,now,&ops);
    check(sends==1,"retry not before 2 s");
    now+=500;rgi_start_step(&st,now,&ops);
    check(sends==2,"second frame after 2 s");

    for(i=0;i<8;i++){now+=2000;rgi_start_step(&st,now,&ops);}
    check(sends==10,"ten tries at 2 s");
    before=sends;now+=2000;rgi_start_step(&st,now,&ops);
    check(sends==before,"after ten tries: not after 2 s");
    now+=28000;rgi_start_step(&st,now,&ops);
    check(sends==before+1,"after ten tries: every 30 s");

    put(RGI_SEEN,"1\n");before=sends;now+=60000;rgi_start_step(&st,now,&ops);now+=60000;rgi_start_step(&st,now,&ops);
    check(sends==before,"first 0x52xx seen: no more frames");
    put(RGI_SEEN,"0\n");now+=500;rgi_start_step(&st,now,&ops);
    check(sends==before+1,"seen back to 0 (new identification): asks again at once");

    connect_ok=0;before=sends;
    put(RGI_SEEN,"0\n");now+=40000;rgi_start_step(&st,now,&ops);
    check(connects>0&&sends==before,"connect fails: no send");
    check(has(RGI_LOG,"iap2_connect failed"),"connect failure is logged");
    connect_ok=1;send_result=-1;now+=40000;
    {RgiStartState s2={0,0,0};rgi_start_step(&s2,now,&ops);check(has(RGI_LOG,"raw send failed"),"send failure is logged");}

    check(rgi_start_step(0,now,&ops)==0,"NULL state is handled");
    {RgiStartOps bad={0,fake_send,fake_disconnect};RgiStartState s3={0,0,0};check(rgi_start_step(&s3,now,&bad)==0,"NULL function pointer is handled");}

    out(failures?"=== FAILED\n":"=== ALL OK\n");
    sys3(SYS_exit,failures?1:0,0,0);
}
__attribute__((naked)) void _start(void){__asm__ volatile(ENTRY_ASM);}
