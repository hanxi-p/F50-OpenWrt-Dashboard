import * as fs from 'fs';
import {create} from './sampler.uc';
let base=getenv('ODI_TEST_DIR');if(!base)die('set an isolated ODI_TEST_DIR');fs.mkdir(base,0700);
let assertions=0;
function check(v){if(!v)die('sampler fixture failed');assertions++;}
function device(name,at){return {expires_at:at+90,sources:{dhcp_lease:{observed_at:at,expires_at:at+90,value:{hostname:name}}}};}
for(let round=0;round<3;round++){
 let root=base+'/round-'+round;fs.mkdir(root,0700);
 let t=1700000000,devices={'02:00:00:00:00:01':device('fixture-name',t)},sample=create(root);
 check(sample(devices,'router-fixture','boot-a',t).written==1);
 check(sample(devices,'router-fixture','boot-a',t+1).written==0);
 sample=create(root);check(sample(devices,'router-fixture','boot-a',t+1).written==0);
 devices['02:00:00:00:00:01']=device('changed-name',t+2);
 check(sample(devices,'router-fixture','boot-a',t+2).written==1);
 check(sample(devices,'router-fixture','boot-b',t+3).written==1);
 devices['02:00:00:00:00:01']=device('changed-name',t+301);
 check(sample(devices,'router-fixture','boot-b',t+301).written==1);
 let lines=split(trim(fs.readfile(root+'/samples-current.jsonl')),'\n');
 check(length(lines)==4);for(let line in lines)check(json(line).label==null);
 let f=fs.open(root+'/labels.jsonl','a');f.write('manual-fixture\n');f.close();create(root);
 check(fs.readfile(root+'/labels.jsonl')=='manual-fixture\n');
 let budget=root+'/budget';sample=create(budget);let count=0;
 for(let i=0;i<40;i++){devices['02:00:00:00:00:01']=device('version-'+i,t+i);count+=sample(devices,'router-fixture','boot-c',t+i).written;}
 check(count==32);sample=create(budget);check(sample(devices,'router-fixture','boot-c',t+41).written==0);
 let partial=root+'/partial';fs.mkdir(partial,0700);f=fs.open(partial+'/samples-current.jsonl','w',0600);f.write('{broken');f.close();
 sample=create(partial);devices['02:00:00:00:00:01']=device('tail-fixture',t);check(sample(devices,'router-fixture','boot-d',t).written==1);
 sample=create(partial);check(sample(devices,'router-fixture','boot-d',t+1).written==0);
 let rotation=root+'/rotation';fs.mkdir(rotation,0700);f=fs.open(rotation+'/samples-current.jsonl','w',0600);
 for(let i=0;i<1024;i++)f.write(sprintf('%4096s','x'));f.close();
 sample=create(rotation);check(sample(devices,'router-fixture','boot-e',t).written==1);
 check(fs.stat(rotation+'/samples-previous.jsonl').size==4194304);
 check(json(trim(fs.readfile(rotation+'/samples-current.jsonl'))).label==null);
}
printf('%d sampler assertions PASS\n',assertions);
