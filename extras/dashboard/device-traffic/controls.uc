import {identity} from './ledger.uc';
// The collector is the only writer of the ledger. RPC publishes requests only.
function filterRemoved(state, source, peers, links, controls, archive) {
 state.removed??={};let hidden={};
 for(let root,request in controls.deleted??{}) {
  if(!match(root,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)||!match(request.id??'',/^[0-9]+-[0-9]+$/))continue;
  let marker=state.removed[root];
  if(marker?.id!=request.id) {
   let records={};for(let mac,d in state.devices)if(identity(mac,links)==root)records[mac]=d;
   archive(request.id,{root:root,records:records,deleted_at:request.at});
   marker=state.removed[root]={id:request.id,offline:false,restored:false};
  }
  if(marker.restored)continue;
  let online=false;for(let mac,p in peers)if(identity(mac,links)==root&&p.online)online=true;
  if(!online)marker.offline=true;
  if(marker.offline&&online){marker.restored=true;continue;}
  hidden[root]=true;
 }
 for(let mac in state.devices)if(hidden[identity(mac,links)])delete state.devices[mac];
 let visible={};for(let mac,p in peers)if(!hidden[identity(mac,links)])visible[mac]=p;
 let lines=split(source,'\n'),clean=[lines[0]];
 for(let i=1;i<length(lines);i++){let mac=lc(split(trim(lines[i]),/\s+/)[0]??'');if(!hidden[identity(mac,links)])push(clean,lines[i]);}
 return {source:join('\n',clean),peers:visible};
}
export {filterRemoved};
