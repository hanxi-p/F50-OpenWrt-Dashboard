/* Read-only conntrack accounting. Never uses CT_GET_CTRZERO.
 * Linux netlink ABI: include only libc headers to permit small static builds. */
#define _GNU_SOURCE
#include <sys/socket.h>
#include <poll.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
typedef struct {uint32_t len;uint16_t type,flags;uint32_t seq,pid;} NH;
typedef struct {uint16_t len,type;} NA;
typedef struct {sa_family_t family;uint16_t pad;uint32_t pid,groups;} NL;
typedef struct {unsigned char src[16],dst[16];uint16_t sp,dp;uint8_t proto;} Tuple;
typedef struct Flow {uint32_t id,status;Tuple t;uint64_t rx,tx,rp,tp,seen;char mac[18];struct Flow *next;} Flow;
typedef struct {char mac[18];uint64_t rx,tx,rp,tp;} Host;
typedef struct {unsigned char ip[16];char mac[18];} Neigh;
static Flow *flows[4096];static Host hosts[1024];static Neigh neighbors[2048];
static int nhost,nneigh,nflow,fd,warming=1,busy=0;static uint32_t net,mask,lan,seq=0;
static char lan_if[32]="br-lan"; static uint16_t redirect_port=0;
static const char *outpath,*persist;static volatile sig_atomic_t stopped;
static struct {unsigned char ip[16];unsigned bits;} routes6[256];static int nroutes6;
static uint64_t rejected,overflows; static char generation[96]; static int family=AF_INET;
static uint64_t ticks(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (uint64_t)t.tv_sec*1000+t.tv_nsec/1000000;}
static void stopit(int s){(void)s;stopped=1;}
static uint64_t be(const void *p,int n){const unsigned char *b=p;uint64_t v=0;for(int i=0;i<n;i++)v=(v<<8)|b[i];return v;}
static int align4(int x){return (x+3)&~3;}
static void attrs(void *data,int len,NA **a,int count){
 memset(a,0,count*sizeof(*a));unsigned char *p=data;
 while(len>=4){NA *n=(NA*)p;if(n->len<4||n->len>len)break;unsigned t=n->type&0x3fff;if(t<(unsigned)count)a[t]=n;int s=align4(n->len);p+=s;len-=s;}
}
static void *val(NA *a){return (unsigned char*)a+4;}
static int local(const unsigned char *ip){
 if(family==AF_INET){uint32_t v;memcpy(&v,ip,4);v=ntohl(v);return (v&mask)==net || (v>>24)==10 || (v>>20)==0xac1 || (v>>16)==0xc0a8 || (v>>16)==0xa9fe || (v>>24)==127 || (v>>24)==0 || (v>>28)>=14;}
 for(int i=0;i<nroutes6;i++){unsigned n=routes6[i].bits/8,b=routes6[i].bits%8;if(!memcmp(routes6[i].ip,ip,n)&&(!b||((ip[n]^routes6[i].ip[n])>>(8-b))==0))return 1;}
 for(int i=0;i<nneigh;i++)if(!memcmp(neighbors[i].ip,ip,16))return 1;
 return ip[0]==0xfe&&(ip[1]&0xc0)==0x80 || (ip[0]&0xfe)==0xfc || ip[0]==0xff;
}
static int host(const char *mac){for(int i=0;i<nhost;i++)if(!strcmp(hosts[i].mac,mac))return i;if(nhost>=1024)return -1;strcpy(hosts[nhost].mac,mac);return nhost++;}
static void neighbors_load(void){
 nroutes6=0;FILE *route=fopen("/proc/net/ipv6_route","r");char row[512],dst[33],iface[32],check[96];unsigned bits;
 if(route){while(fgets(row,sizeof row,route)){if(sscanf(row,"%32s %x %*s %*s %*s %*s %*s %*s %*s %31s",dst,&bits,iface)!=3||!bits||bits>128||nroutes6>=256)continue;snprintf(check,sizeof check,"/sys/class/net/%s/bridge",iface);if(strcmp(iface,lan_if)&&access(check,F_OK)!=0)continue;for(int k=0;k<16;k++){char pair[3]={dst[k*2],dst[k*2+1],0};routes6[nroutes6].ip[k]=strtoul(pair,NULL,16);}routes6[nroutes6++].bits=bits;}fclose(route);}
 nneigh=0;FILE *f=fopen("/proc/net/arp","r");char line[512],ip[64],mac[32];unsigned x,y;
 if(f){while(fgets(line,sizeof line,f))if(sscanf(line,"%63s %x %x %31s",ip,&x,&y,mac)==4&&strlen(mac)==17&&strcmp(mac,"00:00:00:00:00:00")&&nneigh<2048){struct in_addr a;if(inet_pton(AF_INET,ip,&a)==1){memset(neighbors[nneigh].ip,0,16);memcpy(neighbors[nneigh].ip,&a.s_addr,4);strcpy(neighbors[nneigh++].mac,mac);}}fclose(f);}
 f=fopen("/tmp/dhcp.leases","r");unsigned long lease;
 if(f){while(fgets(line,sizeof line,f))if(sscanf(line,"%lu %31s %63s",&lease,mac,ip)==3&&strlen(mac)==17&&nneigh<2048){struct in_addr a;if(inet_pton(AF_INET,ip,&a)==1){memset(neighbors[nneigh].ip,0,16);memcpy(neighbors[nneigh].ip,&a.s_addr,4);strcpy(neighbors[nneigh++].mac,mac);}}fclose(f);}
 char command[96];snprintf(command,sizeof command,"ip -6 neigh show dev %s",lan_if);f=popen(command,"r");
 if(f){while(fgets(line,sizeof line,f)){char *m=strstr(line,"lladdr ");unsigned char a6[16];if(m&&sscanf(line,"%63s",ip)==1&&sscanf(m+7,"%31s",mac)==1&&strlen(mac)==17&&inet_pton(AF_INET6,ip,a6)==1&&nneigh<2048){memcpy(neighbors[nneigh].ip,a6,16);strcpy(neighbors[nneigh++].mac,mac);}}pclose(f);}
}
static const char *lookup(const unsigned char *ip){for(int i=0;i<nneigh;i++)if(!memcmp(neighbors[i].ip,ip,16))return neighbors[i].mac;return "";}
static int tuple(NA *a,Tuple *t){
 if(!a)return 0;NA *v[4],*ip[6],*pr[8];attrs(val(a),a->len-4,v,4);if(!v[1]||!v[2])return 0;
 attrs(val(v[1]),v[1]->len-4,ip,6);attrs(val(v[2]),v[2]->len-4,pr,8);
 int s=family==AF_INET?1:3,d=family==AF_INET?2:4,n=family==AF_INET?4:16;if(!ip[s]||!ip[d]||!pr[1])return 0;memset(t,0,sizeof(*t));memcpy(t->src,val(ip[s]),n);memcpy(t->dst,val(ip[d]),n);t->proto=*(unsigned char*)val(pr[1]);if(pr[2])memcpy(&t->sp,val(pr[2]),2);if(pr[3])memcpy(&t->dp,val(pr[3]),2);return 1;
}
static void counters(NA *a,uint64_t *packets,uint64_t *bytes){
 *packets=*bytes=0;if(!a)return;NA *v[6];attrs(val(a),a->len-4,v,6);
 if(v[1]&&v[1]->len>=12)*packets=be(val(v[1]),8);else if(v[3]&&v[3]->len>=8)*packets=be(val(v[3]),4);
 if(v[2]&&v[2]->len>=12)*bytes=be(val(v[2]),8);else if(v[4]&&v[4]->len>=8)*bytes=be(val(v[4]),4);
}
static void event(NH *h,uint64_t now){
 if(h->len<20)return;unsigned char *p=(unsigned char*)h+16;family=p[0];if(family!=AF_INET&&family!=AF_INET6)return;
 NA *a[32];attrs(p+4,h->len-20,a,32);Tuple orig,reply;if(!tuple(a[1],&orig)||!tuple(a[2],&reply))return;
 unsigned char *client=NULL;int invert=0;unsigned char lanaddr[16]={0};memcpy(lanaddr,&lan,4);
 if(local(orig.src)&&!local(orig.dst)&&memcmp(orig.src,lanaddr,16))client=orig.src;
 else if(local(reply.src)&&!local(reply.dst)&&memcmp(reply.src,lanaddr,16)){client=reply.src;invert=1;}
 else return;
 /* Locally redirected DNS is router traffic. Only the verified OpenClash TCP
  * redirect port is an external client leg. IPv6 TPROXY retains remote tuples. */
 if(family==AF_INET&&!memcmp(reply.src,lanaddr,16)&&reply.sp!=htons(redirect_port))return;
 uint32_t id=a[12]?(uint32_t)be(val(a[12]),4):0;
 uint32_t hash=(id^orig.sp^((uint32_t)orig.dp<<16)^orig.proto)&4095;
 Flow **pp=&flows[hash],*f;
 while((f=*pp)&&!(f->id==id&&!memcmp(&f->t,&orig,sizeof orig)))pp=&f->next;
 int fresh=!f;
 if(fresh){if(nflow>=32768){rejected++;return;}f=calloc(1,sizeof(*f));if(!f)return;f->id=id;f->t=orig;f->seen=now;f->next=*pp;*pp=f;nflow++;}
 if(!f->mac[0]){const char *m=lookup(client);if(m[0])strcpy(f->mac,m);}
 if(a[3]&&a[3]->len>=8)f->status=be(val(a[3]),4);
 uint64_t op,ob,rp,rb; counters(a[9],&op,&ob);counters(a[10],&rp,&rb);
 uint64_t rx=invert?ob:rb,tx=invert?rb:ob,pkR=invert?op:rp,pkT=invert?rp:op;
 uint64_t dr=rx>=f->rx?rx-f->rx:0,dt=tx>=f->tx?tx-f->tx:0;
 uint64_t dpR=pkR>=f->rp?pkR-f->rp:0,dpT=pkT>=f->tp?pkT-f->tp:0;
 uint64_t elapsed=fresh?1000:now-f->seen+1000;
 uint64_t cap=125000000ULL*(elapsed/1000+1)+1048576;
 if(!warming&&(!fresh||(h->seq==0&&(h->flags&0x400)))&&f->mac[0]){
  if(dr>cap||dt>cap||dpR>dr||dpT>dt){rejected++;}
  else {int i=host(f->mac);if(i>=0){hosts[i].rx+=dr;hosts[i].tx+=dt;hosts[i].rp+=dpR;hosts[i].tp+=dpT;}}
 }
 /* Dump/event interleaving and partial updates must not lower a baseline. */
 f->rx=rx>f->rx?rx:f->rx;f->tx=tx>f->tx?tx:f->tx;f->rp=pkR>f->rp?pkR:f->rp;f->tp=pkT>f->tp?pkT:f->tp;f->seen=now;
 if((h->type&255)==2){*pp=f->next;free(f);nflow--;}
}
static int write_csv(const char *path){
 char tmp[512];snprintf(tmp,sizeof tmp,"%s.new",path);FILE *f=fopen(tmp,"w");if(!f)return -1;
 fprintf(f,"sample %s %llu %lld %llu\n",generation,(unsigned long long)ticks(),(long long)time(NULL),(unsigned long long)overflows);
 for(int i=0;i<nhost;i++)fprintf(f,"%s 0 %llu %llu %llu %llu\n",hosts[i].mac,(unsigned long long)hosts[i].rx,(unsigned long long)hosts[i].rp,(unsigned long long)hosts[i].tx,(unsigned long long)hosts[i].tp);
 int bad=ferror(f);fclose(f);int result=bad?-1:rename(tmp,path);
 unsigned hardware=0,software=0,unmapped=0;for(int i=0;i<4096;i++)for(Flow *p=flows[i];p;p=p->next){hardware+=!!(p->status&(1U<<15));software+=!!(p->status&(1U<<14));unmapped+=!p->mac[0];}
 char diag[512];snprintf(diag,sizeof diag,"%s.diag",path);snprintf(tmp,sizeof tmp,"%s.diag.new",path);f=fopen(tmp,"w");if(f){fprintf(f,"{\"timestamp\":%lld,\"flows\":%d,\"hardware_flows\":%u,\"software_flows\":%u,\"unmapped_flows\":%u,\"rejected\":%llu,\"netlink_errors\":%llu}\n",(long long)time(NULL),nflow,hardware,software,unmapped,(unsigned long long)rejected,(unsigned long long)overflows);fclose(f);rename(tmp,diag);}
 return result;
}
static void load_csv(const char *path){
 FILE *f=fopen(path,"r");char line[256],mac[18];unsigned long long c,rx,rp,tx,tp;if(!f)return;
 while(fgets(line,sizeof line,f))if(sscanf(line,"%17s %llu %llu %llu %llu %llu",mac,&c,&rx,&rp,&tx,&tp)==6&&strlen(mac)==17){int i=host(mac);if(i>=0){hosts[i].rx=rx;hosts[i].rp=rp;hosts[i].tx=tx;hosts[i].tp=tp;}}fclose(f);
}
static void dump(void){
 struct {NH h;unsigned char family,version;uint16_t res;} msg={{20,0x101,0x301,++seq,0},AF_UNSPEC,0,0};
 if(send(fd,&msg,sizeof msg,0)>=0)busy=1;
}
int main(int argc,char **argv){
 if(argc<5||argc>7){fprintf(stderr,"usage: %s LAN-IP MASK-BITS RUNTIME-CSV PERSIST-CSV [REDIRECT-PORT] [LAN-DEVICE]\n",argv[0]);return 2;}
 if(argc>=6){char *end;long p=strtol(argv[5],&end,10);if(*end||p<0||p>65535)return 2;redirect_port=p;}
 if(argc>=7){if(!argv[6][0]||strlen(argv[6])>=sizeof lan_if)return 2;for(char *c=argv[6];*c;c++)if(!((*c>='a'&&*c<='z')||(*c>='A'&&*c<='Z')||(*c>='0'&&*c<='9')||strchr("_.:-",*c)))return 2;strcpy(lan_if,argv[6]);}
 struct in_addr a;if(inet_pton(AF_INET,argv[1],&a)!=1)return 2;lan=a.s_addr;int bits=atoi(argv[2]);if(bits<1||bits>32)return 2;
 mask=bits==32?0xffffffffU:0xffffffffU<<(32-bits);net=ntohl(lan)&mask;outpath=argv[3];persist=argv[4];
 snprintf(generation,sizeof generation,"%lld-%d-%llu",(long long)time(NULL),getpid(),(unsigned long long)ticks());neighbors_load();
 fd=socket(AF_NETLINK,SOCK_RAW,12);if(fd<0){perror("socket");return 1;}
 int size=1048576;setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&size,sizeof size);NL sa={AF_NETLINK,0,0,5};
 if(bind(fd,(struct sockaddr*)&sa,sizeof sa)<0){perror("bind");return 1;}
 signal(SIGTERM,stopit);signal(SIGINT,stopit);unsigned char *buf=malloc(1048576);if(!buf)return 1;
 uint64_t next=ticks()+1000,saved=ticks(),neighbors_at=ticks();dump();
 while(!stopped){
  struct pollfd p={fd,POLLIN,0};int ready=poll(&p,1,100);uint64_t now=ticks();
  if(ready>0){int len=recv(fd,buf,1048576,0);if(len<0){if(errno==ENOBUFS)overflows++;}else for(int off=0;off+16<=len;){
   NH *h=(NH*)(buf+off);if(h->len<16||off+(int)h->len>len)break;
   if(h->type==3){busy=0;warming=0;write_csv(outpath);}
   else if(h->type==2){busy=0;overflows++;}
   else if((h->type>>8)==1)event(h,now);
   off+=align4(h->len);
  }}
  if(now-neighbors_at>=5000){neighbors_load();neighbors_at=now;}
  if(now>=next){if(!busy)dump();next=now+1000;
   for(int i=0;i<4096;i++){Flow **p=&flows[i];while(*p){Flow *f=*p;if(now-f->seen>120000){*p=f->next;free(f);nflow--;}else p=&f->next;}}
  }
  (void)saved;
 }
 write_csv(outpath);fprintf(stderr,"flow-account stopped: rejected=%llu netlink_errors=%llu\n",(unsigned long long)rejected,(unsigned long long)overflows);close(fd);free(buf);return 0;
}
