#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/ethtool.h>
#include <linux/sockios.h>
#include <net/if.h>

int main(int argc, char **argv) {
 if ((argc != 2 && argc != 3) || strlen(argv[1]) >= IFNAMSIZ || (argc == 3 && strcmp(argv[2],"--bytes"))) return 2;
 int fd=socket(AF_INET,SOCK_DGRAM,0); if(fd<0){perror("socket");return 1;}
 struct ifreq req={0};strcpy(req.ifr_name,argv[1]);
 struct {struct ethtool_sset_info info; unsigned count;} q={0};
 q.info.cmd=ETHTOOL_GSSET_INFO;q.info.sset_mask=1ULL<<ETH_SS_STATS;req.ifr_data=(void*)&q;
 if(ioctl(fd,SIOCETHTOOL,&req)<0){perror("GSSET_INFO");return 1;}
 unsigned n=q.count;if(!n||n>4096)return 1;
 struct ethtool_gstrings *names=calloc(1,sizeof(*names)+n*ETH_GSTRING_LEN);
 struct ethtool_stats *stats=calloc(1,sizeof(*stats)+n*sizeof(unsigned long long));
 if(!names||!stats)return 1;
 names->cmd=ETHTOOL_GSTRINGS;names->string_set=ETH_SS_STATS;names->len=n;req.ifr_data=(void*)names;
 if(ioctl(fd,SIOCETHTOOL,&req)<0){perror("GSTRINGS");return 1;}
 stats->cmd=ETHTOOL_GSTATS;stats->n_stats=n;req.ifr_data=(void*)stats;
 if(ioctl(fd,SIOCETHTOOL,&req)<0){perror("GSTATS");return 1;}
 unsigned long long rx=0,tx=0;int have_rx=0,have_tx=0;
 for(unsigned i=0;i<n;i++){
  const char *name=(const char *)names->data+i*ETH_GSTRING_LEN;
  if(argc==2)printf("%.*s %llu\n",ETH_GSTRING_LEN,name,(unsigned long long)stats->data[i]);
  if(!strncmp(name,"RxBytes",ETH_GSTRING_LEN)){rx=stats->data[i];have_rx=1;}
  if(!strncmp(name,"TxBytes",ETH_GSTRING_LEN)){tx=stats->data[i];have_tx=1;}
 }
 if(argc==3){if(!have_rx||!have_tx)return 1;printf("%llu %llu\n",rx,tx);}
 free(names);free(stats);close(fd);return 0;
}
