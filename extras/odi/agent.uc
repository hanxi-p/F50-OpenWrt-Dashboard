#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {macOK,lease,radio} from './normalize.uc';
import {suggest} from './identity.uc';
const R='/tmp/odi',P='/etc/odi';
fs.mkdir(R,0700);fs.mkdir(P,0700);
function atomic(path,data){let f=fs.open(path+'.new','w',0600);if(!f)die('cannot write ODI state');f.write(sprintf('%J',data));f.close();if(!fs.rename(path+'.new',path))die('cannot rename ODI state');}
let saved=fs.readfile(P+'/observations.json'),state=saved?json(saved):{version:1,router_id:trim(fs.readfile('/proc/sys/kernel/random/uuid')),devices:{}};
if(state?.version!=1||type(state.devices)!='object')die('invalid ODI state retained');
function command(s){let f=fs.popen(s,'r');if(!f)return {ok:false};let text=f.read('all');let status=f.close();return {ok:status==0,text:text};}
function ubus(object,method){let r=command('ubus -t 2 call '+object+' '+method+' 2>/dev/null');if(!r.ok)return null;try{return json(r.text);}catch(e){return null;}}
let lastSave=0,stopping=false,timer;
function persist(){atomic(P+'/observations.json',state);}
function tick(){
 let now=time(),observed={},capabilities={hostapd:[],mdns:false,dhcp:'lease_file',ipv6:'neighbour_only',dhcp_options:false,ssdp:false};
 function add(mac,source,value){
  if(!macOK(mac)||length(sprintf('%J',value))>16384)return;mac=lc(mac);
  observed[mac]??={mac:mac,sources:{}};
  observed[mac].sources[source]={observed_at:now,expires_at:now+90,value:value};
 }
 try{
  for(let line in split(fs.readfile('/tmp/dhcp.leases')??'','\n')){let v=lease(line,now);if(v)add(v.mac,'dhcp_lease',v);}
  for(let path in fs.glob('/sys/class/net/*/phy80211')){
   let iface=split(path,'/')[4];if(!match(iface,/^[a-zA-Z0-9_.:-]+$/))continue;
   let result=ubus('hostapd.'+iface,'get_clients');if(!result)continue;
   push(capabilities.hostapd,iface);
   for(let mac,client in result.clients??{})add(mac,'wifi:'+iface,{interface:iface,frequency:result.freq??null,...radio(client)});
  }
  for(let family in ['-4','-6']){
   let result=command('ip '+family+' neigh show 2>/dev/null');if(!result.ok)continue;
   for(let line in split(result.text,'\n')){
    let m=match(line,/^(\S+) dev ([a-zA-Z0-9_.:-]+).*lladdr ([0-9a-fA-F:]{17})\s+(\S+)/);
    if(m)add(m[3],'neighbour:'+family+':'+m[1],{address:m[1],interface:m[2],state:m[4],connection_evidence:false});
   }
  }
  for(let path in fs.glob(R+'/dhcp/*.json')??[]){
   try{let e=json(fs.readfile(path));
    if(e?.version!=1||!macOK(e.mac)||e.observed_at>now+30||now-e.observed_at>86400)continue;
    add(e.mac,'dhcp_event',e);
    observed[e.mac].sources.dhcp_event.observed_at=e.observed_at;
    observed[e.mac].sources.dhcp_event.expires_at=e.observed_at+86400;
    if(e.vendor_class||e.requested_options)capabilities.dhcp_options=true;
   }catch(e){}
  }
  capabilities.dhcp_event_hook=fs.stat('/etc/hotplug.d/dhcp/90-odi')!=null;
  let services=ubus('umdns','browse');capabilities.mdns=services!=null;
  // mDNS remains a separate, timestamped snapshot. No guessed MAC association.
  if(services&&length(sprintf('%J',services))<=262144)atomic(R+'/mdns.json',{version:1,observed_at:now,expires_at:now+90,data:services});
  for(let mac,v in observed){
   let previous=state.devices[mac];state.devices[mac]={...v,sources:{...(previous?.sources??{}),...v.sources},first_seen:previous?.first_seen??now,last_seen:now,expires_at:now+90,identity_state:'unclassified'};
   let sourceNames=sort(keys(state.devices[mac].sources),function(a,b){return state.devices[mac].sources[b].observed_at-state.devices[mac].sources[a].observed_at;});
   for(let i=64;i<length(sourceNames);i++)delete state.devices[mac].sources[sourceNames[i]];
  }
  for(let mac,v in state.devices)if(now-v.last_seen>604800)delete state.devices[mac];
  let ordered=sort(keys(state.devices),function(a,b){return state.devices[b].last_seen-state.devices[a].last_seen;});
  for(let i=1024;i<length(ordered);i++)delete state.devices[ordered[i]];
  atomic(R+'/observations.json',{version:1,timestamp:now,mode:'observation_only',capabilities:capabilities,devices:state.devices});
  try{
   let registry=json(fs.readfile('/etc/f50-devices/profiles.json')??'null');
   let candidates=suggest(state.devices,registry,now);candidates.router_id=state.router_id;
   atomic(R+'/candidates.json',candidates);
  }catch(e){atomic(R+'/candidates.json',{version:1,timestamp:now,mode:'shadow_only',error:'identity_unavailable'});}
  if(now-lastSave>=600){persist();lastSave=now;}
 }catch(e){warn('odi-agent: '+e+'\n');}
 if(!stopping)timer.set(30000);
}
loop.init();let signals=[];
for(let signo in [2,15])push(signals,loop.signal(signo,()=>{stopping=true;persist();loop.end();}));
timer=loop.timer(1,tick);loop.run();
