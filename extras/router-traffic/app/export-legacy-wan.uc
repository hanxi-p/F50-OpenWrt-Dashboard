#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic} from './ledger.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
const L=getenv('ROUTER_TRAFFIC_LEGACY_STATE')??'/etc/f50-traffic/state';
let state=readjson(R+'/wan-ledger.json',readjson(P+'/wan-ledger.json',null));
if(!state)exit(0);
if(!match(state.date??'',/^\d{4}-\d{2}-\d{2}$/)||!match(state.hour??'',/^\d{4}-\d{2}-\d{2}-\d{2}$/)||!match(state.last?.device??'',/^[a-zA-Z0-9_.:-]+$/)){warn('No valid WAN baseline to export; previous checkpoint retained\n');exit(0);}
let rows=[sprintf("DATE_KEY='%s'",state.date),sprintf("HOUR_KEY='%s'",state.hour),sprintf("LAST_DEVICE='%s'",state.last.device),sprintf('LAST_RX=%.0f',state.last.rx),sprintf('LAST_TX=%.0f',state.last.tx),sprintf('LAST_SAVE=%d',time())];
for(let key in ['daily_rx','daily_tx','hour_rx','hour_tx','peak_rx','peak_tx'])push(rows,sprintf('%s=%.0f',uc(key),state[key]??0));
let parts=split(L,'/');pop(parts);fs.mkdir(join('/',parts),0700);atomic(L,join('\n',rows)+'\n');
