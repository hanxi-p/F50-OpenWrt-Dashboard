#!/usr/bin/ucode
import * as fs from 'fs';
import * as loop from 'uloop';
import {notifyAllowed} from './f50-bark-state.uc';
const D='/etc/mu300/wxpusher',Q=D+'/outbox',S=D+'/sent';
function put(path,value){let f=fs.open(path+'.new','w',0600);if(!f)die('WxPusher state write failed');f.write(sprintf('%J',value));f.close();if(!fs.rename(path+'.new',path))die('WxPusher atomic rename failed');system('sync >/dev/null 2>&1');}
function mono(){let t=clock(true);return t[0]+t[1]/1000000000;}
let retry={};
function deliver(){
 let items=fs.glob(Q+'/*');sort(items);
 for(let path in items){let id=substr(path,length(Q)+1);if(!match(id,/^[a-zA-Z0-9_-]+$/))continue;
  if(fs.stat(S+'/'+id)){fs.unlink(path);continue;}
  if(!notifyAllowed(id)){fs.mkdir(D+'/suppressed',0700);if(!fs.rename(path,D+'/suppressed/'+id))die('suppression archive failed');continue;}
  let attempt=retry[id]??{failures:0,next:0};if(mono()<attempt.next)continue;
  if(system('/usr/libexec/f50-wxpusher-send "'+path+'" >/dev/null 2>&1')==0){put(S+'/'+id,{sent:time()});fs.unlink(path);delete retry[id];}
  else{attempt.failures++;attempt.next=mono()+min(600,30*(2**min(5,attempt.failures-1)));retry[id]=attempt;}
  break;
 }
}
loop.init();let timer;
function tick(){try{deliver();}catch(e){warn('f50-wxpusher: operation failed; messages retained\n');}timer.set(10000);}
timer=loop.timer(1,tick);loop.run();
