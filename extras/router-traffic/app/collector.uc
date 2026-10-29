#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {readjson,atomic,calculate} from './ledger.uc';
import {peers} from './peers.uc';
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
loop.init();let timer,terminating=false;
function tick(){
 let start=mono();
 try{
  let date=wan(start),source=fs.readfile(R+'/source');
  if(source){let calculated=calculate(state,source,peers(cfg.lan_device),readjson(P+'/aliases.json',{}),time(),date,readjson(P+'/identities.json',{}));state=calculated.state;calculated.public.collector_id=cfg.install_id;atomic(R+'/ledger.json',state);atomic(R+'/devices.json',calculated.public);}
  if(start-lastSave>=60000)save();
 }catch(e){warn('router-traffic: '+e+'\n');}
 if(!terminating)timer.set(max(20,1000-(mono()-start)));
}
let signals=[];for(let signo in [15,2])push(signals,loop.signal(signo,()=>{terminating=true;save();loop.end();}));
timer=loop.timer(1,tick);loop.run();
