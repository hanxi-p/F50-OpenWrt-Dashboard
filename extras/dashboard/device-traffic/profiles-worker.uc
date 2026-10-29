#!/usr/bin/ucode
import * as fs from 'fs';
import * as uci from 'uci';
import {atomic,readjson} from './ledger.uc';
import {validate,seed,moveBinding,detach,derive,macOK,idOK} from './profiles.uc';
const P=getenv('DEVICE_PROFILE_DATA_DIR')??'/etc/f50-devices',R=getenv('DEVICE_PROFILE_RUNTIME_DIR')??'/tmp/f50-devices',C=getenv('DEVICE_PROFILE_UCI_DIR')??'/etc/config',N=getenv('DEVICE_PROFILE_PACKAGE')??'f50_devices';
assert(match(N,/^[a-zA-Z0-9_]+$/));
function uuid(){return trim(fs.readfile('/proc/sys/kernel/random/uuid')??'');}
let tmp='/tmp/device-profile-uci-'+uuid(),cfg=C+'/'+N,temporary=false;
function strict(path,fallback){let s=fs.readfile(path);if(s==null)return fallback;return json(s);}
function load(cursor,pkg){
 let r=null;
 cursor.foreach(pkg,'registry',function(s){assert(!r,'duplicate registry');r={version:1,revision:+s.revision,profiles:{},bindings:{},history:[]};});
 cursor.foreach(pkg,'profile',function(s){r??={version:1,revision:0,profiles:{},bindings:{},history:[]};assert(!r.profiles[s.id],'duplicate profile ID');r.profiles[s.id]={id:s.id,name:s.name??'',anchor:s.anchor??'',created:+s.created};});
 if(!r)return null;
 cursor.foreach(pkg,'binding',function(s){assert(!r.bindings[s.mac],'duplicate MAC binding');r.bindings[s.mac]={id:s.device_id,bound_at:+s.bound_at,origin:s.origin??'confirmed'};});
 cursor.foreach(pkg,'registry',function(s){r.revision=+s.revision;});
 cursor.foreach(pkg,'binding_event',function(s){push(r.history,{mac:s.mac,from:s.from||null,to:s.to,at:+s.at,action:s.action});});
 return validate(r);
}
function run(){
 assert(time()>1577836800,'系统时间尚未同步');let request=ARGV[0]=='sync'?{action:'sync'}:strict(ARGV[0],null);
 assert(request&&index(['sync','rename','bind','detach'],request.action)>=0,'无效档案操作');
 let before=fs.readfile(cfg);fs.mkdir(tmp,0700);fs.mkdir(tmp+'/conf',0700);fs.mkdir(tmp+'/delta',0700);temporary=true;
 let pkg='profiles'+replace(uuid(),/-/g,'');fs.writefile(tmp+'/conf/'+pkg,before??'');
 let cursor=uci.cursor(tmp+'/conf',tmp+'/delta'),r=load(cursor,pkg),cached=readjson(P+'/profiles.json',null),recovered=false;
 if(!r&&before==null&&cached){r=validate(cached);recovered=true;}
 assert(r||before==null||(trim(before)==''&&!cached),'UCI档案无效，已保留原文件与缓存，请恢复配置后重试');
 if(cached&&r)for(let mac in cached.bindings)assert(r.bindings[mac],'UCI档案缺少已有绑定，已保留缓存，请恢复配置后重试');
 let known=strict(R+'/ledger.json',strict(P+'/ledger.json',{devices:{}})).devices;
 let oldAliases=r?{}:strict(P+'/aliases.json',{}),oldLinks=r?{}:strict(P+'/identities.json',{});
 // Legacy aliases/confirmed identity links are imported once. No hostname matching.
 if(!r){for(let mac in oldAliases)if(macOK(mac))known[mac]??={};for(let mac,to in oldLinks){if(macOK(mac))known[mac]??={};if(macOK(to))known[to]??={};}}
 let result=seed(r,known,oldAliases,oldLinks,time(),uuid);r=result.registry;let changed=result.changed||recovered;
 if(request.action!='sync'){
  let mac=lc(request.mac??'');assert(macOK(mac)&&r.bindings[mac],'设备不存在');let id=r.bindings[mac].id;
  if(request.expected_id)assert(request.expected_id==id,'设备归属已变化，请刷新后重试');
  if(request.action=='rename'){let name=trim(request.name??'');assert(type(name)=='string'&&length(name)<=96&&!match(name,/[[:cntrl:]]/),'名称格式无效');r.profiles[id].name=name;r.revision++;}
  else{let blocked=strict(P+'/actions.json',{}).blocked??{};if(request.action=='bind')moveBinding(r,mac,request.device_id,request.expected_id,request.confirmed,time(),blocked);else detach(r,mac,request.expected_id,request.confirmed,time(),blocked,uuid);}
  changed=true;
 }
 let st=fs.stat(cfg),signature=st?sprintf('%s:%s',st.mtime,st.size):'';
 if(!changed&&cached?.revision==r.revision&&cached?.config_signature==signature)return {ok:true,unchanged:true};
 if(changed){
  let empty='output'+replace(uuid(),/-/g,'');fs.writefile(tmp+'/conf/'+empty,'');
  cursor=uci.cursor(tmp+'/conf',tmp+'/delta');
  cursor.set(empty,'registry','registry');cursor.set(empty,'registry','revision',''+r.revision);
  for(let id,p in r.profiles){let sec='d_'+replace(id,/-/g,'');cursor.set(empty,sec,'profile');for(let k in ['id','name','anchor','created'])cursor.set(empty,sec,k,''+p[k]);}
  for(let mac,b in r.bindings){let sec='m_'+replace(mac,/:/g,'');cursor.set(empty,sec,'binding');cursor.set(empty,sec,'mac',mac);cursor.set(empty,sec,'device_id',b.id);cursor.set(empty,sec,'bound_at',''+b.bound_at);cursor.set(empty,sec,'origin',b.origin);}
  let i=0;for(let h in r.history){let sec='h_'+i++;cursor.set(empty,sec,'binding_event');for(let k in ['mac','from','to','at','action'])cursor.set(empty,sec,k,''+(h[k]??''));}
  assert(cursor.save(empty)&&cursor.commit(empty),'保存档案失败');
  let text=fs.readfile(tmp+'/conf/'+empty);assert(text!=null&&fs.readfile(cfg)==before,'档案已被其他操作修改，请重试');
  atomic(cfg,text);
 }
 st=fs.stat(cfg);r.config_signature=sprintf('%s:%s',st.mtime,st.size);
 let d=derive(r);atomic(P+'/identities.json',d.links);atomic(P+'/aliases.json',d.aliases);atomic(P+'/profiles.json',r);
 return {ok:true,revision:r.revision};
}
let output;try{output=run();}catch(e){output={error:''+e};}
if(temporary){for(let dir in ['conf','delta']){for(let path in fs.glob(tmp+'/'+dir+'/*'))fs.unlink(path);fs.rmdir(tmp+'/'+dir);}for(let path in fs.glob(tmp+'/*'))fs.unlink(path);fs.rmdir(tmp);}
print(sprintf('%J',output));
