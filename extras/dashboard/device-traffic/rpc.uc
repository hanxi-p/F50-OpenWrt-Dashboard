#!/usr/bin/ucode
import * as fs from 'fs';
import {recent} from './sessions.uc';
import {annotate,listProfiles} from './profiles.uc';
import {readjson,atomic,identity} from './ledger.uc';
let args=ARGV;
if(args[0]=='list'){print('{"status":{},"rename":{"mac":"String","name":"String","expected_id":"String"},"profiles":{},"sessions":{"mac":"String","expected_id":"String"},"bind":{"mac":"String","device_id":"String","expected_id":"String","confirmed":"Boolean"},"detach":{"mac":"String","expected_id":"String","confirmed":"Boolean"},"remove":{"mac":"String"},"block":{"mac":"String"},"unblock":{"mac":"String"}}');exit(0);}
if(args[0]!='call')exit(1);
if(args[1]=='sessions'){
 let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
 let r=readjson('/etc/f50-devices/profiles.json',null),mac=lc(v.mac??''),id=r?.bindings?.[mac]?.id;
 if(!id||id!=v.expected_id){print('{"error":"设备归属已变化，请刷新后重试"}');exit(0);}
 let macs={};for(let m,b in r.bindings)if(b.id==id)macs[m]=true;
 print(sprintf('%J',{ok:true,sessions:recent('/etc/f50-devices/sessions.jsonl',readjson('/tmp/f50-devices/sessions.json',readjson('/etc/f50-devices/sessions.json',null)),macs)}));exit(0);
}
if(args[1]=='profiles'){
 let r=readjson('/etc/f50-devices/profiles.json',null);print(sprintf('%J',{ok:r!=null,profiles:listProfiles(r,readjson('/etc/f50-devices/ledger.json',{})),history:r?.history??[],revision:r?.revision??null}));exit(0);
}
if(args[1]=='status'){
 let value=readjson('/tmp/f50-devices/devices.json',{stale:true,devices:[]}),controls=readjson('/etc/f50-devices/actions.json',{}),links=readjson('/etc/f50-devices/identities.json',{});
 let registry=readjson('/etc/f50-devices/profiles.json',null);if(registry&&value.profile_revision!=registry.revision)value.stale=true;
 for(let d in value.devices??[])d.blocked=!!controls.blocked?.[identity(d.mac,links)];
 print(sprintf('%J',value));exit(0);
}
if(args[1]=='remove'||args[1]=='block'||args[1]=='unblock'){
 let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
 let mac=lc(v.mac??'');if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)){print('{"error":"无效MAC地址"}');exit(0);}
 let f=fs.popen('/usr/libexec/f50-devices/action '+args[1]+' '+mac,'r'),text=f?.read('all');if(f)f.close();
 try{let result=json(text);if(type(result)!='object')die('invalid');print(sprintf('%J',result));}catch(e){print('{"error":"操作忙或执行失败，请稍后重试"}');}exit(0);
}
if(index(['rename','bind','detach'],args[1])<0)exit(1);
let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
let mac=lc(v.mac??'');if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)){print('{"error":"无效MAC地址"}');exit(0);}
v.mac=mac;v.action=args[1];let uuid=trim(fs.readfile('/proc/sys/kernel/random/uuid')??'');
if(!match(uuid,/^[0-9a-f-]{36}$/))die('UUID unavailable');
let path='/tmp/f50-profile-request-'+uuid+'.json';atomic(path,v);
let f=fs.popen('/usr/libexec/f50-devices/profile-action '+path,'r'),text=f?.read('all');if(f)f.close();fs.unlink(path);
try{let result=json(text);if(type(result)!='object')die('invalid');print(sprintf('%J',result));}catch(e){print('{"error":"操作忙或保存失败，请稍后重试"}');}
