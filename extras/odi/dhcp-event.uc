#!/usr/bin/ucode
import * as fs from 'fs';
import {macOK,clientID} from './normalize.uc';
let mac=lc(getenv('MACADDR')??''),action=getenv('ACTION');
if(!macOK(mac)||index(['add','update','remove'],action)<0)exit(0);
const R=getenv('ODI_EVENT_DIR')??'/tmp/odi/dhcp';
fs.mkdir('/tmp/odi',0700);fs.mkdir(R,0700);
if(!fs.stat(R+'/'+mac+'.json')&&length(fs.glob(R+'/*.json')??[])>=1024)exit(0);
function field(name){let value=getenv(name);return value?substr(value,0,1024):null;}
let event={version:1,mac:mac,action:action,observed_at:time(),ip:field('IPADDR'),hostname:field('HOSTNAME'),
 vendor_class:field('DNSMASQ_VENDOR_CLASS'),requested_options:field('DNSMASQ_REQUESTED_OPTIONS'),
 user_class:field('DNSMASQ_USER_CLASS0'),client_id:clientID(field('DNSMASQ_CLIENT_ID'),mac)};
let lock=R+'/'+mac+'.lock';if(!fs.mkdir(lock,0700)){let st=fs.stat(lock);if(st&&time()-st.mtime>60)fs.rmdir(lock);exit(0);}
try{
 let path=R+'/'+mac+'.json',f=fs.open(path+'.new','w',0600);
 if(f){let text=sprintf('%J',event);let n=f.write(text);f.close();if(n==length(text))fs.rename(path+'.new',path);}
}catch(e){}
fs.rmdir(lock);
