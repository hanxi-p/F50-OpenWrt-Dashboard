import {advance} from '../app/wan-ledger.uc';
function check(v,s){assert(v,s);}
for(let round=0;round<3;round++){
 let s={valid:true,boot:'boot-a',device:'uplink',index:'4',ms:1000,timestamp:1793260800,date:'2026-10-29',hour:'2026-10-29-18',rx:1000000000,tx:2000000000};
 let r=advance(null,s,true);check(r.state.daily_rx==0&&r.status.rx_rate==null,'first baseline');
 s={...s,ms:2250,rx:s.rx+1250,tx:s.tx+2500};r=advance(r.state,s,false);check(r.status.rx_rate==1000&&r.status.tx_rate==2000&&r.state.daily_rx==1250,'actual 1.25 second interval');
 let before=r.state.total_rx;r=advance(r.state,s,false);check(r.state.total_rx==before&&r.status.rx_rate==1000,'duplicate sample');
 s={...s,ms:3250};r=advance(r.state,s,false);check(r.status.rx_rate==0&&r.status.tx_rate==0,'idle');
 s={...s,ms:4250,rx:20,tx:30};r=advance(r.state,s,false);check(r.status.rx_rate==null&&r.state.total_rx==before,'reset baseline');
 s={...s,ms:5250,rx:120,tx:230};r=advance(r.state,s,false);check(r.state.total_rx==before+100,'after reset');
 let daily=r.state.daily_rx;s={...s,ms:6250,device:'new-uplink',index:'9',rx:99999999,tx:88888888};r=advance(r.state,s,false);check(r.state.daily_rx==daily&&r.status.rx_rate==null,'interface replacement baseline');
 s={...s,ms:7250,rx:s.rx+100,tx:s.tx+200};r=advance(r.state,s,true);check(r.state.daily_rx==daily+100&&r.status.rx_rate==null,'same-boot collector restart catches bytes without false speed');
 let life=r.state.total_rx;s={...s,ms:8250,date:'2026-10-30',hour:'2026-10-30-00',rx:s.rx+300,tx:s.tx+400};r=advance(r.state,s,false);check(r.state.daily_rx==0&&r.state.hour_rx==0&&r.state.total_rx==life+300,'midnight gap lifetime only');
 s={...s,ms:9250,rx:s.rx+500,tx:s.tx+600};r=advance(r.state,s,false);check(r.state.daily_rx==500&&r.state.hour_rx==500,'new day normal');
 daily=r.state.daily_rx;s={...s,boot:'boot-b',ms:1000,rx:12345,tx:54321};r=advance(r.state,s,true);check(r.state.daily_rx==daily&&r.state.session_rx==0&&r.status.rx_rate==null,'actual reboot baseline');
 let serialized=sprintf('%J',r.state);r=advance(json(serialized),{...s,ms:2250,rx:s.rx+250,tx:s.tx+500},false);check(r.status.rx_rate==200&&r.state.daily_rx==daily+250,'persisted continuation');
 daily=r.state.daily_rx;life=r.state.total_rx;r=advance(r.state,{...s,valid:false,ms:3250,rx:0,tx:0},false);check(r.state.daily_rx==daily&&r.state.total_rx==life&&r.status.stale,'missing counters');
 r=advance(r.state,{...s,timestamp:1,date:'1970-01-01',hour:'1970-01-01-00'},true);check(r.state.daily_rx==daily&&r.state.date=='2026-10-30','invalid boot clock retains history');
}
print('PASS WAN three rounds: baseline, actual interval, duplicate, idle, reset, interface, collector restart, midnight, reboot, persistence and invalid clock\n');
