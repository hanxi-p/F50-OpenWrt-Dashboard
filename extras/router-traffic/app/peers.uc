import * as fs from 'fs';
function command(s){let p=fs.popen(s,'r');if(!p)return '';let value=p.read('all');p.close();return value??'';}
function valid(s){return type(s)=='string'&&match(s,/^[a-zA-Z0-9_.:-]+$/);}
function peers(bridge){
 let result={};
 for(let line in split(fs.readfile('/tmp/dhcp.leases')??'','\n')){
  let a=split(trim(line),/\s+/);if(length(a)<4)continue;
  if(match(a[1],/^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/))result[lc(a[1])]={ip:a[2],hostname:a[3]=='*'?'':a[3]};
 }
 for(let line in split(command('ip -4 neigh show dev '+bridge),'\n')){
  let m=match(line,/^(\S+) lladdr ([0-9a-fA-F:]{17})\s/);if(m){let mac=lc(m[2]);result[mac]??={};result[mac].ip=m[1];}
 }
 let wireless={};
 for(let path in fs.glob('/sys/class/net/*/phy80211')){
  let iface=split(path,'/')[4];if(!valid(iface))continue;wireless[iface]=true;
  let info=command('iw '+iface+' info'),f=match(info,/\((\d+) MHz\)/),kind=f&&+f[1]<3000?'wifi24':'wifi5';
  for(let line in split(command('iw '+iface+' station dump'),'\n')){
   let m=match(line,/^Station ([0-9a-fA-F:]{17})/);if(!m)continue;
   let mac=lc(m[1]);result[mac]??={};result[mac].connection=kind;result[mac].interface=iface;result[mac].online=true;
  }
 }
 let ports={};
 for(let path in fs.glob('/sys/class/net/'+bridge+'/brif/*/port_no')){
  let iface=split(path,'/')[6];if(valid(iface))ports[+trim(fs.readfile(path)??'0')]=iface;
 }
 // Linux's stable 16-byte __fdb_entry ABI; no bridge utility dependency.
 let data=hexenc(fs.readfile('/sys/class/net/'+bridge+'/brforward')??'');
 for(let at=0;at+32<=length(data);at+=32){
  let bytes=[];for(let i=0;i<16;i++)push(bytes,int(substr(data,at+i*2,2),16));
  if(bytes[7]||(bytes[0]&1))continue;
  let iface=ports[bytes[6]+256*bytes[12]];if(!iface||wireless[iface]||trim(fs.readfile('/sys/class/net/'+iface+'/carrier')??'')!='1')continue;
  let parts=[];for(let i=0;i<6;i++)push(parts,sprintf('%02x',bytes[i]));let mac=join(':',parts);
  if(result[mac]?.online)continue;
  result[mac]??={};result[mac].online=true;result[mac].interface=iface;result[mac].connection='wired';
 }
 return result;
}
export {peers};
