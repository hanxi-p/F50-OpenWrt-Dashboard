#!/usr/bin/ucode
import * as fs from 'fs';
import {atomic,readjson} from './ledger.uc';
import {validate,macOK,idOK} from './profiles.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
function strict(path,fallback){let raw=fs.readfile(path);return raw==null?fallback:json(raw);}
let output;
try{
 let v=json(fs.readfile(ARGV[0])),r=validate(strict(P+'/profiles.json',null)),mac=lc(v.mac??'');
 assert(macOK(mac)&&idOK(v.expected_id)&&r.bindings[mac]?.id==v.expected_id,'设备归属已变化，请刷新后重试');
 assert(v.confirmed===true,'请确认删除统计记录');
 let root=r.profiles[v.expected_id].anchor,controls=strict(P+'/actions.json',{}),state=strict(R+'/ledger.json',strict(P+'/ledger.json',{}));
 assert(type(controls)=='object'&&(controls.deleted==null||type(controls.deleted)=='object'),'删除配置损坏，已保留原文件');
 controls.deleted??={};let old=controls.deleted[root],marker=state.removed?.[root];
 if(old&&(!marker||marker.id!=old.id||!marker.restored))output={ok:true,pending:true};
 else{
  assert(time()>1577836800,'系统时间尚未同步');let random=trim(fs.readfile('/proc/sys/kernel/random/uuid')??'');assert(match(random,/^[0-9a-f-]{36}$/));
  controls.deleted[root]={id:sprintf('%d-%d',time(),int(substr(random,0,8),16)),at:time()};atomic(P+'/actions.json',controls);output={ok:true,pending:true};
 }
}catch(e){output={error:''+e};}
print(sprintf('%J',output));
