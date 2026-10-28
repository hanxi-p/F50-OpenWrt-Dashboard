#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic} from './ledger.uc';
let args=ARGV;
if(args[0]=='list'){print('{"status":{},"rename":{"mac":"String","name":"String"}}');exit(0);}
if(args[0]!='call')exit(1);
if(args[1]=='status'){print(sprintf('%J',readjson('/tmp/f50-devices/devices.json',{stale:true,devices:[]})));exit(0);}
if(args[1]!='rename')exit(1);
let input='';for(let line=fs.stdin.read('line');line;line=fs.stdin.read('line'))input+=line;
let v;try{v=json(input);}catch(e){print('{"error":"无效请求"}');exit(0);}
let mac=lc(v.mac??''), name=trim(v.name??'');
if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)||length(name)>96||match(name,/[[:cntrl:]]/)){print('{"error":"名称最多96字节，不能含控制字符"}');exit(0);}
fs.mkdir('/etc/f50-devices',0700);
let saved=fs.readfile('/etc/f50-devices/aliases.json');let aliases=saved!=null?json(saved):{};
if(type(aliases)!='object')die('invalid aliases retained');if(name=='')delete aliases[mac];else aliases[mac]=name;
atomic('/etc/f50-devices/aliases.json',aliases);print('{"ok":true}');
