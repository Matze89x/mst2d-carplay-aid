/* Host test (freestanding) for "schema B" in src/info_schema.c with a small fake Core Foundation. It checks the SHAPE of the /info
 * dictionary against what perkthefox/mst2-cluster-nav builds. It does not show that an iPhone accepts it. */
#include "../src/info_schema.c"

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
void *memcpy(void *d,const void *s,size_t n){char *x=d;const char *y=s;while(n--)*x++=*y++;return d;}
void *memset(void *d,int c,size_t n){char *x=d;while(n--)*x++=(char)c;return d;}
int memcmp(const void *a,const void *b,size_t n){const unsigned char *x=a,*y=b;while(n--){if(*x!=*y)return *x-*y;x++;y++;}return 0;}
size_t strlen(const char *s){size_t n=0;while(s[n])n++;return n;}
int open(const char *p,int f,...){(void)p;(void)f;return -1;}
int close(int f){(void)f;return 0;}
ssize_t write(int f,const void *b,size_t n){(void)f;(void)b;(void)n;return -1;}
ssize_t read(int f,void *b,size_t n){(void)f;(void)b;(void)n;return -1;}
off_t lseek(int f,off_t o,int w){(void)f;(void)o;(void)w;return 0;}
void *dlopen(const char *p,int f){(void)p;(void)f;return 0;}
void *dlsym(void *h,const char *s){(void)h;(void)s;return 0;}

enum {K_STR=1,K_INT,K_BOOL,K_DICT,K_ARR};
typedef struct Obj{int kind;char s[48];long long i;int n;const char *k[24];struct Obj *v[24];}Obj;
static Obj pool[600];static int used;
static Obj *mk(int kind){Obj *o=&pool[used++];o->kind=kind;return o;}
static int same(const char *a,const char *b){while(*a&&*a==*b){a++;b++;}return *a==*b;}
static CFStringRef f_string(void *a,const char *t,uint32_t e){(void)a;(void)e;Obj *o=mk(K_STR);size_t i=0;while(t[i]&&i<47){o->s[i]=t[i];i++;}o->s[i]=0;return o;}
static void f_release(CFTypeRef o){(void)o;}
static void put(Obj *d,const char *key,Obj *val){
    for(int i=0;i<d->n;i++)if(same(d->k[i],key)){d->v[i]=val;return;}
    d->k[d->n]=key;d->v[d->n]=val;d->n++;
}
static CFTypeRef f_dict_get(CFDictionaryRef d,CFTypeRef key){const Obj *o=d,*k=key;for(int i=0;i<o->n;i++)if(same(o->k[i],k->s))return o->v[i];return 0;}
static void f_dict_set(CFMutableDictionaryRef d,CFTypeRef key,CFTypeRef val){
    Obj *k=(Obj *)key;
    /* keys are copied: the caller releases its key string, and here strings live in the pool forever, so keep the pointer */
    put(d,k->s,(Obj *)val);
}
static void f_dict_set_i64(CFMutableDictionaryRef d,CFTypeRef key,int64_t v){Obj *i=mk(K_INT);i->i=v;f_dict_set(d,key,i);}
static CFIndex f_dict_count(CFDictionaryRef d){return ((const Obj *)d)->n;}
static void f_dict_pairs(CFDictionaryRef d,const void **keys,const void **vals){
    const Obj *o=d;
    for(int i=0;i<o->n;i++){Obj *k=mk(K_STR);size_t j=0;while(o->k[i][j]&&j<47){k->s[j]=o->k[i][j];j++;}k->s[j]=0;keys[i]=k;vals[i]=o->v[i];}
}
static CFMutableDictionaryRef f_dict_new(void *a,CFIndex c,const void *x,const void *y){(void)a;(void)c;(void)x;(void)y;return mk(K_DICT);}
static CFIndex f_array_count(CFArrayRef a){return ((const Obj *)a)->n;}
static CFTypeRef f_array_get(CFArrayRef a,CFIndex i){return ((const Obj *)a)->v[i];}
static void f_array_append(CFMutableArrayRef a,CFTypeRef v){Obj *o=a;o->v[o->n++]=(Obj *)v;}
static CFMutableArrayRef f_array_new(void *a,CFIndex c,const void *x){(void)a;(void)c;(void)x;return mk(K_ARR);}

static Obj *g(const Obj *d,const char *key){for(int i=0;i<d->n;i++)if(same(d->k[i],key))return d->v[i];return 0;}
static int failures;
static void check(int ok,const char *what){out(ok?"  ok   ":"  FAIL ");out(what);out("\n");if(!ok)failures++;}
static int arr_has(const Obj *a,const char *text){if(!a)return 0;for(int i=0;i<a->n;i++)if(a->v[i]->kind==K_STR&&same(a->v[i]->s,text))return 1;return 0;}

static Obj bool_true;
static const CFTypeRef true_ref=&bool_true;
static DccCfApi api(int with_bool){
    DccCfApi a;
    a.string=f_string;a.release=f_release;a.dict_get=f_dict_get;a.dict_set=f_dict_set;a.dict_set_i64=f_dict_set_i64;
    a.dict_count=f_dict_count;a.dict_pairs=f_dict_pairs;a.dict_new=f_dict_new;a.array_count=f_array_count;a.array_get=f_array_get;
    a.array_append=f_array_append;a.array_new=f_array_new;a.dict_key_callbacks=a.dict_value_callbacks=a.array_callbacks=0;
    a.true_value=with_bool?&true_ref:0;return a;
}
/* a stock /info: one display in the old schema + other keys */
static Obj *stock_info(int with_uuid,int displays){
    Obj *info=mk(K_DICT),*arr=mk(K_ARR);
    for(int n=0;n<displays;n++){
        Obj *d=mk(K_DICT),*s;
        if(with_uuid){s=mk(K_STR);s->s[0]='M';s->s[1]=0;put(d,"uuid",s);}
        s=mk(K_INT);s->i=800;put(d,"widthPixels",s);
        s=mk(K_INT);s->i=480;put(d,"heightPixels",s);
        s=mk(K_STR);s->s[0]='k';s->s[1]=0;put(d,"edid",s);
        arr->v[arr->n++]=d;
    }
    put(info,"displays",arr);
    {Obj *f=mk(K_INT);f->i=0x1234;put(info,"features",f);}
    return info;
}
static const DccClusterDisplay cluster={"UUID-C","Instrument Cluster","maps:/car/instrumentcluster/map",1010,376,244,91,25,0,58,1010,248};

void test_main(void){
    DccCfApi a=api(1);
    Obj *info,*disp,*main,*cl,*views,*view,*safe,*streams;
    out("info schema B (host test with a fake CF)\n");

    info=stock_info(1,1);
    check(dcc_info_schema_b(&a,info,&cluster)==1,"one display with uuid: changed");
    disp=g(info,"displays");
    check(disp&&disp->n==2,"displays holds two entries");
    check(g(info,"displayPanels")==disp,"displayPanels is the same list");
    check(arr_has(g(info,"extendedFeatures"),"altScreen")&&arr_has(g(info,"extendedFeatures"),"viewAreas"),"extendedFeatures = altScreen, viewAreas");
    check(!g(info,"enabledFeatures"),"no enabledFeatures in /info");
    check(g(info,"features")&&g(info,"features")->i==0x1234,"other /info keys untouched");
    main=disp->v[0];cl=disp->v[1];
    check(g(main,"edid")&&g(main,"widthPixels")->i==800,"main display keeps its stock keys");
    check(g(main,"uid")&&same(g(main,"uid")->s,"M"),"main display: uid = its uuid");
    streams=g(main,"initialVideoStreams");
    check(streams&&streams->n==1&&same(g(streams->v[0],"uuid")->s,"M")&&g(streams->v[0],"zIndex")->i==0,"main display: initialVideoStreams");
    check(same(g(cl,"uuid")->s,"UUID-C")&&same(g(cl,"uid")->s,"UUID-C"),"cluster: uuid = uid");
    check(same(g(cl,"name")->s,"Instrument Cluster")&&arr_has(g(cl,"properties"),"Instrument Cluster"),"cluster: name and properties");
    check(g(cl,"widthPixels")->i==1010&&g(cl,"heightPixels")->i==376,"cluster: 1010 x 376");
    check(g(cl,"widthPhysical")->i==244&&g(cl,"heightPhysical")->i==91&&g(cl,"maxFPS")->i==25&&g(cl,"features")->i==0,"cluster: physical size, maxFPS 25, features 0");
    check(!g(cl,"type"),"cluster: NO type key");
    check(same(g(cl,"initialURL")->s,"maps:/car/instrumentcluster/map")&&g(cl,"initialViewArea")->i==0,"cluster: initialURL, initialViewArea");
    views=g(cl,"viewAreas");view=views?views->v[0]:0;safe=view?g(view,"safeArea"):0;
    check(views&&views->n==1&&g(view,"widthPixels")->i==1010,"cluster: one view area");
    check(safe&&g(safe,"originYPixels")->i==58&&g(safe,"heightPixels")->i==248,"cluster: safe area from the profile");
    check(g(view,"drawUIOutsideSafeArea")==&bool_true&&g(safe,"drawUIOutsideSafeArea")==&bool_true,"drawUIOutsideSafeArea set in view and safe area");
    streams=g(cl,"initialVideoStreams");
    check(streams&&streams->n==1&&same(g(streams->v[0],"uuid")->s,"UUID-C"),"cluster: initialVideoStreams");

    {DccCfApi nb=api(0);info=stock_info(1,1);
     check(dcc_info_schema_b(&nb,info,&cluster)==1,"without the boolean symbol: still works");
     view=g(g(g(info,"displays")->v[1],"viewAreas")->v[0],"widthPixels")?g(g(g(info,"displays")->v[1],"viewAreas")->v[0],"widthPixels"):0;
     check(!g(g(g(g(info,"displays")->v[1],"viewAreas")->v[0],"safeArea"),"drawUIOutsideSafeArea"),"without the boolean symbol: flag left out");}

    info=stock_info(1,2);
    check(dcc_info_schema_b(&a,info,&cluster)==0&&g(info,"displays")->n==2&&!g(info,"displayPanels"),"two stock displays: /info left unchanged");
    info=stock_info(0,1);
    check(dcc_info_schema_b(&a,info,&cluster)==0&&!g(info,"displayPanels")&&!g(info,"extendedFeatures"),"display without uuid: /info left unchanged");
    info=mk(K_DICT);
    check(dcc_info_schema_b(&a,info,&cluster)==0,"no displays key: left unchanged");
    check(dcc_info_schema_b(0,info,&cluster)==0&&dcc_info_schema_b(&a,0,&cluster)==0&&dcc_info_schema_b(&a,info,0)==0,"NULL arguments are handled");

    out(failures?"=== FAILED\n":"=== ALL OK\n");
    sys3(SYS_exit,failures?1:0,0,0);
}
__attribute__((naked)) void _start(void){__asm__ volatile(ENTRY_ASM);}
