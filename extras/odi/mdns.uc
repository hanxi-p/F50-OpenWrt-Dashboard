function correlate(data,observed,now){
 let addresses={},rows=[];
 for(let mac,d in observed)for(let source,item in d.sources??{}){
  if(item.expires_at<now)continue;
  let v=item.value,address=null;
  if(source=='dhcp_lease')address=v.ip;
  if(index(source,'neighbour:')==0&&index(['REACHABLE','PERMANENT'],v.state)>=0)address=v.address;
  if(address){addresses[address]??={};addresses[address][mac]=true;}
 }
 for(let service,instances in data??{}){
  if(type(instances)!='object')continue;
  for(let name,v in instances){
   if(type(v)!='object'||(v.ttl!=null&&+v.ttl<=0))continue;
   let owners={};for(let address in [v.ipv4,v.ipv6])if(type(address)=='string')for(let mac in addresses[address]??{})owners[mac]=true;
   let macs=keys(owners);if(length(macs)!=1)continue;
   let model=match(v.txt??'',/(^|[[:space:];])(model|md|am)=([^;[:space:]]{1,128})/);
   let manufacturer=match(v.txt??'',/(^|[[:space:];])(manufacturer|vendor)=([^;[:space:]]{1,128})/);
   push(rows,{mac:macs[0],source:'mdns:'+substr(service,0,96)+':'+substr(name,0,96),value:{service:substr(service,0,96),instance:substr(name,0,128),host:substr(v.host??'',0,128),model_hint:model?model[3]:null,manufacturer_hint:manufacturer?manufacturer[3]:null,address_link:'unique_current_address_not_permanent_identity'}});
   if(length(rows)>=256)return rows;
  }
 }
 return rows;
}
export {correlate};
