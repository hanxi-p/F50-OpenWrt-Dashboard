import {features,canonical} from './identity.uc';
function flatten(d,now){
 let f=features(d,now,true),r={};
 for(let key in ['hostname','client_id','dhcp_options'])if(f[key])r[key]=f[key];
 for(let band,value in f.radios)r['radio:'+band]=value;
 let instances=[],types=[],models=[];
 for(let source,item in d?.sources??{}){
  if(index(source,'mdns:')!=0||item.expires_at<now||item.observed_at>now+30)continue;
  let v=item.value;if(v.instance)push(instances,v.instance);
  if(v.service)push(types,v.service);
  if(v.model_hint)push(models,[v.model_hint,v.manufacturer_hint??null]);
 }
 if(length(instances))r.mdns_names=sprintf('%J',sort(instances));
 if(length(types))r.mdns_types=sprintf('%J',sort(types));
 if(length(models))r.mdns_models=sprintf('%J',sort(models,function(a,b){return sprintf('%J',a)<sprintf('%J',b)?-1:1;}));
 for(let key,value in r)if(length(value)>4096)delete r[key];
 return r;
}
function update(history,devices,now){
 history??={version:1,devices:{}};
 assert(history.version==1&&type(history.devices)=='object','invalid feature history retained');
 for(let mac,d in devices){
  if(d.expires_at<now)continue;
  let fields=flatten(d,now);if(!length(fields))continue;
  let row=history.devices[mac]??={fields:{},last_seen:now};row.last_seen=now;
  for(let key,value in fields){
   let field=row.fields[key]??={variants:[],last_window:-1};
   // Repeated polling in the same five-minute window is not an independent sample.
   let window=int(now/300);
   field.last_window=window;let found=false;
   for(let variant in field.variants)if(variant.value==value){if(window>(variant.last_window??-1)){variant.windows=min(65535,variant.windows+1);variant.last_window=window;}variant.last_seen=now;found=true;break;}
   if(!found)push(field.variants,{value:value,windows:1,first_seen:now,last_seen:now,last_window:window});
   field.variants=filter(field.variants,function(v){return now-v.last_seen<=604800;});
   sort(field.variants,function(a,b){return b.last_seen-a.last_seen;});field.variants=slice(field.variants,0,4);
  }
 }
 for(let mac,row in history.devices)if(now-row.last_seen>604800)delete history.devices[mac];
 let ordered=sort(keys(history.devices),function(a,b){return history.devices[b].last_seen-history.devices[a].last_seen;});
 let budget=0;
 for(let i=0;i<length(ordered);i++){let size=length(sprintf('%J',history.devices[ordered[i]]));if(i>=1024||budget+size>2097152)delete history.devices[ordered[i]];else budget+=size;}
 return history;
}
function family(field){
 if(field=='hostname'||field=='mdns_names')return 'names';
 if(field=='client_id'||field=='dhcp_options')return 'dhcp';
 if(index(field,'radio:')==0)return 'radio';
 return 'service_types';
}
function infer(history,devices,registry,now,base){
 if(base.error)return base;
 base.policy='history-shadow-v2';base.learning={window_seconds:300,retention_days:7,meaning:'window_repeatability_not_identity_accuracy'};
 let targets={},active={};
 for(let mac,b in registry.bindings){
  if(!registry.profiles[b.id])continue;
  if(features(devices[mac],now,true).associated)active[b.id]=true;
  let row=history.devices[mac];if(!row)continue;
  for(let key,field in row.fields)for(let v in field.variants){
   if(now-v.last_seen>604800)continue;
   targets[key]??={};targets[key][v.value]??={};
   let old=targets[key][v.value][b.id];
   if(!old||old.windows<v.windows)targets[key][v.value][b.id]={...v,variant_count:length(field.variants)};
  }
 }
 for(let result in base.results){
  let current=flatten(devices[result.mac],now),matches={};
  for(let row in result.candidates)matches[row.device_id]={...row,learned_evidence:[],families:{},rare_groups:{},repeatable_groups:{},rare_matches:0};
  for(let key,value in current){
   let owners=targets[key]?.[value]??{},shared=length(owners);
   for(let id,v in owners){
    matches[id]??={device_id:id,evidence:[],conflicts:[],learned_evidence:[],families:{},rare_groups:{},repeatable_groups:{},rare_matches:0};
    let row=matches[id];row.families[family(key)]=true;
    push(row.learned_evidence,{field:key,matching_profiles:shared,observed_windows:v.windows,window_span_seconds:v.last_seen-v.first_seen,variant_count:v.variant_count,repeatability:v.windows>=3&&v.variant_count==1?'repeated_in_sampled_windows':'variable_or_insufficient',quality:shared>1?'shared_in_this_registry':'unique_in_observed_registry'});
    if(shared==1)row.rare_groups[family(key)]=true;
    if(v.windows>=3&&v.variant_count==1)row.repeatable_groups[family(key)]=true;
   }
  }
  let rows=values(matches),associated=features(devices[result.mac],now,true).associated;
  for(let row in rows){
   if(associated&&active[row.device_id]&&index(row.conflicts,'simultaneous_associations_require_review')<0)push(row.conflicts,'simultaneous_associations_require_review');
   if(length(rows)>1&&index(row.conflicts,'multiple_matching_profiles')<0)push(row.conflicts,'multiple_matching_profiles');
   row.independent_source_groups=length(row.families);row.rare_matches=length(row.rare_groups);row.repeatable_source_groups=length(row.repeatable_groups);delete row.families;delete row.rare_groups;delete row.repeatable_groups;
  }
  sort(rows,function(a,b){return b.independent_source_groups-a.independent_source_groups||b.rare_matches-a.rare_matches||b.repeatable_source_groups-a.repeatable_source_groups;});
  result.candidates=slice(rows,0,8);result.state=length(rows)?'candidate':'unknown';
  for(let row in rows)if(length(row.conflicts))result.state='conflict';
  result.automatic_link=false;
 }
 return base;
}
export {flatten,update,infer};
