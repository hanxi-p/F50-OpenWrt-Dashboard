#include <stdio.h>
#include <string.h>
#include <assert.h>
extern int checkroute(void*,void*,int,int,int,int);
extern void setgroupbk(void*);
extern int checkarp(void*,void*);
int main(void){unsigned char netdev[3000]={0},priv[96]={0};int tests=0;int arp_tests=0;for(int round=0;round<3;round++)for(int mode=0;mode<9;mode++)for(int hw=0;hw<5;hw++){memcpy(netdev+2992,&mode,4);memcpy(priv+92,&hw,4);assert(checkarp(netdev,priv)==((mode==2||mode==6)&&hw==3));arp_tests++;}printf("PASS %d ARP classification cases\n",arp_tests);
 for(int round=0;round<3;round++)for(int mode=0;mode<9;mode++)for(int hw=0;hw<5;hw++)for(int dns=0;dns<2;dns++)for(int dhcp=0;dhcp<2;dhcp++)for(int vowifi=0;vowifi<2;vowifi++){
  memcpy(netdev+2992,&mode,4);memcpy(priv+92,&hw,4);int special=dns||dhcp||vowifi;
  int want=(dns&&!dhcp&&!vowifi&&(mode==2||mode==6)&&hw==3)?1:!special;
  assert(checkroute(netdev,priv,dns,dhcp,!vowifi,special)==want);tests++;
 }
 printf("PASS %d exact ARM instruction guard cases: AP/GO PCIe DNS returns data; DHCP, VoWiFi and other modes retain original selection.\n",tests);
 int desc_tests=0;for(int round=0;round<3;round++)for(int lut=0;lut<32;lut++)for(int tid=0;tid<256;tid++){
  unsigned char actual[16],want[16];for(int i=0;i<16;i++)actual[i]=0xa0+i;actual[6]=11;actual[10]=tid;actual[11]=lut;memcpy(want,actual,16);if(lut<6)want[10]=(tid&0xf0)|1;
  setgroupbk(actual);assert(!memcmp(actual,want,16));desc_tests++;
 }
 printf("PASS %d descriptor cases: group BK TID uses real descriptor, retaining prefix and unrelated bits.\n",desc_tests);return 0;
}
