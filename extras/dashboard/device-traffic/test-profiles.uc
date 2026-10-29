import {seed,moveBinding,detach,derive,annotate,validate,listProfiles} from './profiles.uc';
import {calculate} from './ledger.uc';
let a='02:11:22:33:44:01',b='02:11:22:33:44:02',c='02:11:22:33:44:03';
for(let round=0;round<3;round++){
 let n=0;function uuid(){return sprintf('12345678-1234-4234-8234-%012d',++n);}
 let known={},aliases={},legacy={};known[a]={hostname:'Phone'};known[b]={hostname:'Phone'};known[c]={hostname:'Phone'};aliases[a]='Saved name';legacy[b]=a;
 let seeded=seed(null,known,aliases,legacy,1793318400,uuid),r=seeded.registry,id=r.bindings[a].id,other=r.bindings[c].id;
 assert(id==r.bindings[b].id&&id!=other,'only confirmed legacy links merge; same hostname never merges');
 assert(r.profiles[id].name=='Saved name','existing custom name retained');
 assert(!seed(r,known,{},legacy,1793318401,uuid).changed&&r.bindings[a].id==id,'repeat/restart IDs stable');
 let d=derive(r);assert(d.links[b]==a&&!d.links[a],'one-level compatibility map');
 let rows=[{mac:b,name:'new host'}];annotate(rows,r);assert(rows[0].device_id==id&&rows[0].name=='Saved name','new active MAC retains stable profile ID/name');
 let before=sprintf('%J',r),failed=false;
 try{moveBinding(r,c,id,other,false,1793318402,{});}catch(e){failed=true;}assert(failed&&sprintf('%J',r)==before,'unconfirmed request makes no mutation');
 failed=false;try{moveBinding(r,c,id,id,true,1793318402,{});}catch(e){failed=true;}assert(failed&&sprintf('%J',r)==before,'stale expected ownership rejected');
 let blocked={};blocked[a]=true;failed=false;try{moveBinding(r,c,id,other,true,1793318402,blocked);}catch(e){failed=true;}assert(failed&&sprintf('%J',r)==before,'blocked profile requires explicit unblock first');
 moveBinding(r,c,id,other,true,1793318403,{});assert(r.bindings[c].id==id&&r.profiles[id].name=='Saved name','explicit bind preserves target identity');
 let found=false;for(let profile in listProfiles(r,{}))if(profile.id==other&&length(profile.members)==0)found=true;assert(found,'empty historical profile remains selectable with original UUID');
 let state={version:1,devices:{}},peer={};for(let mac in known){state.devices[mac]={today_rx:10,today_tx:20,month_total:30,month_key:'2026-10',total:100,day:'2026-10-30'};peer[mac]={online:true};}
 d=derive(r);let result=calculate(state,'sample test 1000 1793318400 0\n',peer,d.aliases,1793318400,'2026-10-30',d.links);
 assert(length(result.public.devices)==1&&result.public.devices[0].total==300,'merge sums each raw MAC exactly once');
 detach(r,a,id,true,1793318404,{},uuid);assert(r.bindings[a].id!=id&&r.bindings[b].id==id&&r.profiles[id].anchor==b,'detach anchor leaves original profile ID stable');
 d=derive(r);result=calculate(state,'sample test 1000 1793318400 0\n',peer,d.aliases,1793318400,'2026-10-30',d.links);
 let total=0;for(let row in result.public.devices)total+=row.total;assert(length(result.public.devices)==2&&total==300,'detach preserves all raw totals without double count');
 validate(json(sprintf('%J',r)));assert(length(r.history)>=5,'persistent binding audit retained');
}
print('PASS profiles three rounds: UUID stability, legacy migration, no hostname guessing, guarded bind/detach, raw total conservation\n');
