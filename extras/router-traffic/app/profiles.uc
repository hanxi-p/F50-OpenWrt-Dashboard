import {identity} from './ledger.uc';
function macOK(m){return type(m)=='string'&&!!match(m,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/);}
function idOK(id){return type(id)=='string'&&!!match(id,/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);}
function validate(r){
 assert(r?.version==1&&type(r.profiles)=='object'&&type(r.bindings)=='object'&&type(r.history)=='array'&&r.revision>=0,'invalid device registry retained');
 for(let id,p in r.profiles)assert(idOK(id)&&p.id==id&&type(p.name)=='string'&&length(p.name)<=96&&macOK(p.anchor),'invalid device profile');
 for(let mac,b in r.bindings)assert(macOK(mac)&&r.profiles[b.id]!=null,'invalid profile binding');
 return r;
}
function history(r,mac,from,to,at,action){push(r.history,{mac:mac,from:from,to:to,at:at,action:action});r.history=slice(r.history,-200);}
function repairAnchors(r){
 for(let id,p in r.profiles){let members=[];for(let mac,b in r.bindings)if(b.id==id)push(members,mac);sort(members);if(length(members)&&r.bindings[p.anchor]?.id!=id)p.anchor=members[0];}
}
function seed(r,known,aliases,legacy,now,uuid){
 let first=r==null;r??={version:1,revision:0,profiles:{},bindings:{},history:[]};validate(r);let changed=false;
 let groupIDs={};
 for(let mac in known){
  if(!macOK(mac)||r.bindings[mac])continue;
  let anchor=first?identity(mac,legacy):mac,id=first?groupIDs[anchor]:null;
  if(!id){id=uuid();assert(idOK(id)&&!r.profiles[id],'invalid or duplicate profile ID');r.profiles[id]={id:id,name:aliases[anchor]||aliases[mac]||known[anchor]?.hostname||known[mac]?.hostname||'',anchor:anchor,created:now};groupIDs[anchor]=id;}
  r.bindings[mac]={id:id,bound_at:now,origin:first?'legacy':'observed'};history(r,mac,null,id,now,first?'migrate':'detected');changed=true;
 }
 repairAnchors(r);if(changed)r.revision++;return {registry:r,changed:changed||first};
}
function moveBinding(r,mac,target,expected,confirmed,now,blocked){
 validate(r);assert(macOK(mac)&&r.bindings[mac],'device not found');let source=r.bindings[mac].id;
 assert(idOK(expected)&&source==expected,'设备归属已变化，请刷新后重试');
 assert(confirmed===true,'需要确认该MAC确属所选设备');assert(idOK(target)&&r.profiles[target],'目标档案不存在');
 assert(!blocked?.[r.profiles[source].anchor]&&!blocked?.[r.profiles[target].anchor],'请先解除相关设备的拒绝连接，再修改归属');
 if(source==target)return r;
 history(r,mac,source,target,now,'bind');r.bindings[mac]={id:target,bound_at:now,origin:'confirmed'};repairAnchors(r);r.revision++;return r;
}
function detach(r,mac,expected,confirmed,now,blocked,uuid){
 validate(r);assert(r.bindings[mac]?.id==expected&&confirmed===true,'设备归属已变化或尚未确认');
 let n=0;for(let m,b in r.bindings)if(b.id==expected)n++;assert(n>1,'此地址已是独立档案，无需解绑');
 assert(!blocked?.[r.profiles[expected].anchor],'请先解除拒绝连接，再解绑');
 let id=uuid();assert(idOK(id)&&!r.profiles[id]);r.profiles[id]={id:id,name:'',anchor:mac,created:now};
 moveBinding(r,mac,id,expected,true,now,blocked);r.history[length(r.history)-1].action='detach';return r;
}
function derive(r){
 validate(r);let links={},aliases={};
 for(let mac,b in r.bindings){let p=r.profiles[b.id];if(mac!=p.anchor)links[mac]=p.anchor;if(p.name)aliases[mac]=p.name;}
 return {links:links,aliases:aliases};
}
function annotate(rows,r){
 if(!r)return rows;validate(r);
 for(let d in rows??[]){let b=r.bindings[d.mac];if(b){let p=r.profiles[b.id];d.device_id=b.id;d.name=p.name||d.name;d.binding_count=0;for(let mac,x in r.bindings)if(x.id==b.id)d.binding_count++;}}
 return rows;
}
function listProfiles(r,state){
 if(!r)return [];validate(r);let out=[];
 for(let id,p in r.profiles){let members=[];for(let mac,b in r.bindings)if(b.id==id){let d=state?.devices?.[mac]??{};push(members,{mac:mac,bound_at:b.bound_at,origin:b.origin,online:!!d.online,ip:d.ip??'',last_seen:d.last_seen??null});}
  push(out,{id:id,name:p.name||state?.devices?.[p.anchor]?.hostname||p.anchor,members:members,created:p.created});
 }
 return out;
}
export {macOK,idOK,validate,seed,moveBinding,detach,derive,annotate,listProfiles};
