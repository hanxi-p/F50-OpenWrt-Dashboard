import {match_peer} from './f50-trusted-auth.uc';
let mac='02:11:22:33:44:55',entries={},wifi={clients:{}},ip='192.168.50.2',neighbor=ip+' lladdr '+mac+' REACHABLE',fdb=mac+' dev wlan0 master br-lan';entries[mac]={port:'wlan0'};wifi.clients[mac]={authorized:true,assoc:true};
let tests=0;function check(ok,msg){if(!ok)die('FAIL '+msg);tests++;}
for(let round=0;round<3;round++){
 check(!!match_peer(ip,entries,neighbor,fdb,wifi),'allowed associated client');
 check(!match_peer(ip,{},neighbor,fdb,wifi),'unknown MAC denied');
 check(!match_peer('127.0.0.1',entries,'127.0.0.1 lladdr '+mac+' REACHABLE',fdb,wifi),'loopback denied');
 check(!match_peer(ip,entries,neighbor+' FAILED',fdb,wifi),'failed neighbor denied');
 check(!match_peer(ip,entries,neighbor,mac+' dev usb0 master br-lan',wifi),'wrong port denied');
 check(!match_peer(ip,entries,neighbor,fdb+' permanent',wifi),'permanent bridge entry denied');
 check(!match_peer(ip,entries,neighbor,fdb,{clients:{}}),'disconnected client denied');
 wifi.clients[mac].authorized=false;check(!match_peer(ip,entries,neighbor,fdb,wifi),'unauthorized client denied');wifi.clients[mac].authorized=true;
 wifi.clients[mac].assoc=false;check(!match_peer(ip,entries,neighbor,fdb,wifi),'unassociated client denied');wifi.clients[mac].assoc=true;
 check(!match_peer(ip,entries,neighbor,fdb+'\n'+mac+' dev usb0 master br-lan',wifi),'conflicting bridge ports denied');
 check(!match_peer('192.168.50.99',entries,neighbor,fdb,wifi),'other IP cannot use trusted neighbor');
 check(!!match_peer('fd51::2',entries,'fd51::2 lladdr '+mac+' STALE',fdb,wifi),'IPv6 trusted peer');
}
print(sprintf('PASS %d trusted MAC/interface/association boundary assertions\n',tests));
