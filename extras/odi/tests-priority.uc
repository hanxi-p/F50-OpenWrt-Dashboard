import * as fs from 'fs';
import {resolve,indexDevices} from './subjects.uc';
import {archive} from './archive.uc';
import {normalize} from './wifi-normalize.uc';
let root=getenv('ODI_TEST_DIR');if(!root)die('isolated ODI_TEST_DIR required');fs.mkdir(root,0700);
let n=0;function check(v){if(!v)die('priority fixture failed');n++;}
function query(path,sql){let p=fs.popen("sqlite3 '"+path+"' '"+sql+"'",'r');let s=p.read('all');check(p.close()==0);return trim(s);}
for(let round=0;round<3;round++){
 let counter=0,uuid=()=>sprintf('fixture-id-%d',++counter),book={};
 let registry={version:1,profiles:{a:{name:"quote'); DROP TABLE devices;--"}},bindings:{'02:00:00:00:00:01':{id:'a'},'02:00:00:00:00:02':{id:'a'}}};
 check(resolve(book,registry,'02:00:00:00:00:01',1000,uuid).id=='a');
 let provisional=resolve(book,registry,'02:00:00:00:00:03',1000,uuid).id;
 check(resolve(book,registry,'02:00:00:00:00:03',1001,uuid).id==provisional);
 check(resolve(book,null,'02:00:00:00:00:01',1001,uuid).id=='a');
 let devices={'02:00:00:00:00:01':{},'02:00:00:00:00:02':{},'02:00:00:00:00:03':{}};
 let index=indexDevices(devices,book,registry,1002,uuid);check(length(index)==2);check(length(index.a.observed_identifiers)==2);
 registry.bindings['02:00:00:00:00:03']={id:'a'};index=indexDevices(devices,book,registry,1003,uuid);check(length(index)==1);
 check(normalize('probe',{address:'02:00:00:00:00:01'},'hostapd.test',1000)==null);
 check(normalize('assoc',{address:'bad'},'hostapd.test',1000)==null);
 check(normalize('assoc',{address:'02:00:00:00:00:01'},'hostapd.test',1000).stage=='associated');
 check(normalize('sta-authorized',{address:'02:00:00:00:00:01'},'hostapd.test',1000).stage=='authorized');
 check(normalize('deauth',{address:'02:00:00:00:00:01'},'hostapd.test',1000).stage=='disconnected');
 let dir=root+'/round-'+round;fs.mkdir(dir,0700);
 check(archive(dir,registry,devices,{devices:{}},'router-test',1700000000).ok);
 check(archive(dir,registry,devices,{devices:{}},'router-test',1700000001).ok);
 check(query(dir+'/archive.sqlite','SELECT count(*) FROM devices')=='1');
 check(query(dir+'/archive.sqlite','SELECT count(*) FROM identifiers WHERE active=1')=='3');
 check(query(dir+'/archive.sqlite','PRAGMA integrity_check')=='ok');
 // Forward schemas are rejected rather than silently downgraded.
 query(dir+'/archive.sqlite','PRAGMA user_version=9');
 check(archive(dir,registry,devices,{devices:{}},'router-test',1700000002).error=='unsupported_or_corrupt_archive');
 check(query(dir+'/archive.sqlite','PRAGMA user_version')=='9');
}
printf('%d identity/event/SQLite assertions PASS\n',n);
