#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {readjson,atomic,calculate} from './ledger.uc';
import {step as sessionStep,append as appendSessions} from './sessions.uc';
import {derive,annotate} from './profiles.uc';
import {filterRemoved} from './controls.uc';
import {usbPeers} from './peers.uc';
const R='/tmp/f50-devices', P='/etc/f50-devices';
fs.mkdir(R,0700);fs.mkdir(P,0700);
function cmd(s){let f=fs.popen(s,'r');if(!f)return '';let v=f.read('all');f.close();return v??'';}
let saved=fs.readfile(P+'/ledger.json');
let state=saved!=null?json(saved):{version:1,devices:{}};
if(!state || state.version!=1 || type(state.devices)!='object')die('invalid ledger: retained for recovery');
function mono(){let t=clock(true);return t[0]*1000+t[1]/1000000;}
let sessionScanValid=true;
function peers(){
 sessionScanValid=true;
 let p={};
 for(let line in split(fs.readfile('/tmp/dhcp.leases')??'','\n')){
  let a=split(trim(line),/\s+/);if(length(a)<4)continue;let m=lc(a[1]);
  if(match(m,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/))p[m]={ip:a[2],hostname:a[3]=='*'?'':a[3]};
 }
 for(let path in fs.glob('/sys/class/net/*/phy80211')){
  let iface=split(path,'/')[4];if(!match(iface,/^[a-zA-Z0-9_.:-]+$/))continue;
  let info=cmd('iw '+iface+' info'),freq=match(info,/\((\d+) MHz\)/);
  let group=freq&&+freq[1]<3000?'wifi24':'wifi5';
  let scan=fs.popen('iw '+iface+' station dump','r'),stations=scan?.read('all')??'';if(!scan||scan.close()!=0)sessionScanValid=false;
  for(let s in split(stations,'\n')){let n=match(s,/^Station ([0-9a-fA-F:]{17})/);if(n){let mac=lc(n[1]);p[mac]??={};p[mac].connection=group;p[mac].interface=iface;p[mac].online=true;}}
 }
 // Current Wi-Fi association takes precedence over USB bridge history.
 return usbPeers(p,cmd('bridge fdb show br br-lan'),cmd('ip -4 neigh show dev br-lan'),trim(fs.readfile('/sys/class/net/usb0/carrier')??'')=='1');
}
let sessionState=readjson(P+'/sessions.json',null),sessionSave=0,sessionWarn=0,sessionPending=[],sessionDirty=false,boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')??'');
loop.init();let busy=false, timer,nextProfileTry=0;
function tick(){
 if(busy)return;busy=true;let start=mono();
 try{
  let src=fs.readfile(R+'/source');if(src){
   let registry=readjson(P+'/profiles.json',null),derived=registry?derive(registry):null;
   let links=derived?.links??readjson(P+'/identities.json',{}),controls=readjson(P+'/actions.json',{});
   let observed=peers();
   // Discovery metadata alone is not a connection. Retain established history,
   // but wait for an address before admitting a new station on this driver.
   for(let mac,peer in observed){
    let old=state.devices[mac];
    if(!old && !peer.online){delete observed[mac];continue;}
    if(peer.online && !peer.ip && !old?.ip && !(old?.total>0))delete observed[mac];
   }
   try{
    let sessions=sessionStep(sessionState,observed,time(),boot,registry,sessionScanValid);sessionState=sessions.state;sessionDirty=sessionDirty||sessions.changed;
    for(let event in sessions.events)push(sessionPending,event);sessionPending=slice(sessionPending,-200);
    appendSessions(P+'/sessions.jsonl',sessionPending);sessionPending=[];atomic(R+'/sessions.json',sessionState);
    if(sessionDirty||start-sessionSave>=60000){atomic(P+'/sessions.json',sessionState);sessionSave=start;sessionDirty=false;}
   }catch(e){if(start-sessionWarn>=60000){warn('f50-sessions: '+e+'\n');sessionWarn=start;}}
   let filtered=filterRemoved(state,src,observed,links,controls,function(id,snapshot){fs.mkdir(P+'/deleted-archive',0700);atomic(P+'/deleted-archive/'+id+'.json',snapshot);});
   let result=calculate(state,filtered.source,filtered.peers,derived?.aliases??readjson(P+'/aliases.json',{}),time(),trim(cmd('date +%F')),links);
   result.public.control_version=1;
   state=result.state;atomic(P+'/ledger.json',state);
   let missing=!registry;for(let mac in state.devices)if(!registry?.bindings?.[mac])missing=true;
   let st=fs.stat('/etc/config/f50_devices'),signature=st?sprintf('%s:%s',st.mtime,st.size):'';
   if((missing||registry?.config_signature!=signature)&&start>=nextProfileTry){
    nextProfileTry=start+10000;let answer;try{answer=json(cmd('/usr/libexec/f50-devices/profile-action sync'));}catch(e){}
    if(answer?.ok){registry=readjson(P+'/profiles.json',registry);if(registry){derived=derive(registry);result=calculate(state,filtered.source,filtered.peers,derived.aliases,time(),trim(cmd('date +%F')),derived.links);state=result.state;}}
   }
   result.public.control_version=1;result.public.profile_revision=registry?.revision??null;
   // Quarantine old discovery-only rows in the visible table; preserve the raw
   // ledger and profiles so an actually returning device can recover its identity.
   result.public.devices=filter(result.public.devices,function(d){return d.online||d.ip||d.total>0;});
   annotate(result.public.devices,registry);atomic(R+'/devices.json',result.public);
  }
 }catch(e){warn('f50-devices: '+e+'\n');}
 busy=false;timer.set(max(10,1000-(mono()-start)));
}
timer=loop.timer(1,tick);loop.run();
