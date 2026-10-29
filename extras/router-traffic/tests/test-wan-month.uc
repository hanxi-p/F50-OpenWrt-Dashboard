import {advance} from '../app/wan-ledger.uc';
for(let round=0;round<3;round++){
 let q={valid:true,boot:'a',device:'uplink',index:'4',ms:1000,timestamp:1793260800,date:'2026-10-29',hour:'2026-10-29-20',rx:10000,tx:20000};
 let old={version:1,date:q.date,hour:q.hour,daily_rx:1000,daily_tx:2000,session_rx:3000,session_tx:4000,total_rx:10,total_tx:20};
 let r=advance(old,q,true);assert(r.status.month_rx==1000&&r.status.month_tx==2000&&r.status.total_rx==3000&&r.status.total_tx==4000&&r.status.history_partial,'legacy known history retained without overlapping addition');
 r=advance(r.state,q,false);assert(r.status.total_rx==3000&&r.status.month_rx==1000,'upgrade and same sample idempotent');
 q={...q,ms:2000,rx:10100,tx:20200};r=advance(r.state,q,false);assert(r.status.month_rx==1100&&r.status.total_rx==3100,'month actual delta');
 q={...q,ms:3000,date:'2026-10-30',hour:'2026-10-30-00',rx:10300,tx:20500};r=advance(r.state,q,false);assert(r.status.daily_rx==0&&r.status.month_rx==1300&&r.status.total_rx==3300,'day boundary belongs to known month');
 q={...q,ms:4000,date:'2026-11-01',hour:'2026-11-01-00',rx:10600,tx:20900};r=advance(r.state,q,false);assert(r.status.month_rx==0&&r.status.total_rx==3600,'unknown month-boundary interval only belongs to lifetime');
 q={...q,ms:5000,rx:10850,tx:21400};r=advance(r.state,q,false);assert(r.status.month_rx==250&&r.status.month_tx==500,'new month observed usage');
 q={...q,boot:'b',ms:1000,rx:88888,tx:99999};r=advance(json(sprintf('%J',r.state)),q,true);assert(r.status.month_rx==250&&r.status.total_rx==3850,'persist/reboot retain month and lifetime without adding historical raw counter');
}
print('PASS monthly three rounds: safe legacy migration, idempotence, same month midnight, month reset, persistence/reboot\n');
