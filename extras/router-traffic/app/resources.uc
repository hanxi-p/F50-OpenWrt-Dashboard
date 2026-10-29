import * as fs from 'fs';
import {readjson,atomic} from './ledger.uc';
function cpuUsage(before,after){
 if(!before||!after)return null;
 let total=after.total-before.total,idle=after.idle-before.idle;
 return total>0&&idle>=0&&idle<=total?100*(total-idle)/total:null;
}
function sample(path){
 let tick=clock(true),ms=tick[0]*1000+tick[1]/1000000,old=readjson(path,{});
 if(old.ms&&ms>=old.ms&&ms-old.ms<800)return old;
 let cpus={};for(let line in split(fs.readfile('/proc/stat')??'','\n')){
  let a=split(trim(line),/\s+/);if(!match(a[0]??'',/^cpu[0-9]*$/)||length(a)<9)continue;
  let total=0;for(let i=1;i<=8;i++)total+=+a[i];cpus[a[0]]={total:total,idle:+a[4]+(+a[5])};
 }
 let fresh=old.ms&&ms-old.ms>0&&ms-old.ms<=4000,cores=[];
 for(let name,value in cpus)if(name!='cpu')push(cores,{name:name,usage:fresh?cpuUsage(old.raw_cpu?.[name],value):null});
 let mem={};for(let line in split(fs.readfile('/proc/meminfo')??'','\n')){let m=match(line,/^(\w+):\s+(\d+) kB/);if(m)mem[m[1]]=+m[2]*1024;}
 let temps=[];for(let dir in fs.glob('/sys/class/thermal/thermal_zone*')){
  let raw=fs.readfile(dir+'/temp');if(raw==null)continue;let c=(+trim(raw))/1000;
  if(c>=-20&&c<=150)push(temps,{name:trim(fs.readfile(dir+'/type')??'温度'),celsius:c});
 }
 let storage=old.storage??null;
 if(!storage||ms-(old.disk_ms??0)>15000){
  let f=fs.popen('df -k /overlay','r');if(f){let lines=split(trim(f.read('all')??''),'\n');f.close();let a=split(trim(lines[length(lines)-1]??''),/\s+/);if(length(a)>=6&&+a[1]>0)storage={total:+a[1]*1024,used:+a[2]*1024,available:+a[3]*1024,mount:'/overlay'};}
 }
 let value={timestamp:time(),ms:ms,raw_cpu:cpus,cpu:fresh?cpuUsage(old.raw_cpu?.cpu,cpus.cpu):null,cores:cores,memory:{total:mem.MemTotal,available:mem.MemAvailable??((mem.MemFree??0)+(mem.Buffers??0)+(mem.Cached??0))},temperatures:temps,storage:storage,disk_ms:!old.storage||ms-(old.disk_ms??0)>15000?ms:old.disk_ms};
 atomic(path,value);return value;
}
export {cpuUsage,sample};
