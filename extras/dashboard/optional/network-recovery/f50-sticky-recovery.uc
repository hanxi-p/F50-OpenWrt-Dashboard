#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {pinDecision} from './recovery-policy.uc';
const cfg=json(fs.readfile('/etc/mu300/network-recovery.json')),key=ARGV[0];
if(!match(key??'',/^\/run\/f50-sticky\.[A-Za-z0-9]+\/api.conf$/))die('private controller file required');
const main=cfg.main_group,group=cfg.fallback_group,tmp=substr(key,0,length(key)-8);
const ROUTE_SNAPSHOT='/run/f50-route-current.json';
function enc(s){let h=hexenc(s),out='';for(let i=0;i<length(h);i+=2)out+='%'+substr(h,i,2);return out;}
function api(path,name){
 let command='curl --config "'+key+'" -fsS --connect-timeout 1 --max-time 3 ';
 if(name!=null){let f=fs.open(tmp+'selection.json','w',0600);if(!f)return null;f.write(sprintf('%J',{name:name}));f.close();command+='-X PUT -H "Content-Type: application/json" --data-binary "@'+tmp+'selection.json" ';}
 let p=fs.popen(command+'"http://127.0.0.1:9090'+path+'" 2>/dev/null','r');if(!p)return null;let text=p.read('all'),rc=p.close();
 if(rc!=0)return null;if(name!=null)return true;try{return json(text);}catch(e){return null;}
}
let last='',next=0;
let routeRoot=null,routePoll=0;
function status(mode){if(mode==last)return;last=mode;let f=fs.open('/run/f50-sticky-recovery.json','w',0600);if(f){f.write(sprintf('%J',{mode:mode,time:time()}));f.close();}}
function publishRoute(){
 if(!cfg.notify_route||!routeRoot)return;
 let now=clock(true)[0];if(now<routePoll)return;routePoll=now+5;
 let p=routeRoot,seen=[];
 for(let i=0;i<6;i++){
  if(type(p?.now)=='string'&&length(p.now)){
   for(let name in seen)if(name==p.now)return;
   push(seen,p.now);p=api('/proxies/'+enc(p.now));if(!p)return;
  }else{
   if(type(p?.all)=='array'||type(p?.name)!='string'||!length(p.name))return;
   let f=fs.open(ROUTE_SNAPSHOT+'.new','w',0600);if(!f)return;
   f.write(sprintf('%J',{version:1,boot:trim(fs.readfile('/proc/sys/kernel/random/boot_id')??''),node:p.name,updated:time()}));f.close();
   fs.rename(ROUTE_SNAPSHOT+'.new',ROUTE_SNAPSHOT);return;
  }
 }
}
function tick(){
 let m=api('/proxies/'+enc(main));if(!m){status('controller-unavailable');return;}
 routeRoot=m;
 if(m.now!=group){status('manual-selection');return;}
 let g=api('/proxies/'+enc(group));if(!g||g.type!='Fallback'){status('incompatible-group');return;}
 routeRoot=g;
 if(g.fixed==g.now && g.now){status('holding-current');return;}
 let candidate=g.now?api('/proxies/'+enc(g.now)):null;
 let decision=pinDecision(m.now,g,candidate?.alive===true);
 if(!decision){status('waiting-for-usable-circuit');return;}
 let clockValue=clock(true)[0];if(clockValue<next)return;
 if(api('/proxies/'+enc(group),decision)){status('pinned-current-after-health-event');}
 else{next=clockValue+10;status('pin-retry-delayed');}
}
loop.init();let timer;
function run(){routeRoot=null;try{tick();}catch(e){status('controller-error');}try{publishRoute();}catch(e){}timer.set(2000);}
timer=loop.timer(1,run);loop.run();
