import {groupWired} from '../app/presentation.uc';
for(let round=0;round<3;round++){
 let a={mac:'02:00:00:00:00:01',name:'one',connection:'wired',online:true,rx_rate:100,tx_rate:20,today_rx:1000,today_tx:200,month_total:3000,total:4000};
 let b={mac:'02:00:00:00:00:02',name:'two',connection:'wired',online:false,rx_rate:null,tx_rate:null,today_rx:2000,today_tx:300,month_total:4000,total:5000};
 let wifi={mac:'02:00:00:00:00:03',connection:'wifi5',online:true};
 let rows=groupWired([a,b,wifi,a]),w=rows[1];
 assert(length(rows)==2&&rows[0]==wifi&&w.name=='有线连接');
 assert(w.today_rx==3000&&w.today_tx==500&&w.month_total==7000&&w.total==9000);
 assert(w.rx_rate==100&&w.tx_rate==20&&length(w.members)==2);
 a.connection='wifi5';rows=groupWired([a,b,wifi]);assert(length(rows)==3&&length(rows[2].members)==1&&rows[2].total==5000);
 a.connection='wired';a.online=false;w=groupWired([a,b])[0];assert(!w.online&&w.rx_rate==null);
 a.online=true;a.rx_rate=null;w=groupWired([a,b])[0];assert(w.online&&w.rx_rate==null);
 assert(a.mac=='02:00:00:00:00:01'&&a.total==4000); // Never replaces stored per-MAC history.
}
print('PASS three rounds: one wired aggregate, Wi-Fi individual rows, directions, history, MAC dedup, interface movement, offline/unknown rate, immutable ledger\n');
