import * as fs from 'fs';
let root=ARGV[0] || '/opt/f50-speed-peaks', live=ARGV[1] || '/tmp/f50-speed-peaks';
if(root!='/opt/f50-speed-peaks' && !match(root,/^\/tmp\/f50-peaks-test-[a-zA-Z0-9-]+$/))die('Invalid persistent path');
if(live!='/tmp/f50-speed-peaks' && !match(live,/^\/tmp\/f50-peaks-live-test-[a-zA-Z0-9-]+$/))die('Invalid cache path');
let now=ARGV[2] ? +ARGV[2] : time(), source=ARGV[3] || '/tmp/f50-dashboard-live/history.json';
if(now<1735689600)die('Clock not ready');
function datekey(ts){let d=localtime(ts);return sprintf('%04d-%02d-%02d',d.year,d.mon,d.mday);}
function read(path){let s=fs.readfile(path);if(!s)return null;try{return json(s);}catch{return null;}}
function valid(s){return s?.version==1 && type(s.days)=='object' && length(keys(s.days))<=101;}
function atomic(path,data){let text=sprintf('%J',data),tmp=path+'.new';if(fs.writefile(tmp,text)!=length(text))die('Peak write failed');fs.chmod(tmp,0600);if(!fs.rename(tmp,path))die('Peak rename failed');}
for(let dir in [root,live]){fs.mkdir(dir,0700);if(fs.lstat(dir)?.type!='directory')die('Unsafe peak directory');fs.chmod(dir,0700);}
let state=read(live+'/state.json');
if(!valid(state)){state=read(root+'/history.json');if(!valid(state)){if(fs.stat(root+'/history.json'))die('Invalid saved peaks; retained for recovery');state={version:1,started:now,days:{},saved:0};}}
let oldDays=sprintf('%J',state.days),cutoff=datekey(now-99*86400), today=datekey(now), days={};
for(let day,row in state.days){if(match(day,/^\d{4}-\d{2}-\d{2}$/) && day>=cutoff && day<=today && type(row)=='object' && match(type(row.download),/^(int|double)$/) && match(type(row.upload),/^(int|double)$/) && row.download>=0 && row.upload>=0 && row.download<=1250000000 && row.upload<=1250000000)days[day]=row;}
let samples=read(source);if(type(samples)!='array')die('Rate cache unavailable');
if(length(samples)>320)die('Oversized rate cache');
for(let p in samples){
 if(type(p)!='array' || length(p)<3 || !match(type(p[0]),/^(int|double)$/) || p[0]>now+5 || p[0]<now-400)continue;
 if(!match(type(p[1]),/^(int|double)$/) || !match(type(p[2]),/^(int|double)$/) || p[1]<0 || p[2]<0 || p[1]>1250000000 || p[2]>1250000000)continue;
 let day=datekey(p[0]);if(day>today || day<cutoff)continue;
 let row=days[day] || {download:0,upload:0,download_at:p[0],upload_at:p[0]};
 if(p[1]>row.download){row.download=p[1];row.download_at=p[0];}
 if(p[2]>row.upload){row.upload=p[2];row.upload_at=p[0];}
 days[day]=row;
}
state.days=days;state.updated=now;
state.dirty=state.dirty || oldDays!=sprintf('%J',days);
if(!state.saved || state.dirty){let saved=state.saved;state.saved=now;state.dirty=false;try{atomic(root+'/history.json',state);}catch(e){state.saved=saved;state.dirty=true;atomic(live+'/state.json',state);die(e);}}
atomic(live+'/state.json',state);
let series=[];for(let day in sort(keys(days))){if(day>=datekey(now-29*86400))push(series,{date:day,...days[day]});}
atomic(live+'/public.json',{version:1,today,updated:now,started:state.started,days:series});
