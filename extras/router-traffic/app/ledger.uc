import * as fs from 'fs';
function readjson(path, fallback) { try { return json(fs.readfile(path)); } catch(e) { return fallback; } }
function atomic(path, value) {
 let f=fs.open(path+'.new','w',0600); if(!f)die('open '+path+' failed');
 f.write(type(value)=='string'?value:sprintf('%J',value)); f.flush(); f.close();
 if(!fs.rename(path+'.new',path))die('rename '+path+' failed');
}
function identity(mac, links) {
 if(type(links)!='object')return mac;
 let root=links[mac];
 if(type(root)!='string'||!match(root,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/))return mac;
 // Explicit one-level links only; cycles and chained guesses fail closed.
 if(links[root]!=null && links[root]!=root)return mac;
 return root;
}
function groupRows(rows, devices, aliases, links) {
 let groups={},out=[];
 for(let row in rows){let root=identity(row.mac,links);groups[root]??=[];push(groups[root],row);}
 for(let root,members in groups){
  let best=members[0];
  for(let row in members){
   let seen=devices[row.mac]?.last_seen??0,oldSeen=devices[best.mac]?.last_seen??0;
   if((row.online&&!best.online)||(row.online==best.online && (seen>oldSeen || (seen==oldSeen && row.mac!=root && best.mac==root))))best=row;
  }
  let merged={};for(let k,v in best)merged[k]=v;
  merged.identity_mac=root;
  merged.name=aliases[root]||aliases[best.mac]||best.hostname||best.mac;
  if(length(members)>1){
   merged.today_rx=0;merged.today_tx=0;merged.month_total=0;merged.total=0;merged.rx_rate=null;merged.tx_rate=null;merged.online=false;
   for(let row in members){
    for(let k in ['today_rx','today_tx','month_total','total'])merged[k]+=row[k]??0;
    if(row.online){merged.online=true;if(row.rx_rate!=null)merged.rx_rate=(merged.rx_rate??0)+row.rx_rate;if(row.tx_rate!=null)merged.tx_rate=(merged.tx_rate??0)+row.tx_rate;}
   }
  }
  push(out,merged);
 }
 return out;
}
function calculate(state, source, peers, aliases, now, day, identities) {
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
  if(d.online)d.last_seen=now;
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
 return {state:state,public:{timestamp:now,sample_timestamp:stamp,date:day,stale:!valid,errors:errors,devices:groupRows(rows,devices,aliases,identities),
  scope:'IPv4 / IPv6 外网连接；透明代理按客户端段计数，排除内网目的地址'}};
}
export {readjson,atomic,calculate,identity};
