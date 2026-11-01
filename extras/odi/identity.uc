function canonical(v){
 if(type(v)=='object'){let r={};for(let k in sort(keys(v)))r[k]=canonical(v[k]);return r;}
 if(type(v)=='array'){let r=[];for(let item in v)push(r,canonical(item));return r;}
 return v;
}
function features(d,now,fresh){
 let r={radios:{},hostname:null,client_id:null,associated:false};
 for(let source,item in d?.sources??{}){
  if(now-item.observed_at>604800||item.observed_at>now+30)continue;
  if(fresh&&item.expires_at<now)continue;
  let v=item.value;
  if(source=='dhcp_lease'){
   let n=lc(v.hostname??'');
   if(length(n)>3&&!match(n,/^(unknown|localhost|android|iphone|ipad|phone|computer|desktop|laptop)$/))r.hostname=n;
   if(v.client_id?.independent!==false)r.client_id=v.client_id?.value;
  }
  if(source=='dhcp_event'){
   if(v.client_id?.independent!==false&&v.client_id?.value)r.client_id=v.client_id.value;
   if(v.vendor_class&&v.requested_options)r.dhcp_options=sprintf('%J',[v.vendor_class,v.requested_options]);
  }
  if(index(source,'wifi:')==0){
   if(item.expires_at>=now&&v.associated&&v.authorized)r.associated=true;
   if(v.quality=='reported'){
    let band=v.frequency>=5925?'6':v.frequency>=3000?'5':'2';
    r.radios[band]=sprintf('%J',canonical(v.features));
   }
  }
 }
 return r;
}
function suggest(devices,registry,now){
 let output={version:1,policy:'shadow-v1',timestamp:now,expires_at:now+90,mode:'shadow_only',results:[],truncated:false};
 if(!registry||registry.version!=1||type(registry.bindings)!='object'||type(registry.profiles)!='object'){
  output.error='registry_unavailable';return output;
 }
 let candidates=[],targets=[],activeProfiles={};
 for(let mac,d in devices){
  let id=registry.bindings[mac]?.id;
  if(id&&registry.profiles[id]){let fp=features(d,now,false);push(targets,{mac:mac,id:id,fp:fp});if(fp.associated)activeProfiles[id]=true;}
  else if(d.expires_at>=now)push(candidates,{mac:mac,fp:features(d,now,true)});
 }
 if(length(targets)>512||length(candidates)>128)output.truncated=true;
 targets=slice(targets,0,512);candidates=slice(candidates,0,128);
 for(let source in candidates){
  let matches={};
  for(let target in targets){
   let evidence=[],conflicts=[];
   if(source.fp.hostname&&source.fp.hostname==target.fp.hostname)push(evidence,'hostname_weak');
   if(source.fp.client_id&&source.fp.client_id==target.fp.client_id)push(evidence,'client_id_unverified');
   if(source.fp.dhcp_options&&source.fp.dhcp_options==target.fp.dhcp_options)push(evidence,'dhcp_options_shared_type');
   for(let band,value in source.fp.radios)if(target.fp.radios[band]==value){push(evidence,'radio_same_band');break;}
   if(!length(evidence))continue;
   if(source.fp.associated&&activeProfiles[target.id])push(conflicts,'simultaneous_associations_require_review');
   let old=matches[target.id];
   // A conflict on any observed member of a profile must survive candidate reduction.
   if(!old)matches[target.id]={device_id:target.id,evidence:evidence,conflicts:conflicts};
   else{
    for(let e in evidence)if(index(old.evidence,e)<0)push(old.evidence,e);
    for(let c in conflicts)if(index(old.conflicts,c)<0)push(old.conflicts,c);
   }
  }
  let rows=values(matches),ambiguous=length(rows)>1,conflict=false;
  for(let row in rows){if(ambiguous)push(row.conflicts,'multiple_matching_profiles');if(length(row.conflicts))conflict=true;}
  push(output.results,{mac:source.mac,state:conflict?'conflict':length(rows)?'candidate':'unknown',candidates:slice(rows,0,8),automatic_link:false});
 }
 return output;
}
export {canonical,features,suggest};
