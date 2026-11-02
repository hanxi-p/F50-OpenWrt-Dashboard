import * as fs from 'fs';
import {flatten} from './learning.uc';
import {features,canonical} from './identity.uc';
function snapshot(d,now){
 let rows=[];
 for(let source,item in d.sources??{}){
  let v=item.value??{},value=null;
  if(index(source,'wifi:')==0)value={quality:v.quality,frequency:v.frequency,features:v.features,associated:v.associated,authorized:v.authorized};
  if(source=='dhcp_lease')value={hostname:v.hostname,client_id:v.client_id};
  if(source=='dhcp_event')value={hostname:v.hostname,client_id:v.client_id,vendor_class:v.vendor_class,requested_options:v.requested_options,user_class:v.user_class};
  if(index(source,'mdns:')==0)value={service:v.service,instance:v.instance,host:v.host,model_hint:v.model_hint,manufacturer_hint:v.manufacturer_hint};
  if(value&&length(sprintf('%J',value))<=2048)push(rows,{source:source,fresh:item.expires_at>=now,value:value});
  if(length(rows)>=8)break;
 }
 return sort(rows,function(a,b){return a.source<b.source?-1:a.source>b.source?1:0;});
}
function create(root){
 fs.mkdir(root,0700);
 let current=root+'/samples-current.jsonl',previous=root+'/samples-previous.jsonl';
 let last={},sequence=0,partial=false,cursor=0,budgetWindow=-1,budgetUsed=0;
 let labels=fs.open(root+'/labels.jsonl','a',0600);if(labels)labels.close();
 for(let path in [previous,current]){
  let st=fs.stat(path);if(!st)continue;
  if(st.size>4194304)die('oversize sample log retained; manual recovery required');
  let text=fs.readfile(path)??'';
  if(path==current&&length(text)&&substr(text,-1)!='\n')partial=true;
  for(let line in split(text,'\n')){
   try{let row=json(line);
    if(index(['odi-sample-v1','odi-sample-v2'],row.schema)<0||!row.mac||type(row.features)!='object')continue;
    sequence=max(sequence,row.sequence??0);
    if(row.window>budgetWindow){budgetWindow=row.window;budgetUsed=1;}else if(row.window==budgetWindow)budgetUsed++;
    last[row.mac]={signature:sprintf('%J',canonical({device_id:row.device_id??null,features:row.features,raw_sources:row.raw_sources??[]})),window:row.window,boot:row.boot_id,at:row.observed_at};
   }catch(e){}
  }
 }
 return function(devices,router,boot,now,capabilities){
  let status={version:1,enabled:true,location:root,written:0,empty_fingerprints_seen:0,oversize:0,mode:'unlabelled_observations',timestamp:now};
  if(now<1577836800||!router||!boot){status.error='clock_or_node_identity_unavailable';return status;}
  let names=sort(keys(devices)),rows=[],updates={},window=int(now/300);
  if(window!=budgetWindow){budgetWindow=window;budgetUsed=0;}
  if(budgetUsed>=32){status.budget_exhausted=true;return status;}
  for(let offset=0;offset<length(names);offset++){
   let mac=names[(cursor+offset)%length(names)],d=devices[mac];
   if(d.expires_at<now)continue;
   let f=flatten(d,now);if(!length(f))status.empty_fingerprints_seen++;
   let raw=snapshot(d,now),signature=sprintf('%J',canonical({device_id:d.device_id??null,features:f,raw_sources:raw})),old=last[mac];
   if(old?.boot==boot&&old.window==window&&old.signature==signature)continue;
   let quality={};for(let source,item in d.sources??{}){let group=split(source,':')[0];quality[group]??={fresh:false,qualities:{}};if(item.expires_at>=now&&item.observed_at<=now+30)quality[group].fresh=true;quality[group].qualities[item.value?.quality=='limited'?'limited':item.value?.quality=='reported'?'reported':'metadata']=true;}
   let row={frame_id:trim(fs.readfile('/proc/sys/kernel/random/uuid')),device_id:d.device_id??null,identity_state:d.identity_state??'unresolved',site_id:null,source_quality:quality,capabilities:capabilities??{},raw_sources:raw,schema:'odi-sample-v2',router_id:router,boot_id:boot,sequence:sequence+length(rows)+1,
    mac:mac,window:window,observed_at:now,group_kind:'observation_window_not_independent_device',
    fingerprint_quality:length(f)?'available':'no_usable_fingerprint',reason:old&&now<old.at?'clock_regression':old?.boot!=boot?'first_or_boot_change':old.signature!=signature?'feature_change':'periodic_window',
    association_reported:features(d,now,true).associated,features:f,label:null,label_source:null};
   let line=sprintf('%J',row)+'\n';if(length(line)>16384){status.oversize++;continue;}
   push(rows,line);updates[mac]={signature:signature,window:window,boot:boot,at:now};
   if(length(rows)>=min(8,32-budgetUsed)){cursor=(cursor+offset+1)%length(names);break;}
  }
  if(length(rows)){
   let data=join('',rows),st=fs.stat(current);
   if((st?.size??0)+length(data)+(partial?1:0)>4194304){
    if(!fs.rename(current,previous))die('sample rotation failed; original log retained');
    partial=false;
   }
   let f=fs.open(current,'a',0600);if(!f)die('sample log unavailable');
   if(partial){if(f.write('\n')!=1){f.close();die('cannot terminate partial sample line');}partial=false;}
   let n=f.write(data);f.close();if(n!=length(data)){partial=true;die('short sample write; retained for recovery');}
   sequence+=length(rows);budgetUsed+=length(rows);for(let mac,v in updates)last[mac]=v;
   status.written=length(rows);
  }
  let ordered=sort(keys(last),function(a,b){return last[b].at-last[a].at;});
  for(let i=1024;i<length(ordered);i++)delete last[ordered[i]];
  status.last_sequence=sequence;status.retention='two_logs_up_to_4MiB_each';
  return status;
 };
}
export {create};
