#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic,identity} from './ledger.uc';
import {recent} from './sessions.uc';
import {listProfiles} from './profiles.uc';
import {groupWired} from './presentation.uc';
import {sample} from './resources.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
if(ARGV[0]=='list'){print('{"status":{},"devices":{},"resources":{},"profiles":{},"remove":{"mac":"String","expected_id":"String","confirmed":"Boolean"},"sessions":{"mac":"String","expected_id":"String"},"rename":{"mac":"String","name":"String","expected_id":"String"},"bind":{"mac":"String","device_id":"String","expected_id":"String","confirmed":"Boolean"},"detach":{"mac":"String","expected_id":"String","confirmed":"Boolean"}}');exit(0);}
if(ARGV[0]!='call')exit(1);
if(ARGV[1]=='resources'){let value=sample(R+'/resources.json');delete value.raw_cpu;print(sprintf('%J',value));exit(0);}
if(ARGV[1]=='status'||ARGV[1]=='devices'){
 let value=readjson(R+(ARGV[1]=='status'?'/wan.json':'/devices.json'),{stale:true,devices:[]});
 value.diagnostics=readjson(R+'/source.diag',{});
 if(ARGV[1]=='devices'){let registry=readjson(P+'/profiles.json',null);if(registry&&value.profile_revision!=registry.revision)value.stale=true;value.devices=groupWired(value.devices);}
 if(!value.timestamp||time()-value.timestamp>4)value.stale=true;
 print(sprintf('%J',value));exit(0);
}
if(ARGV[1]=='sessions'){
 let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
 let r=readjson(P+'/profiles.json',null),mac=lc(v.mac??''),id=r?.bindings?.[mac]?.id;
 if(!id||id!=v.expected_id){print('{"error":"设备归属已变化，请刷新后重试"}');exit(0);}
 let macs={};for(let m,b in r.bindings)if(b.id==id)macs[m]=true;
 print(sprintf('%J',{ok:true,sessions:recent(P+'/sessions.jsonl',readjson(R+'/sessions.json',readjson(P+'/sessions.json',null)),macs)}));exit(0);
}
if(ARGV[1]=='profiles'){
 let r=readjson(P+'/profiles.json',null);print(sprintf('%J',{ok:r!=null,profiles:listProfiles(r,readjson(R+'/ledger.json',readjson(P+'/ledger.json',{}))),history:r?.history??[],revision:r?.revision??null}));exit(0);
}
if(index(['rename','bind','detach','remove'],ARGV[1])<0)exit(1);
let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
let mac=lc(v.mac??'');if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)){print('{"error":"无效MAC地址"}');exit(0);}
v.mac=mac;v.action=ARGV[1];let uuid=trim(fs.readfile('/proc/sys/kernel/random/uuid')??'');
if(!match(uuid,/^[0-9a-f-]{36}$/))die('UUID unavailable');
let path='/tmp/router-traffic-profile-request-'+uuid+'.json';atomic(path,v);
let f=fs.popen('/usr/libexec/router-traffic/'+(ARGV[1]=='remove'?'remove-action':'profile-action')+' '+path,'r'),text=f?.read('all');if(f)f.close();fs.unlink(path);
try{let result=json(text);if(type(result)!='object')die('invalid');print(sprintf('%J',result));}catch(e){print('{"error":"操作忙或保存失败，请稍后重试"}');}
