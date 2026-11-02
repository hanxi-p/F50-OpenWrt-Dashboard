function resolve(book,registry,mac,now,uuid){
 let valid=registry?.version==1&&type(registry.bindings)=='object'&&type(registry.profiles)=='object';
 let binding=valid?registry.bindings[mac]:null;
 if(binding&&registry.profiles[binding.id]){
  book[mac]={id:binding.id,state:'known',last_seen:now};return book[mac];
 }
 if(!valid&&book[mac])return {...book[mac],state:'registry_unavailable'};
 if(!book[mac]||book[mac].state=='known')book[mac]={id:uuid(),state:'provisional',last_seen:now};
 book[mac].last_seen=now;return book[mac];
}
function indexDevices(devices,book,registry,now,uuid){
 let index={};
 for(let mac,d in devices){
  let s=resolve(book,registry,mac,now,uuid);d.device_id=s.id;d.identity_state=s.state;
  index[s.id]??={device_id:s.id,state:s.state,observed_identifiers:[]};push(index[s.id].observed_identifiers,{kind:'mac',value:mac});
 }
 for(let mac,v in book)if(!devices[mac]&&now-v.last_seen>604800)delete book[mac];
 let recent=sort(keys(book),function(a,b){return book[b].last_seen-book[a].last_seen;});for(let i=2048;i<length(recent);i++)delete book[recent[i]];
 return index;
}
export {resolve,indexDevices};
