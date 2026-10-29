#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {readjson,atomic,calculate} from './ledger.uc';
import {usbPeers} from './peers.uc';
const R='/tmp/f50-devices', P='/etc/f50-devices';
fs.mkdir(R,0700);fs.mkdir(P,0700);
function cmd(s){let f=fs.popen(s,'r');if(!f)return '';let v=f.read('all');f.close();return v??'';}
let saved=fs.readfile(P+'/ledger.json');
let state=saved!=null?json(saved):{version:1,devices:{}};
if(!state || state.version!=1 || type(state.devices)!='object')die('invalid ledger: retained for recovery');
function mono(){let t=clock(true);return t[0]*1000+t[1]/1000000;}
function peers(){
 let p={};
 for(let line in split(fs.readfile('/tmp/dhcp.leases')??'','\n')){
  let a=split(trim(line),/\s+/);if(length(a)<4)continue;let m=lc(a[1]);
  if(match(m,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/))p[m]={ip:a[2],hostname:a[3]=='*'?'':a[3]};
 }
 for(let path in fs.glob('/sys/class/net/*/phy80211')){
  let iface=split(path,'/')[4];if(!match(iface,/^[a-zA-Z0-9_.:-]+$/))continue;
  let info=cmd('iw '+iface+' info'),freq=match(info,/\((\d+) MHz\)/);
  let group=freq&&+freq[1]<3000?'wifi24':'wifi5';
  let stations=cmd('iw '+iface+' station dump');
  for(let s in split(stations,'\n')){let n=match(s,/^Station ([0-9a-fA-F:]{17})/);if(n){let mac=lc(n[1]);p[mac]??={};p[mac].connection=group;p[mac].interface=iface;p[mac].online=true;}}
 }
 // Current Wi-Fi association takes precedence over USB bridge history.
 return usbPeers(p,cmd('bridge fdb show br br-lan'),cmd('ip -4 neigh show dev br-lan'),trim(fs.readfile('/sys/class/net/usb0/carrier')??'')=='1');
}
loop.init();let busy=false, timer;
function tick(){
 if(busy)return;busy=true;let start=mono();
 try{
  let src=fs.readfile(R+'/source');if(src){
   let result=calculate(state,src,peers(),readjson(P+'/aliases.json',{}),time(),trim(cmd('date +%F')),readjson(P+'/identities.json',{}));
   state=result.state;atomic(P+'/ledger.json',state);atomic(R+'/devices.json',result.public);
  }
 }catch(e){warn('f50-devices: '+e+'\n');}
 busy=false;timer.set(max(10,1000-(mono()-start)));
}
timer=loop.timer(1,tick);loop.run();
