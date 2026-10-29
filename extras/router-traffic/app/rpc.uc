#!/usr/bin/ucode
import * as fs from 'fs';
import {readjson,atomic,identity} from './ledger.uc';
import {groupWired} from './presentation.uc';
import {sample} from './resources.uc';
const P=getenv('ROUTER_TRAFFIC_CONFIG_DIR')??'/etc/router-traffic',R=getenv('ROUTER_TRAFFIC_RUNTIME_DIR')??'/tmp/router-traffic';
if(ARGV[0]=='list'){print('{"status":{},"devices":{},"resources":{},"rename":{"mac":"String","name":"String"}}');exit(0);}
if(ARGV[0]!='call')exit(1);
if(ARGV[1]=='resources'){let value=sample(R+'/resources.json');delete value.raw_cpu;print(sprintf('%J',value));exit(0);}
if(ARGV[1]=='status'||ARGV[1]=='devices'){
 let value=readjson(R+(ARGV[1]=='status'?'/wan.json':'/devices.json'),{stale:true,devices:[]});
 value.diagnostics=readjson(R+'/source.diag',{});
 if(ARGV[1]=='devices')value.devices=groupWired(value.devices);
 if(!value.timestamp||time()-value.timestamp>4)value.stale=true;
 print(sprintf('%J',value));exit(0);
}
if(ARGV[1]!='rename')exit(1);
let input=fs.stdin.read('all'),v;try{v=json(input);}catch(e){print('{"error":"无效请求"}');exit(0);}
let mac=lc(v.mac??''),name=trim(v.name??'');
if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)||length(name)>96||match(name,/[[:cntrl:]]/)){print('{"error":"名称最多96字节，不能含控制字符"}');exit(0);}
let saved=fs.readfile(P+'/aliases.json'),aliases=saved!=null?json(saved):{};
if(type(aliases)!='object')die('invalid aliases retained');
let links=readjson(P+'/identities.json',{}),root=identity(mac,links),members={};members[root]=true;members[mac]=true;
for(let member in links)if(identity(member,links)==root)members[member]=true;
for(let member in members){if(name=='')delete aliases[member];else aliases[member]=name;}
atomic(P+'/aliases.json',aliases);print('{"ok":true}');
