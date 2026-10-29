import * as fs from 'fs';
let size=8388608,chunk=65536;
if(getenv('HTTP_X_F50_DIRECTION')=='download'){
 let random=fs.open('/dev/urandom','r'),data=random?.read(chunk);random?.close();
 if(length(data)!=chunk)die('random source unavailable');
 print('Content-Type: application/octet-stream\r\nContent-Length: '+size+'\r\nCache-Control: no-store, no-transform\r\nX-Content-Type-Options: nosniff\r\n\r\n');
 for(let n=0;n<size;n+=chunk)if(fs.stdout.write(data)!=chunk)exit(1);
 fs.stdout.flush();
}else{
 let received=0;
 while(received<size){let data=fs.stdin.read(min(chunk,size-received));if(!length(data))break;received+=length(data);}
 print((received==size?'':'Status: 400 Bad Request\r\n')+'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'+sprintf('%J',{bytes:received}));
}
