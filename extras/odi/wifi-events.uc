#!/usr/bin/ucode
import * as fs from 'fs';
import * as ubus from 'ubus';
import * as loop from 'uloop';
import {normalize} from './wifi-normalize.uc';
const R='/tmp/odi',P='/etc/odi';fs.mkdir(R,0700);fs.mkdir(P,0700);
loop.init();let conn=ubus.connect();if(!conn)die('ubus unavailable');
let subscriptions={},pending=[],dropped=0,sequence=0,minute=-1,used=0,refreshAt=0;
const collector=trim(fs.readfile('/proc/sys/kernel/random/uuid')),boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id'));
function discover(){
 for(let path in fs.glob('/sys/class/net/*/phy80211')??[]){
  let iface=split(path,'/')[4];if(!match(iface,/^[a-zA-Z0-9_.:-]+$/))continue;
  let object='hostapd.'+iface;if(subscriptions[object])continue;
  let sub=conn.subscriber(function(event){
   // Never wait for persistence or deny an authentication/association request.
   try{let row=normalize(event.type,event.data,object,time());if(row){if(length(pending)<128){row.event_id=collector+'-'+(++sequence);push(pending,row);}else dropped++;}}catch(e){}
   return 0;
  },function(id){delete subscriptions[object];});
  if(sub&&sub.subscribe(object))subscriptions[object]=sub;else if(sub)sub.remove();
 }
}
function flush(){
 let now=time(),window=int(now/60);if(window!=minute){minute=window;used=0;}
 let rows=[],view={};try{view=json(fs.readfile(R+'/observations.json')??'{}');}catch(e){}
 for(let row in pending){
  if(used>=240){dropped++;continue;}used++;
  row.boot_id=boot;row.device_id=view.devices?.[row.mac]?.device_id??null;
  row.identity_state=view.devices?.[row.mac]?.identity_state??'unresolved';push(rows,sprintf('%J',row)+'\n');
 }
 pending=[];
 if(length(rows)){
  let path=P+'/wifi-events.jsonl',data=join('',rows),st=fs.stat(path);
  if((st?.size??0)+length(data)>524288&&!fs.rename(path,P+'/wifi-events.previous.jsonl'))die('event rotation failed');
  let f=fs.open(path,'a',0600);if(!f)die('event log unavailable');let n=f.write(data);f.close();if(n!=length(data))die('short event write');
 }
 let f=fs.open(R+'/wifi-events-status.json.new','w',0600);
 if(f){f.write(sprintf('%J',{version:1,timestamp:now,subscribed_objects:keys(subscriptions),dropped:dropped,received_events:sequence,source:'hostapd_notifications',collector_id:collector}));f.close();fs.rename(R+'/wifi-events-status.json.new',R+'/wifi-events-status.json');}
 if(now-refreshAt>=15){discover();refreshAt=now;}
}
discover();let timer;
timer=loop.timer(1,()=>{try{flush();}catch(e){warn('odi-wifi-events: '+e+'\n');}timer.set(2000);});
let signals=[];for(let signo in [2,15])push(signals,loop.signal(signo,()=>{try{flush();}catch(e){}loop.end();}));
loop.run();
