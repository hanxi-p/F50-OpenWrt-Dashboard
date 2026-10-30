import {filterRemoved} from '../app/controls.uc';
import {calculate} from '../app/ledger.uc';
let mac='02:50:aa:bb:cc:01',old='02:50:aa:bb:cc:02',other='02:50:aa:bb:cc:03',links={};links[mac]=old;
for(let round=0;round<3;round++){
 let state={version:1,devices:{}},peer={},control={deleted:{}};state.devices[mac]={total:100};state.devices[old]={total:200};state.devices[other]={total:300};peer[mac]={online:true};peer[other]={online:true};control.deleted[old]={id:'1793279000-'+round,at:1793279000};
 let source='sample a 1000 1793279000 0\n'+mac+' 0 888888 0 999999 0\n'+old+' 0 999999 0 888888 0\n';let archives=0;
 function archive(id,s){assert(s.records[mac].total+s.records[old].total==300,'archive both identity members');archives++;}
 let f=filterRemoved(state,source,peer,links,control,archive);assert(!state.devices[mac]&&!state.devices[old]&&state.devices[other].total==300&&!f.peers[mac]&&index(f.source,mac)<0,'delete only selected group and filter old raw counters');
 f=filterRemoved(state,source,peer,links,control,archive);assert(archives==1&&!f.peers[mac],'repeated sample neither restores nor repeats archive');
 filterRemoved(state,source,{},links,control,archive,false,'boot');f=filterRemoved(state,source,peer,links,control,archive,true,'boot');assert(!f.peers[mac],'failed scan never restores deleted device');
 let down={};down[other]=peer[other];filterRemoved(state,source,down,links,control,archive);
 f=filterRemoved(state,source,peer,links,control,archive);assert(f.peers[mac]&&state.removed[old].restored,'reconnect restores visibility');
 let result=calculate(state,f.source,f.peers,{},1793279000,'2026-10-29',links);assert(result.state.devices[mac].total==0,'reconnect establishes fresh baseline without historical recount');
 f=filterRemoved(result.state,source,peer,links,control,archive);assert(f.peers[mac]&&archives==1,'restored state persists without repeat deletion');
}
print('PASS controls three rounds: archive/group delete, unrelated history, repeated samples, offline/reconnect, fresh baseline\n');
