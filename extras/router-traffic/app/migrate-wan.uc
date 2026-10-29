#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic} from './ledger.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
const L=getenv('ROUTER_TRAFFIC_LEGACY_STATE')??'/etc/f50-traffic/state',W=getenv('ROUTER_TRAFFIC_WAN_RUNTIME_DIR')??'/tmp/f50-traffic';
if(fs.stat(P+'/wan-ledger.json')){print('WAN ledger retained\n');exit(0);}
let values={};
for(let line in split(fs.readfile(L)??'','\n')){
 let m=match(line,/^([A-Z_]+)='?([a-zA-Z0-9_.:-]+)'?$/);if(m)values[m[1]]=m[2];
}
function number(v){return match(''+(v??''),/^[0-9]+(\.[0-9]+)?$/)?+v:0;}
let old=readjson(W+'/status.json',{}),date=old.date??values.DATE_KEY??'',hour=old.hour??values.HOUR_KEY??'';
let result={version:1,date:date,hour:hour,total_rx:0,total_tx:0,session_rx:0,session_tx:0,migration:'legacy totals retained; previous peak/sample timing cannot be reconstructed'};
for(let key in ['daily_rx','daily_tx','hour_rx','hour_tx','peak_rx','peak_tx']){
 let comparable=(substr(key,0,5)=='hour_'?values.HOUR_KEY==hour:values.DATE_KEY==date);
 result[key]=max(number(old[key]),comparable?number(values[uc(key)]):0);
}
let live=ARGV[0]=='stopped-live'&&old.timestamp&&time()-old.timestamp>=0&&time()-old.timestamp<=15;
if(live){result.session_rx=number(old.rx_total);result.session_tx=number(old.tx_total);}
let aligned=live&&values.DATE_KEY==date&&values.HOUR_KEY==hour&&values.LAST_DEVICE==old.device&&match(old.device??'',/^[a-zA-Z0-9_.:-]+$/);
for(let key in ['daily_rx','daily_tx','hour_rx','hour_tx'])if(number(values[uc(key)])!=number(old[key]))aligned=false;
if(aligned){
 let index=fs.readfile('/sys/class/net/'+old.device+'/ifindex'),tick=clock(true);
 if(index)result.last={boot:trim(fs.readfile('/proc/sys/kernel/random/boot_id')??''),device:old.device,index:trim(index),ms:max(0,tick[0]*1000+tick[1]/1000000-(time()-old.timestamp)*1000),timestamp:old.timestamp,date:date,hour:hour,rx:number(values.LAST_RX),tx:number(values.LAST_TX)};
}
fs.mkdir(P,0700);fs.mkdir(R,0700);atomic(P+'/wan-ledger.json',result);atomic(R+'/wan-ledger.json',result);
print(sprintf('%J',{imported:true,legacy_date:date,live:!!live,raw_baseline_bound:!!result.last,legacy_peaks_preserved:true}));
