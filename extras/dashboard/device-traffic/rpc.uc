#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic,identity} from './ledger.uc';
let args=ARGV;
if(args[0]=='list'){print('{"status":{},"rename":{"mac":"String","name":"String"},"remove":{"mac":"String"},"block":{"mac":"String"},"unblock":{"mac":"String"}}');exit(0);}
if(args[0]!='call')exit(1);
if(args[1]=='status'){
 let value=readjson('/tmp/f50-devices/devices.json',{stale:true,devices:[]}),controls=readjson('/etc/f50-devices/actions.json',{}),links=readjson('/etc/f50-devices/identities.json',{});
 for(let d in value.devices??[])d.blocked=!!controls.blocked?.[identity(d.mac,links)];
 print(sprintf('%J',value));exit(0);
}
if(args[1]=='remove'||args[1]=='block'||args[1]=='unblock'){
 let v;try{v=json(fs.stdin.read('all'));}catch(e){print('{"error":"无效请求"}');exit(0);}
 let mac=lc(v.mac??'');if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)){print('{"error":"无效MAC地址"}');exit(0);}
 let f=fs.popen('/usr/libexec/f50-devices/action '+args[1]+' '+mac,'r'),text=f?.read('all');if(f)f.close();
 try{let result=json(text);if(type(result)!='object')die('invalid');print(sprintf('%J',result));}catch(e){print('{"error":"操作忙或执行失败，请稍后重试"}');}exit(0);
}
if(args[1]!='rename')exit(1);
let input='';for(let line=fs.stdin.read('line');line;line=fs.stdin.read('line'))input+=line;
let v;try{v=json(input);}catch(e){print('{"error":"无效请求"}');exit(0);}
let mac=lc(v.mac??''), name=trim(v.name??'');
if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)||length(name)>96||match(name,/[[:cntrl:]]/)){print('{"error":"名称最多96字节，不能含控制字符"}');exit(0);}
fs.mkdir('/etc/f50-devices',0700);
let saved=fs.readfile('/etc/f50-devices/aliases.json');let aliases=saved!=null?json(saved):{};
if(type(aliases)!='object')die('invalid aliases retained');
let links=readjson('/etc/f50-devices/identities.json',{}),root=identity(mac,links),members={};
members[root]=true;members[mac]=true;
if(type(links)=='object')for(let member,target in links)if(identity(member,links)==root)members[member]=true;
for(let member in members){if(name=='')delete aliases[member];else aliases[member]=name;}
atomic('/etc/f50-devices/aliases.json',aliases);print('{"ok":true}');
