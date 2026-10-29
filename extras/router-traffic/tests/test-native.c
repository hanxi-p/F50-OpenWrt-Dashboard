#define main collector_main
#include "../native/flow-account.c"
#undef main
#include <assert.h>
static unsigned char frame[2048];static int pos;
static int attr_start(int type){int at=pos;NA *a=(NA*)(frame+pos);a->len=4;a->type=type;pos+=4;return at;}
static void attr_end(int at){((NA*)(frame+at))->len=pos-at;pos=align4(pos);}
static void attr_value(int type,const void *v,int n){int a=attr_start(type);memcpy(frame+pos,v,n);pos+=n;attr_end(a);}
static void ct_tuple(int type,int af,const char *src,const char *dst,int sp,int dp){
 int a=attr_start(type),ip=attr_start(1);unsigned char addr[16];
 inet_pton(af,src,addr);attr_value(af==AF_INET?1:3,addr,af==AF_INET?4:16);
 inet_pton(af,dst,addr);attr_value(af==AF_INET?2:4,addr,af==AF_INET?4:16);attr_end(ip);
 int pr=attr_start(2);uint8_t proto=6;uint16_t port=htons(sp);attr_value(1,&proto,1);attr_value(2,&port,2);port=htons(dp);attr_value(3,&port,2);attr_end(pr);attr_end(a);
}
static void ct_counter(int type,uint64_t bytes){int a=attr_start(type);unsigned char b[8]={0};b[7]=1;attr_value(1,b,8);for(int i=7;i>=0;i--){b[i]=bytes&255;bytes>>=8;}attr_value(2,b,8);attr_end(a);}
static void message(int af,int id,const char *src,const char *dst,const char *rsrc,int rport,uint64_t up,uint64_t down,int flags,int type){
 memset(frame,0,sizeof frame);pos=20;frame[16]=af;
 ct_tuple(1,af,src,dst,12345,443);ct_tuple(2,af,rsrc,src,rport,12345);ct_counter(9,up);ct_counter(10,down);
 uint32_t ident=htonl(id);attr_value(12,&ident,4);NH *h=(NH*)frame;h->len=pos;h->type=0x100|type;h->seq=flags?0:1;h->flags=flags;event(h,1000+(uint64_t)id*100);
}
static void neighbor(int af,const char *ip,const char *mac){inet_pton(af,ip,neighbors[nneigh].ip);strcpy(neighbors[nneigh++].mac,mac);}
int main(void){
 redirect_port=7892;lan=inet_addr("192.168.50.1");mask=0xffffff00;net=0xc0a83200;
 const char *mac="02:11:22:33:44:55";neighbor(AF_INET,"192.168.50.2",mac);neighbor(AF_INET6,"2001:db8::2",mac);
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,1000,2000,0,0);warming=0;
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,1500,3000,0,0);assert(hosts[0].rx==1000&&hosts[0].tx==500);
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,1500,3000,0,0);assert(hosts[0].rx==1000&&hosts[0].tx==500);
 message(AF_INET,2,"192.168.50.2","192.168.50.3","192.168.50.3",443,9999,9999,0x400,0);assert(nhost==1&&hosts[0].rx==1000);
 message(AF_INET,3,"192.168.50.2","192.168.50.1","192.168.50.1",443,9999,9999,0x400,0);assert(hosts[0].rx==1000);
 message(AF_INET,4,"192.168.50.2","8.8.8.8","192.168.50.1",53,9999,9999,0x400,0);assert(hosts[0].rx==1000);
 message(AF_INET,5,"192.168.50.2","198.18.0.1","192.168.50.1",7892,100,200,0x400,0);assert(hosts[0].rx==1200&&hosts[0].tx==600);
 message(AF_INET6,6,"2001:db8::2","2606:4700::1111","2606:4700::1111",443,1000,2000,0,0);
 message(AF_INET6,6,"2001:db8::2","2606:4700::1111","2606:4700::1111",443,1300,2600,0,0);assert(nhost==1&&hosts[0].rx==1800&&hosts[0].tx==900);
 message(AF_INET6,7,"2001:db8::2","fe80::1","fe80::1",443,9999,9999,0x400,0);assert(hosts[0].rx==1800);
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,1,1,0,0);assert(hosts[0].rx==1800&&hosts[0].tx==900);
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,101,201,0,2);assert(hosts[0].rx==1800&&hosts[0].tx==900);
 message(AF_INET,1,"192.168.50.2","1.1.1.1","1.1.1.1",443,101,201,0,0);assert(hosts[0].rx==1800&&hosts[0].tx==900);
 message(AF_INET,22,"192.168.50.2","1.1.1.1","1.1.1.1",443,1000,2000,0x400,0);
 uint64_t saved_rx=hosts[0].rx,saved_tx=hosts[0].tx;
 message(AF_INET,22,"192.168.50.2","1.1.1.1","1.1.1.1",443,0,0,0,0);
 message(AF_INET,22,"192.168.50.2","1.1.1.1","1.1.1.1",443,1000,2000,0,0);
 assert(hosts[0].rx==saved_rx&&hosts[0].tx==saved_tx);
 puts("PASS native IPv4/IPv6 MAC merge, directions, LAN/router/DNS exclusion, proxy client only, baseline, reset, duplicate, destroy/dump race");
}
