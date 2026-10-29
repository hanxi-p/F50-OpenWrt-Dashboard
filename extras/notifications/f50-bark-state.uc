function advance(states, key, ok) {
 let s=states[key] ?? {bad:0,good:0,alert:false,seq:0}; states[key]=s;
 if(ok){s.bad=0;s.good=min(2,s.good+1);if(s.alert && s.good>=2){s.alert=false;return 'recovery';}}
 else{s.good=0;s.bad=min(3,s.bad+1);if(!s.alert && s.bad>=3){s.alert=true;s.seq++;return 'fault';}}
 return null;
}
function parseSMS(raw) {
 let cut=index(raw,'\n\n');if(cut<0)return null;
 let headers=substr(raw,0,cut),body=substr(raw,cut+2),from='未知',incoming=false;
 for(let line in split(headers,'\n')){if(line=='dir: mt')incoming=true;if(substr(line,0,6)=='from: ')from=substr(line,6);}
 if(!incoming)return null;
 if(substr(body,-1)=='\n')body=substr(body,0,length(body)-1);
 return {title:'F50 新短信',body:'发送号码：'+from+'\n短信原文：'+body};
}

function notifyAllowed(id,channel){
 if(type(id)!='string')return false;
 if(channel=='wxpusher')return !!match(id,/^sms-[0-9]+$/);
 return !match(id,/^(wan|dns)-/);
}
function barkTTL(id){
 return type(id)=='string'&&(match(id,/^(route|boot|ready)-/)||match(id,/^(wifi|devices|kernel)-.+-recovery$/))?600:0;
}
function routeAdvance(previous,snapshot){
 if(type(snapshot)!='object'||snapshot.version!=1||type(snapshot.node)!='string'||!length(snapshot.node)||length(snapshot.node)>512||!match(snapshot.boot??'',/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/))return null;
 if(previous!=null && (type(previous)!='object'||type(previous.node)!='string'||type(previous.seq)!='int'||previous.seq<0||previous.seq>=2147483647))return null;
 let next={boot:snapshot.boot,node:snapshot.node,seq:previous?.seq??0};
 if(!previous||previous.boot!=snapshot.boot){next.seq=0;return {next:next,event:null,changed:true};}
 if(previous.node==snapshot.node)return {next:previous,event:null,changed:false};
 next.seq++;
 let labels={DIRECT:'直连',REJECT:'拒绝连接'},id='route-'+snapshot.boot+'-'+next.seq;
 return {next:next,changed:true,event:{id:id,title:'F50 节点已切换',body:'原节点：'+(labels[previous.node]??previous.node)+'\n当前节点：'+(labels[snapshot.node]??snapshot.node)}};
}
export {advance,parseSMS,notifyAllowed,routeAdvance,barkTTL};
