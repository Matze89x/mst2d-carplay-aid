#include "dcc_qnx.h"
#include "dcc_resolve.h"

#define CHILD "/extbin/apps/mst2-eu-carplay-maps/libmst2_eu_ipod.so"
#define FULL_ENV "LD_PRELOAD=" CHILD
#define ENV_CAP 96
#define VALUE_CAP 1024

typedef int pid_t;
struct inheritance;
typedef pid_t (*spawn_fn)(const char *,int,const int *,const struct inheritance *,char *const *,char *const *);

static int equal(const char *a,const char *b){
    while(*a&&*a==*b){a++;b++;}
    return *a==*b;
}
static int prefix(const char *value,const char *part){
    while(*part)if(*value++!=*part++)return 0;
    return 1;
}
static int mm_ipod(const char *value){
    const char *base=value;
    if(!value)return 0;
    while(*value){if(*value=='/')base=value+1;value++;}
    return equal(base,"mm-ipod");
}
static int launches_ipod(const char *path,char *const argv[]){
    unsigned i;
    if(mm_ipod(path))return 1;
    if(!argv)return 0;
    for(i=0;i<ENV_CAP&&argv[i];i++)if(mm_ipod(argv[i]))return 1;
    return 0;
}
/* The real spawn/spawnp: RTLD_NEXT first, then named libc. NULL when neither is found (never called then). */
static spawn_fn real_spawn,real_spawnp;
static spawn_fn find_spawn(const char *symbol){
    int plain=equal(symbol,"spawn");
    spawn_fn *cache=plain?&real_spawn:&real_spawnp;
    if(!*cache)*cache=(spawn_fn)dcc_next_symbol(symbol);
    if(!*cache)*cache=(spawn_fn)dcc_library_symbol("libc.so.3",symbol);
    return *cache;
}
static pid_t invoke(const char *symbol,const char *path,int fd_count,const int *fd_map,
                    const struct inheritance *inherit,char *const argv[],char *const envp[]){
    spawn_fn next=find_spawn(symbol);char *environment[ENV_CAP];char value[VALUE_CAP];
    unsigned count=0,preload=ENV_CAP,i,used;
    if(!next)return -1;
    if(!launches_ipod(path,argv)||!envp)return next(path,fd_count,fd_map,inherit,argv,envp);
    while(envp[count]&&count+2<ENV_CAP){environment[count]=envp[count];if(prefix(envp[count],"LD_PRELOAD="))preload=count;count++;}
    if(envp[count])return next(path,fd_count,fd_map,inherit,argv,envp);
    used=(unsigned)strlen(FULL_ENV);
    if(preload<ENV_CAP){const char *stock=environment[preload]+strlen("LD_PRELOAD=");unsigned stock_len=(unsigned)strlen(stock);
        if(prefix(stock,CHILD))return next(path,fd_count,fd_map,inherit,argv,envp);
        if(stock_len&&used+1+stock_len>=VALUE_CAP)return next(path,fd_count,fd_map,inherit,argv,envp);
        i=0;while(FULL_ENV[i]){value[i]=FULL_ENV[i];i++;}
        if(stock_len){value[i++]=':';while(*stock)value[i++]=*stock++;}value[i]=0;environment[preload]=value;
    }else{
        if(used>=VALUE_CAP)return next(path,fd_count,fd_map,inherit,argv,envp);
        i=0;while(FULL_ENV[i]){value[i]=FULL_ENV[i];i++;}value[i]=0;environment[count++]=value;
    }
    environment[count]=NULL;
    return next(path,fd_count,fd_map,inherit,argv,environment);
}
__attribute__((visibility("default")))
pid_t spawn(const char *path,int fd_count,const int *fd_map,const struct inheritance *inherit,char *const argv[],char *const envp[]){
    return invoke("spawn",path,fd_count,fd_map,inherit,argv,envp);
}
__attribute__((visibility("default")))
pid_t spawnp(const char *path,int fd_count,const int *fd_map,const struct inheritance *inherit,char *const argv[],char *const envp[]){
    return invoke("spawnp",path,fd_count,fd_map,inherit,argv,envp);
}
