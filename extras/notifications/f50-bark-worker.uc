#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {advance,parseSMS} from './f50-bark-state.uc';
const D='/etc/mu300/bark',Q=D+'/outbox',S=D+'/sent',POOL='/etc/mu300/sms-pool/msg';
function load(path,fallback){let t=fs.readfile(path);if(t==null)return fallback;try{return json(t);}catch(e){die('invalid Bark state retained');}}
function put(path,value){let f=fs.open(path+'.new','w',0600);if(!f)die('Bark state write failed');f.write(sprintf('%J',value));f.close();if(!fs.rename(path+'.new',path))die('Bark atomic rename failed');if(substr(path,0,5)=='/etc/')system('sync >/dev/null 2>&1');}
function command(s){let f=fs.popen(s,'r');if(!f)return '';let t=f.read('all');f.close();return trim(t??'');}
const WX='/etc/mu300/wxpusher',WX_FIRST=+trim(fs.readfile(WX+'/first-id')??'0');
function wxEligible(id){return WX_FIRST>0 && (substr(id,0,4)!='sms-' || +substr(id,4)>=WX_FIRST);}
function queue(id,payload){
 payload.created=time();payload.id=id;
 if(wxEligible(id) && !fs.stat(WX+'/sent/'+id) && !fs.stat(WX+'/outbox/'+id))put(WX+'/outbox/'+id,payload);
 if(fs.stat(S+'/'+id)||fs.stat(Q+'/'+id))return;
 put(Q+'/'+id,payload);
}
let state=load(D+'/state.json',{version:1,boot:'',health:{}});
if(state.version!=1||type(state.health)!='object')die('unsupported Bark state retained');
const boot=trim(fs.readfile('/proc/sys/kernel/random/boot_id')??'');
const first=+trim(fs.readfile(D+'/first-id')??'0');
if(!first)die('Bark SMS baseline missing');
let changed=false;
if(!state.boot){state.boot=boot;put(D+'/state.json',state);}
else if(state.boot!=boot){queue('boot-'+boot,{title:'F50 已重新启动',body:'设备已启动，正在检查无线、DNS和联网状态。'});state.boot=boot;state.pending_boot=true;state.health={};put(D+'/state.json',state);}
function mono(){let t=clock(true);return t[0]+t[1]/1000000000;}
let retry={},lastHealth=-30,lastHeartbeat=-300;
const labels={wifi:'无线服务',dns:'DNS解析',wan:'外网连接',devices:'设备流量采集',kernel:'无线/内核严重错误'};
function collectSMS(){
 for(let path in fs.glob(POOL+'/[0-9]*')){
  let id=substr(path,length(POOL)+1);if(!match(id,/^[0-9]+$/)||+id<first)continue;
  let event='sms-'+id;
  let barkKnown=fs.stat(S+'/'+event)||fs.stat(Q+'/'+event);
  let wxKnown=!wxEligible(event)||fs.stat(WX+'/sent/'+event)||fs.stat(WX+'/outbox/'+event);
  if(barkKnown && wxKnown)continue;
  let raw=fs.readfile(path);if(raw==null)continue;
  let payload=parseSMS(raw);if(payload)queue('sms-'+id,payload);
 }
}
function health(){
 let uptime=+(split(fs.readfile('/proc/uptime')??'0',' ')[0]);if(uptime<180)return;
 let result={};
 result.wifi=trim(fs.readfile('/sys/class/net/wlan0/operstate')??'')=='up' && system('/usr/libexec/f50-bounded 4 ubus call hostapd.wlan0 get_clients >/dev/null 2>&1')==0;
 result.dns=system('/usr/libexec/f50-bounded 5 nslookup www.baidu.com 127.0.0.1 >/dev/null 2>&1')==0;
 result.wan=system('curl -fsS --connect-timeout 3 --max-time 5 https://1.1.1.1/ -o /dev/null 2>/dev/null')==0;
 let src=fs.stat('/tmp/f50-devices/source'),view=fs.stat('/tmp/f50-devices/devices.json');result.devices=src!=null && view!=null && time()-src.mtime<20 && time()-view.mtime<20;
 let recent=false;
 for(let line in split(command('dmesg 2>/dev/null'),'\n')){
  let stamp=match(line,/^\[\s*([0-9.]+)\]/);
  if(stamp && +stamp[1]>=uptime-90 && match(line,/edma.*push.*link.*fail|tx[_ ]?return.*err|Kernel panic|Oops:|NETDEV WATCHDOG|(^|[^A-Za-z0-9_])BUG:|firmware.*(crash|assert)|sprdwl.*(assert|hang)/i)){recent=true;break;}
 }
 result.kernel=!recent;
 changed=false;
 for(let key,value in result){
  let event=advance(state.health,key,value);
  if(event){let id=key+'-'+boot+'-'+state.health[key].seq+'-'+event;queue(id,{title:event=='fault'?'F50 故障：'+labels[key]:'F50 恢复：'+labels[key],body:(event=='fault'?'持续异常，已连续三次检查确认。':'已连续两次检查正常。')+'\n发生时间：'+command('date "+%F %T %Z"')});changed=true;}
 }
 if(state.pending_boot){let ready=true;for(let k,v in result)if(!v||state.health[k].good<2)ready=false;if(ready){queue('ready-'+boot,{title:'F50 设备已恢复正常',body:'重启后无线、DNS、外网、设备流量采集及严重错误检查连续两次正常。'});state.pending_boot=false;changed=true;}}
 if(changed)put(D+'/state.json',state);
 put('/run/f50-bark-health.json',{checked:time(),checks:result,queue:length(fs.glob(Q+'/*'))});
}
function deliver(){
 let items=fs.glob(Q+'/*');sort(items);
 for(let path in items){let id=substr(path,length(Q)+1);if(!match(id,/^[a-zA-Z0-9_-]+$/))continue;
  if(fs.stat(S+'/'+id)){fs.unlink(path);continue;}
  let attempt=retry[id]??{failures:0,next:0};if(mono()<attempt.next)continue;
  if(system('/usr/libexec/f50-bark-send "'+path+'" >/dev/null 2>&1')==0){put(S+'/'+id,{sent:time()});fs.unlink(path);delete retry[id];}
  else{attempt.failures++;attempt.next=mono()+min(600,30*(2**min(5,attempt.failures-1)));retry[id]=attempt;}
  break;
 }
}
loop.init();let timer;
function tick(){try{collectSMS();if(mono()-lastHealth>=30){health();lastHealth=mono();}deliver();if(mono()-lastHeartbeat>=300){state.last_seen=time();put(D+'/state.json',state);lastHeartbeat=mono();}}catch(e){warn('f50-bark: worker operation failed; pending messages retained\n');}timer.set(10000);}
timer=loop.timer(1,tick);loop.run();
