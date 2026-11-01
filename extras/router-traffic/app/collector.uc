#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {filterRemoved} from './controls.uc';
import {readjson,atomic,calculate} from './ledger.uc';
import {observations} from './peers.uc';
import {derive,annotate} from './profiles.uc';
import {step as sessionStep,append as appendSessions} from './sessions.uc';
import {advance} from './wan-ledger.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
let cfg=readjson(P+'/config.json',{});
if(!match(cfg.lan_device??'',/^[a-zA-Z0-9_.:-]+$/)||!match(cfg.wan_network??'',/^[a-zA-Z0-9_]+$/))die('invalid interface configuration');
fs.mkdir(P,0700);fs.mkdir(R,0700);
let raw=fs.readfile(R+'/ledger.json')??fs.readfile(P+'/ledger.json');
let state=raw!=null?json(raw):{version:1,devices:{}};
if(state.version!=1||type(state.devices)!='object')die('invalid ledger retained');
function command(s){let p=fs.popen(s,'r');if(!p)return '';let value=p.read('all');p.close();return value??'';}
function mono(){let c=clock(true);return c[0]*1000+c[1]/1000000;}
const W=getenv('ROUTER_TRAFFIC_WAN_RUNTIME_DIR')??'/tmp/f50-traffic';
fs.mkdir(W,0700);
let wanRaw=fs.readfile(R+'/wan-ledger.json')??fs.readfile(P+'/wan-ledger.json');
let wanState=wanRaw!=null?json(wanRaw):{version:1};
if(wanState.version!=1)die('invalid WAN ledger retained');
let lastSave=mono(),wanDevice='',nextResolve=0,history=[],firstWan=true;
for(let line in split(trim(fs.readfile(W+'/history.csv')??''),'\n')){let a=split(trim(line),/\s+/);if(length(a)==3&&+a[0]>0&&+a[1]>=0&&+a[2]>=0)push(history,[+a[0],+a[1],+a[2]]);}
history=slice(history,-320);
function save(){atomic(P+'/ledger.json',state);atomic(P+'/wan-ledger.json',wanState);lastSave=mono();}
function wan(now){
 if(now>=nextResolve){
  let net;try{net=json(command('ubus call network.interface.'+cfg.wan_network+' status'));}catch(e){}
  let candidate=net?.l3_device??net?.device;
  wanDevice=match(candidate??'',/^[a-zA-Z0-9_.:-]+$/)?candidate:'';nextResolve=now+10000;
 }
 let base='/sys/class/net/'+wanDevice+'/statistics/',rx=fs.readfile(base+'rx_bytes'),tx=fs.readfile(base+'tx_bytes'),index=fs.readfile('/sys/class/net/'+wanDevice+'/ifindex');
 let measured=mono();
 let hour=trim(command('date +%F-%H')),date=substr(hour,0,10);
 let current={valid:rx!=null&&tx!=null&&index!=null,boot:trim(fs.readfile('/proc/sys/kernel/random/boot_id')??''),device:wanDevice,index:trim(index??''),rx:+rx,tx:+tx,ms:measured,timestamp:time(),date:date,hour:hour};
 let result=advance(wanState,current,firstWan);wanState=result.state;firstWan=false;
 let data=result.status;data.collector_id=cfg.install_id;
 if(data.rx_rate!=null)push(history,[current.timestamp,data.rx_rate,data.tx_rate]);
 if(length(history)>320)history=slice(history,-320);
 atomic(R+'/wan-ledger.json',wanState);atomic(W+'/status.json',data);
 let rows=[];for(let row in history)push(rows,sprintf('%d %.6f %.6f',row[0],row[1],row[2]));atomic(W+'/history.csv',join('\n',rows)+'\n');
 data.history=history;data.show_wan=cfg.show_wan!==false;atomic(R+'/wan.json',data);
 return date;
}
let sessionState=readjson(P+'/sessions.json',null),sessionSave=0,sessionWarn=0,sessionPending=[],sessionDirty=false,profileTry=0,boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')??'');
loop.init();let timer,terminating=false;
function tick(){
 let start=mono();
 try{
  let date=wan(start),source=fs.readfile(R+'/source');
  if(source){
   let obs=observations(cfg.lan_device),registry=readjson(P+'/profiles.json',null),d=registry?derive(registry):null;
   for(let mac,peer in obs.peers){
    let old=state.devices[mac];
    if(!old&&!peer.online){delete obs.peers[mac];continue;}
    if(peer.online&&!peer.ip&&!old?.ip&&!(old?.total>0))delete obs.peers[mac];
   }
   let controls=readjson(P+'/actions.json',{}),beforeRemoved=sprintf('%J',state.removed??{});
   function archive(id,snapshot){fs.mkdir(P+'/deleted-archive',0700);let path=P+'/deleted-archive/'+id+'.json';if(!fs.stat(path))atomic(path,snapshot);}
   let filtered=filterRemoved(state,source,obs.peers,d?.links??readjson(P+'/identities.json',{}),controls,archive,obs.valid,boot);
   let calculated=calculate(state,filtered.source,filtered.peers,d?.aliases??readjson(P+'/aliases.json',{}),time(),date,d?.links??readjson(P+'/identities.json',{}));state=calculated.state;atomic(R+'/ledger.json',state);
   let missing=!registry;for(let mac in state.devices)if(!registry?.bindings?.[mac])missing=true;
   let st=fs.stat('/etc/config/router_traffic_devices'),signature=st?sprintf('%s:%s',st.mtime,st.size):'';
   if((missing||signature!=registry?.config_signature)&&start>=profileTry){profileTry=start+10000;let answer;try{answer=json(command('/usr/libexec/router-traffic/profile-action sync'));}catch(e){}if(answer?.ok){registry=readjson(P+'/profiles.json',registry);d=registry?derive(registry):null;filtered=filterRemoved(state,source,obs.peers,d?.links??{},controls,archive,obs.valid,boot);calculated=calculate(state,filtered.source,filtered.peers,d?.aliases??{},time(),date,d?.links??{});state=calculated.state;}}
   try{
    let result=sessionStep(sessionState,obs.peers,time(),boot,registry,obs.valid);sessionState=result.state;sessionDirty=sessionDirty||result.changed;
    for(let event in result.events)push(sessionPending,event);sessionPending=slice(sessionPending,-200);appendSessions(P+'/sessions.jsonl',sessionPending);sessionPending=[];atomic(R+'/sessions.json',sessionState);
    if(sessionDirty||start-sessionSave>=60000){atomic(P+'/sessions.json',sessionState);sessionDirty=false;sessionSave=start;}
   }catch(e){if(start-sessionWarn>=60000){warn('router-traffic-sessions: '+e+'\n');sessionWarn=start;}}
   if(beforeRemoved!=sprintf('%J',state.removed??{}))atomic(P+'/ledger.json',state);
   calculated.public.devices=filter(calculated.public.devices,function(d){return d.online||d.ip||d.total>0;});
   annotate(calculated.public.devices,registry);calculated.public.profile_revision=registry?.revision??null;calculated.public.collector_id=cfg.install_id;atomic(R+'/devices.json',calculated.public);
  }
  if(start-lastSave>=60000)save();
 }catch(e){warn('router-traffic: '+e+'\n');}
 if(!terminating)timer.set(max(20,1000-(mono()-start)));
}
let signals=[];for(let signo in [15,2])push(signals,loop.signal(signo,()=>{terminating=true;save();loop.end();}));
timer=loop.timer(1,tick);loop.run();
