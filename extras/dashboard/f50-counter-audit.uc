import * as fs from 'fs';
let root=ARGV[0] || '/opt/f50-traffic-hours/counters';
let input=ARGV[1], now=ARGV[2] ? +ARGV[2] : time();
if(root!='/opt/f50-traffic-hours/counters' && !match(root,/^\/tmp\/f50-counter-test-[a-zA-Z0-9-]+$/))die('Invalid audit path');
if(input && !match(input,/^\/tmp\/f50-counter-test-[a-zA-Z0-9-]+\.json$/))die('Invalid fixture');
if(now<1735689600)die('Clock not ready');
function read(p){let v=fs.readfile(p);return v ? trim(v) : null;}
function day(t){let d=localtime(t);return sprintf('%04d-%02d-%02d',d.year,d.mon,d.mday);}
let row=input ? json(fs.readfile(input)) : {
 boot:read('/proc/sys/kernel/random/boot_id'), uptime:read('/proc/uptime'),
 ifindex:read('/sys/class/net/sipa_eth0/ifindex'),
 rx:read('/sys/class/net/sipa_eth0/statistics/rx_bytes'),
 tx:read('/sys/class/net/sipa_eth0/statistics/tx_bytes')
};
if(!match(row?.rx || '',/^\d+$/) || !match(row?.tx || '',/^\d+$/) || !match(row?.uptime || '',/^\d+(\.\d+)? /) || !row.boot || !row.ifindex)die('Counters unavailable');
fs.mkdir(root,0700);if(fs.lstat(root)?.type!='directory')die('Unsafe audit directory');fs.chmod(root,0700);
let today=day(now), path=root+'/'+today+'.jsonl',limit=5000000000;
if(input && ARGV[3]){limit=+ARGV[3];if(limit<1024 || limit>5000000000)die('Invalid fixture limit');}
if(fs.lstat(path)?.type=='link')die('Unsafe audit file');
// The daily guard bounds accidental fast loops; capacity, not age, expires history.
if((fs.stat(path)?.size || 0)>16776000)die('Audit daily cap reached');
let previous=null;try{previous=json(fs.readfile(root+'/last.json'));}catch{}
if(previous && (!match(previous.rx || '',/^\d+$/) || !match(previous.tx || '',/^\d+$/) || !match(previous.uptime || '',/^\d+(\.\d+)? /)))previous=null;
let reason='initial',rx=null,tx=null,seconds=null;
if(previous){
 let dt=+split(row.uptime || '',' ')[0]-+split(previous.uptime || '',' ')[0];
 if(previous.boot!=row.boot || previous.ifindex!=row.ifindex)reason='restart';
 else if(+row.rx<+previous.rx || +row.tx<+previous.tx)reason='counter-reset';
 else if(dt<=0 || dt>600)reason='sampling-gap';
 else {reason='normal';rx=+row.rx-+previous.rx;tx=+row.tx-+previous.tx;seconds=dt;}
}
row={version:2,ts:now,...row,interval_start_ts:previous?.ts,interval_seconds:seconds,received_bytes:rx,sent_bytes:tx,total_bytes:rx==null?null:rx+tx,status:reason};
let line=sprintf('%J\n',row),files=[],size=0;
for(let name in fs.lsdir(root))if(match(name,/^\d{4}-\d{2}-\d{2}\.jsonl$/) && fs.lstat(root+'/'+name)?.type=='file'){push(files,name);size+=fs.stat(root+'/'+name).size;}
for(let name in sort(files)){
 if(size+length(line)<=limit)break;
 if(name==today+'.jsonl')continue;
 let p=root+'/'+name,n=fs.stat(p).size;if(!fs.unlink(p))die('Audit prune failed');size-=n;
}
if(size+length(line)>limit)die('Audit capacity reached');
let f=fs.open(path,'a');if(!f)die('Audit open failed');
let count=f.write(line), closed=f.close();
if(count!=length(line) || !closed)die('Audit write failed');fs.chmod(path,0600);
if(fs.writefile(root+'/last.json.new',sprintf('%J',row))<=0)die('Audit baseline write failed');
fs.chmod(root+'/last.json.new',0600);if(!fs.rename(root+'/last.json.new',root+'/last.json'))die('Audit baseline rename failed');
