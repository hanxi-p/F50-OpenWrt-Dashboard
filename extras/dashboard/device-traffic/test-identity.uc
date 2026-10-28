import {calculate,identity} from './ledger.uc';
let old='02:11:22:33:44:55',fresh='02:11:22:33:44:66',other='02:11:22:33:44:77';
let links={};links[fresh]=old;let names={};names[old]='Confirmed phone';
function check(v,m){if(!v)die('FAIL '+m);}
function src(ms,a,b){return sprintf('sample test %d %d 0\n%s 0 %d 0 2000 0\n%s 0 %d 0 2000000 0\n%s 0 5 0 5 0\n',ms,1793116800+ms/1000,old,a,fresh,b,other);}
function row(r){for(let d in r.public.devices)if(d.identity_mac==old)return d;die('identity row missing');}
for(let round=0;round<3;round++){
 let peers={};peers[fresh]={online:true,connection:'wifi5',interface:'wlan0',ip:'192.0.2.2'};
 let r=calculate(null,src(1000,1000,1000000),peers,names,1793116801,'2026-10-28',links);
 r.state.devices[old].total=10000;r.state.devices[old].today_rx=500;r.state.devices[old].today_tx=200;r.state.devices[old].month_total=2000;
 r.state.devices[fresh].total=100;r.state.devices[fresh].today_rx=80;r.state.devices[fresh].today_tx=20;r.state.devices[fresh].month_total=100;
 r=calculate(r.state,src(2000,1000,1000200),peers,names,1793116802,'2026-10-28',links);
 let d=row(r);check(length(r.public.devices)==2 && length(keys(r.state.devices))==3,'one display row with all raw identities retained');
 check(d.mac==fresh && d.name=='Confirmed phone' && d.ip=='192.0.2.2','current address and canonical custom name');
 check(d.total==10300 && d.today_rx==780 && d.today_tx==220 && d.month_total==2300,'sum historical and new bytes exactly once');
 check(d.rx_rate==200 && d.tx_rate==0,'rate from current online sample only');
 check(r.state.devices[old].raw_rx==1000 && r.state.devices[fresh].raw_rx==1000200,'different raw baselines never merged');
 let total=d.total;r=calculate(r.state,src(2000,1000,1000200),peers,names,1793116802,'2026-10-28',links);check(row(r).total==total,'duplicate source does not sum again');
 r=calculate(r.state,src(3000,1000,1000200),{},names,1793116803,'2026-10-28',links);check(!row(r).online && row(r).mac==fresh && row(r).rx_rate==null,'offline retains last actual address and no current rate');
 peers={};peers[old]={online:true,connection:'wifi24',interface:'wlan0'};
 r=calculate(r.state,src(4000,1050,1000200),peers,names,1793116804,'2026-10-28',links);check(row(r).mac==old && row(r).rx_rate==50 && row(r).total==total+50,'old address reconnect uses its own baseline');
 peers[fresh]={online:true,connection:'wifi5',interface:'wlan0'};
 r=calculate(r.state,src(5000,1150,1000400),peers,names,1793116805,'2026-10-28',links);check(row(r).mac==fresh && row(r).rx_rate==300,'overlap remains one row and adds actual current increments');
 total=row(r).total;
 r=calculate(json(sprintf('%J',r.state)),src(6000,1150,1000400),peers,names,1793116806,'2026-10-29',links);check(row(r).total==total && row(r).today_rx==0 && row(r).today_tx==0,'persisted restart and cross-day retain total');
 r=calculate(r.state,src(7000,1150,1000400),peers,names,1793116807,'2026-11-01',links);check(row(r).month_total==0 && row(r).total==total,'cross-month reset for both raw members');
 let cycle={};cycle[old]=fresh;cycle[fresh]=old;check(identity(old,cycle)==old && identity(fresh,cycle)==fresh,'cycles fail closed');
 check(identity(fresh,{})==fresh && identity(fresh,[])==fresh,'unconfirmed addresses remain independent');
 print('PASS identity round: history/current/rates/dedup/offline/reconnect/overlap/restart/day/month/cycles\n');
}
