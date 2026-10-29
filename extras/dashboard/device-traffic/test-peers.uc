import {usbPeers} from './peers.uc';
function check(v,label){if(!v)die(label);}
let mac='02:11:22:33:44:55',fdb=mac+' dev usb0 master br-lan\n02:aa:bb:cc:dd:ee dev usb0 master br-lan permanent';
for(let round=0;round<3;round++){
 let p=usbPeers({},fdb,'192.0.2.7 lladdr '+mac+' REACHABLE',true);
 check(p[mac].online&&p[mac].connection=='wired'&&p[mac].interface=='usb0'&&p[mac].ip=='192.0.2.7','USB online and IP');
 check(!p['02:aa:bb:cc:dd:ee'],'permanent bridge MAC excluded');
 p=usbPeers({},fdb,'192.0.2.7 lladdr '+mac+' STALE',false);check(!p[mac].online&&!p[mac].connection,'unplugged not online');
 p={};p[mac]={online:true,connection:'wifi5',interface:'wlan0'};
 p=usbPeers(p,fdb,'',true);check(p[mac].interface=='wlan0'&&p[mac].connection=='wifi5','live Wi-Fi wins stale FDB');
 p=usbPeers({},mac+' dev wlan0 master br-lan','192.0.2.7 lladdr '+mac+' REACHABLE',true);check(!p[mac].online,'neighbour alone does not prove USB');
 p=usbPeers({},fdb,'',true);check(p[mac].online,'no DHCP lease required');
 p=usbPeers({},'malformed\n'+mac+' dev usb0 self','',true);check(!p[mac],'malformed or self records excluded');
 print('USB peer round '+(round+1)+' PASS\n');
}
