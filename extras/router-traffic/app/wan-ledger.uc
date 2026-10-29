// WAN accounting is independent of sampling rate and of calendar attribution.
// Never add an interface's historical counter at first observation/reset.
function advance(state,sample,first){
 state??={version:1};
 for(let key in ['month_rx','month_tx','daily_rx','daily_tx','hour_rx','hour_tx','peak_rx','peak_tx','session_rx','session_tx','total_rx','total_tx'])state[key]??=0;
 // Upgrade once: retain independently known totals without adding overlapping history.
 if(state.history_version!=2){
  state.total_rx=max(state.total_rx,state.session_rx,state.daily_rx);state.total_tx=max(state.total_tx,state.session_tx,state.daily_tx);
  state.month=substr(state.date??'',0,7);state.month_rx=max(state.month_rx,state.daily_rx);state.month_tx=max(state.month_tx,state.daily_tx);
  state.history_partial=state.daily_rx>0||state.daily_tx>0||state.session_rx>0||state.session_tx>0;state.history_version=2;
 }
 let old=state.last,down=null,up=null,valid=sample.valid!==false&&sample.timestamp>=1577836800;
 if(valid){
  let generation=old&&old.boot==sample.boot&&old.device==sample.device&&old.index==sample.index;
  let delta=old?sample.ms-old.ms:0;
  if(old&&old.boot!=sample.boot){state.session_rx=0;state.session_tx=0;}
  let month=substr(sample.date,0,7);
  if(state.month!=month){state.month=month;state.month_rx=0;state.month_tx=0;}
  if(state.date!=sample.date){state.date=sample.date;state.daily_rx=0;state.daily_tx=0;state.peak_rx=0;state.peak_tx=0;}
  if(state.hour!=sample.hour){state.hour=sample.hour;state.hour_rx=0;state.hour_tx=0;}
  if(generation&&delta>0&&sample.rx>=old.rx&&sample.tx>=old.tx){
   let rx=sample.rx-old.rx,tx=sample.tx-old.tx;
   state.session_rx+=rx;state.session_tx+=tx;state.total_rx+=rx;state.total_tx+=tx;
   // An unsampled midnight/hour boundary cannot be split reliably.
   if(substr(old.date,0,7)==month){state.month_rx+=rx;state.month_tx+=tx;}
   if(old.date==sample.date){state.daily_rx+=rx;state.daily_tx+=tx;}
   if(old.hour==sample.hour){state.hour_rx+=rx;state.hour_tx+=tx;}
   if(!first&&delta<=4000){down=rx*1000/delta;up=tx*1000/delta;}
  }else if(generation&&delta==0){down=state.last_rx_rate;up=state.last_tx_rate;}
  if(!old||!generation||delta>0)state.last=sample;
  if(down!=null){state.peak_rx=max(state.peak_rx,down);state.peak_tx=max(state.peak_tx,up);}
  state.last_rx_rate=down;state.last_tx_rate=up;
 }
 return {state:state,status:{engine:'router-traffic-wan-v2',timestamp:sample.timestamp,device:sample.device,stale:!valid,rx_rate:down,tx_rate:up,rx_total:state.session_rx,tx_total:state.session_tx,hour_rx:state.hour_rx,hour_tx:state.hour_tx,daily_rx:state.daily_rx,daily_tx:state.daily_tx,peak_rx:state.peak_rx,peak_tx:state.peak_tx,month_rx:state.month_rx,month_tx:state.month_tx,total_rx:state.total_rx,total_tx:state.total_tx,history_partial:state.history_partial,date:state.date??'',hour:state.hour??''}};
}
export {advance};
