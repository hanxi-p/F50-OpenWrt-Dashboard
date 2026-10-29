import {step} from './sessions.uc';
for(let round=0;round<3;round++){
 let m='02:11:22:33:44:55',peers={},s=null,events=[];peers[m]={online:true,connection:'wifi5',interface:'wlan0'};
 let r=step(s,peers,1700000000,'boot1',null,true);s=r.state;assert(length(r.events)==1&&r.events[0].type=='start');let id=s.open[m].id;
 r=step(s,peers,1700000001,'boot1',null,true);assert(!r.changed&&s.open[m].id==id,'repeat sample never duplicates session');
 r=step(s,{},1700000002,'boot1',null,false);assert(length(r.events)==0&&s.open[m],'failed scan cannot disconnect device');
 step(s,{},1700000003,'boot1',null,true);step(s,{},1700000004,'boot1',null,true);r=step(s,{},1700000005,'boot1',null,true);assert(length(r.events)==1&&!s.open[m]&&r.events[0].end==1700000001,'debounce and preserve last observed time');
 r=step(s,peers,1700000006,'boot1',null,true);assert(s.open[m].id!=id,'reconnect has a new session');
 peers[m].interface='wlan1';r=step(s,peers,1700000007,'boot1',null,true);assert(length(r.events)==2&&r.events[0].reason=='interface_change');
 let restored=json(sprintf('%J',s));r=step(restored,peers,1700000008,'boot1',null,true);assert(!r.changed,'collector restart in same boot preserves session');
 r=step(restored,peers,1700000009,'boot2',null,true);assert(length(r.events)==2&&r.events[0].reason=='observation_gap','reboot never fabricates continuous association');
 r=step(restored,peers,1700000030,'boot2',null,true);assert(length(r.events)==2&&r.events[0].reason=='observation_gap','stale observation explicitly marks gap');
}
print('PASS Wi-Fi sessions three rounds: dedup, failed scan, debounce, reconnect, interface switch, restart, reboot and stale gap\n');
