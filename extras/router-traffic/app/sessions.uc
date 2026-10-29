import * as fs from 'fs';
import {atomic,readjson} from './ledger.uc';
function step(s,peers,now,boot,registry,valid){
 s??={version:1,boot:boot,sequence:0,open:{},last_sample:now};
 assert(s.version==1&&type(s.open)=='object','invalid session state retained');
 let events=[],changed=false;
 function close(mac,reason){let v=s.open[mac];push(events,{type:'end',id:v.id,mac:mac,interface:v.interface,start:v.start,end:v.last_seen,reason:reason,device_id:v.device_id});delete s.open[mac];changed=true;}
 if(!valid||now<1577836800)return {state:s,events:events,changed:false};
 if(s.boot!=boot||now<s.last_sample||now-s.last_sample>10){for(let mac in s.open)close(mac,'observation_gap');s.boot=boot;}
 let seen={};
 for(let mac,p in peers){
  if(!p.online||(p.connection!='wifi24'&&p.connection!='wifi5'))continue;
  seen[mac]=true;let old=s.open[mac];
  if(old&&old.interface!=p.interface){close(mac,'interface_change');old=null;}
  if(!old){let id=boot+'-'+(++s.sequence)+'-'+mac+'-'+now;s.open[mac]={id:id,mac:mac,interface:p.interface,ip:p.ip??'',start:now,last_seen:now,misses:0,device_id:registry?.bindings?.[mac]?.id??null};push(events,{type:'start',...s.open[mac]});changed=true;}
  s.open[mac].last_seen=now;s.open[mac].misses=0;
 }
 for(let mac,v in s.open)if(!seen[mac]){v.misses++;if(v.misses>=3)close(mac,'not_seen');}
 s.last_sample=now;return {state:s,events:events,changed:changed};
}
function append(path,events){
 if(!length(events))return;
 let st=fs.stat(path);if(st&&st.size>262144){assert(fs.rename(path,path+'.previous'),'session rotation failed');}
 let f=fs.open(path,'a',0600);assert(f,'session journal unavailable');for(let e in events)f.write(sprintf('%J\n',e));f.flush();f.close();
}
function recent(path,state,macs){
 let sessions={};
 for(let file in [path+'.previous',path])for(let line in split(fs.readfile(file)??'','\n')){
  if(!line)continue;let e;try{e=json(line);}catch(err){continue;}if(!macs[e.mac]||!e.id)continue;
  if(e.type=='start')sessions[e.id]=e;
  else if(e.type=='end')sessions[e.id]={...(sessions[e.id]??e),end:e.end,reason:e.reason,online:false};
 }
 for(let mac,v in state?.open??{})if(macs[mac])sessions[v.id]=time()-(state.last_sample??0)<=4?{...v,online:true}:{...v,online:false,end:v.last_seen,reason:'observation_gap'};
 let rows=[];for(let id,v in sessions)push(rows,v);sort(rows,(a,b)=>b.start-a.start);return slice(rows,0,30);
}
export {step,append,recent};
