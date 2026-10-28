import {calculate} from './ledger.uc';
let m='02:11:22:33:44:55', day='2026-10-28';let n=0;
function check(ok,msg){if(!ok)die('FAIL '+msg);print('PASS '+msg+'\n');n++;}
function sample(gen,ms,rx,tx){return sprintf('sample %s %d %d 0\n%s 0 %d 0 %d 0\n',gen,ms,1793116800+ms/1000,m,rx,tx);}
function run(s,g,ms,rx,tx,d,peers){return calculate(s,sample(g,ms,rx,tx),peers??{}, {},1793116800+ms/1000,d??day);}
for(let round=0;round<3;round++){
 let r=run(null,'a',1000,900000,500000);check(r.state.devices[m].total==0&&r.public.devices[0].rx_rate==null,'first sample baseline');
 r=run(r.state,'a',2250,901000,500500);check(r.state.devices[m].total==1500&&r.public.devices[0].rx_rate==800,'direction and actual 1.25s interval');
 r=run(r.state,'a',2250,901000,500500);check(r.state.devices[m].total==1500&&r.public.devices[0].rx_rate==800,'duplicate read idempotent');
 r=run(r.state,'a',3250,901000,500500);check(r.public.devices[0].rx_rate==0&&r.public.devices[0].tx_rate==0,'idle zero');
 r=run(r.state,'a',4250,1,2);check(r.state.devices[m].total==1500&&r.public.devices[0].rx_rate==null,'counter reset baseline');
 r=run(r.state,'b',1000,1000000,1000000);check(r.state.devices[m].total==1500&&r.public.devices[0].rx_rate==null,'source restart baseline');
 r=run(r.state,'b',2000,1000100,1000200,'2026-10-29');check(r.state.devices[m].today_rx==100&&r.state.devices[m].today_tx==200&&r.state.devices[m].total==1800,'local midnight resets daily only');
 let peers={};peers[m]={connection:'wifi5',interface:'wlan0',online:true};r=run(r.state,'b',3000,1000100,1000200,'2026-10-29',peers);
 peers[m]={connection:'wifi24',interface:'wlan0',online:true};r=run(r.state,'b',4000,1000100,1000200,'2026-10-29',peers);check(length(r.public.devices)==1&&r.public.devices[0].connection=='wifi24','interface switch without duplicate');
 r=run(r.state,'b',5000,1000100,1000200,'2026-10-29');check(r.public.devices[0].connection=='wifi24'&&!r.public.devices[0].online,'offline keeps classification');
 let stale=calculate(r.state,sample('b',5000,9999999,9999999),{}, {},1793116900,'2026-10-29');check(stale.public.stale&&stale.public.devices[0].rx_rate==null&&stale.state.devices[m].total==1800,'stale source not accumulated');
 let stored=json(sprintf('%J',r.state));r=run(stored,'c',1000,9000000,9000000,'2026-10-29');check(r.state.devices[m].total==1800,'persisted ledger after reboot');
 r=run(r.state,'c',20000,9000100,9000200,'2026-10-30');check(r.state.devices[m].today_rx==0&&r.state.devices[m].today_tx==0&&r.state.devices[m].total==2100&&r.public.devices[0].rx_rate==null,'date-spanning stale gap retained in lifetime without false daily attribution');
 check(r.state.devices[m].month_total==2100,'same month includes prior days and stale same-month deltas');
 r=run(r.state,'c',21000,9000200,9000400,'2026-11-01');check(r.state.devices[m].month_total==300&&r.state.devices[m].total==2400,'month resets independently from lifetime');
 r=run(r.state,'c',21000,9000200,9000400,'2026-11-01');check(r.state.devices[m].month_total==300,'duplicate monthly sample is idempotent');
 r=run(r.state,'c',22000,9000300,9000600,'2026-11-02');check(r.state.devices[m].month_total==600&&r.state.devices[m].today_rx==100&&r.state.devices[m].today_tx==200,'daily rollover preserves month');
 stored=json(sprintf('%J',r.state));r=run(stored,'d',1000,9999999,9999999,'2026-11-02');check(r.state.devices[m].month_total==600&&r.state.devices[m].total==2700,'monthly survives persisted state and source restart');
 let legacy={version:1,devices:{}};legacy.devices[m]={day:'2026-10-27',today_rx:12,today_tx:34,total:9999};
 r=run(legacy,'e',1000,1,1,'2026-10-28');check(r.state.devices[m].month_total==46&&r.state.devices[m].total==9999,'legacy migration retains attributable month bytes without inventing older lifetime attribution');
 r=calculate(r.state,sample('e',1000,1,1),{}, {},1793116900,'2026-11-01');
 r=run(r.state,'e',20000,101,201,'2026-11-01');check(r.state.devices[m].month_total==0&&r.state.devices[m].today_rx==0&&r.state.devices[m].today_tx==0&&r.state.devices[m].total==10299,'stale rollover and long cross-month gap avoid false monthly attribution');
}
print(sprintf('%d assertions passed\n',n));
