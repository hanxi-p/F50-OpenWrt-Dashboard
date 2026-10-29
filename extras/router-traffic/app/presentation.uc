// Presentation only: keep the authoritative ledger and identity mapping per MAC.
function groupWired(rows){
 let out=[],seen={},wired=null,missing=false;
 for(let row in rows??[]){
  if(seen[row.mac])continue;seen[row.mac]=true;
  if(row.connection!='wired'){push(out,row);continue;}
  wired??={mac:'wired',name:'有线连接',ip:'',hostname:'',connection:'wired',interface:'LAN',online:false,aggregate:true,members:[],rx_rate:0,tx_rate:0,today_rx:0,today_tx:0,month_total:0,total:0};
  push(wired.members,{mac:row.mac,name:row.name,interface:row.interface});
  for(let k in ['today_rx','today_tx','month_total','total'])wired[k]+=row[k]??0;
  if(row.online){wired.online=true;if(row.rx_rate==null||row.tx_rate==null)missing=true;else{wired.rx_rate+=row.rx_rate;wired.tx_rate+=row.tx_rate;}}
 }
 if(wired){if(!wired.online||missing){wired.rx_rate=null;wired.tx_rate=null;}push(out,wired);}
 return out;
}
export {groupWired};
