import * as fs from 'fs';
function readjson(path, fallback) { try { return json(fs.readfile(path)); } catch(e) { return fallback; } }
function atomic(path, value) {
 let f=fs.open(path+'.new','w',0600); if(!f)die('open '+path+' failed');
 f.write(type(value)=='string'?value:sprintf('%J',value)); f.flush(); f.close();
 if(!fs.rename(path+'.new',path))die('rename '+path+' failed');
}
function calculate(state, source, peers, aliases, now, day) {
 state ??= {version:1,devices:{}}; let devices=state.devices, lines=split(trim(source),'\n');
 let month=substr(day,0,7);
 function initializeMonth(d){
  if(d.month_key!=month){
   // Legacy daily counters are attributable; lifetime bytes may span months.
   d.month_total=!d.month_key&&substr(d.day??'',0,7)==month?(d.today_rx??0)+(d.today_tx??0):0;
   d.month_key=month;
  }
 }
 let meta=split(lines[0], /\s+/); if(meta[0]!='sample'||length(meta)!=5)die('invalid source');
 let generation=meta[1], ms=+meta[2], stamp=+meta[3], errors=+meta[4];
 let valid=now-stamp<=4&&now>=stamp&&errors==0;
 for(let mac,peer in peers){devices[mac]??={today_rx:0,today_tx:0,total:0};for(let k,v in peer)devices[mac][k]=v;}
 let previousDay={};
 for(let mac,d in devices){
  previousDay[mac]=d.sample_day??d.day;
  initializeMonth(d);
  d.online=!!peers[mac]?.online;
  if(d.day!=day){d.today_rx=0;d.today_tx=0;d.day=day;}
  d.rx_rate=null;d.tx_rate=null;
 }
 for(let i=1;i<length(lines);i++){
  let a=split(trim(lines[i]),/\s+/),mac=lc(a[0]);
  if(length(a)!=6||!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/))continue;
  let rx=+a[2],tx=+a[4];if(rx<0||tx<0)continue;
  let d=devices[mac]??={today_rx:0,today_tx:0,total:0,day:day};
  initializeMonth(d);
  let elapsed=ms-(d.ms??0),same=d.generation==generation;
  if(valid&&same&&elapsed>0&&rx>=d.raw_rx&&tx>=d.raw_tx){
   let dr=rx-d.raw_rx,dt=tx-d.raw_tx;
   // A gap spanning dates cannot be reliably attributed to today's bucket.
   if(previousDay[mac]==day||elapsed<=4000){d.today_rx+=dr;d.today_tx+=dt;}
   if(substr(previousDay[mac]??'',0,7)==month||elapsed<=4000)d.month_total+=dr+dt;
   d.total+=dr+dt;
   if(elapsed<=4000){d.rx_rate=dr*1000/elapsed;d.tx_rate=dt*1000/elapsed;}
  }else if(valid&&same&&elapsed==0){d.rx_rate=d.last_rx_rate;d.tx_rate=d.last_tx_rate;}
  if(valid){d.generation=generation;d.ms=ms;d.raw_rx=rx;d.raw_tx=tx;d.last_rx_rate=d.rx_rate;d.last_tx_rate=d.tx_rate;d.sample_day=day;}
 }
 let rows=[];
 for(let mac,d in devices){push(rows,{mac:mac,ip:d.ip??'',name:aliases[mac]||d.hostname||mac,
  hostname:d.hostname??'',connection:d.connection??'unknown',interface:d.interface??'',online:!!d.online,
  rx_rate:valid?d.rx_rate:null,tx_rate:valid?d.tx_rate:null,today_rx:d.today_rx,today_tx:d.today_tx,month_total:d.month_total,total:d.total});}
 return {state:state,public:{timestamp:now,sample_timestamp:stamp,date:day,stale:!valid,errors:errors,devices:rows,
  scope:'IPv4 / IPv6 外网连接；透明代理按客户端段计数，排除内网目的地址'}};
}
export {readjson,atomic,calculate};
