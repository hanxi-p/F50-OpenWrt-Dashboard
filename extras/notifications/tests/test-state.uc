import {advance,parseSMS,notifyAllowed,routeAdvance} from '../f50-bark-state.uc';
function check(ok,msg){if(!ok)die(msg);}
for(let round=0;round<3;round++){
 let s={};check(advance(s,'wifi',true)==null,'initial healthy');
 check(advance(s,'wifi',false)==null,'first transient');check(advance(s,'wifi',true)==null,'transient recovered silently');
 check(advance(s,'wifi',false)==null,'failure1');check(advance(s,'wifi',false)==null,'failure2');check(advance(s,'wifi',false)=='fault','fault threshold');
 check(advance(s,'wifi',false)==null,'repeat fault suppressed');check(advance(s,'wifi',true)==null,'recovery1');check(advance(s,'wifi',false)==null,'flap stays alert');
 check(advance(s,'wifi',true)==null,'recovery1 again');check(advance(s,'wifi',true)=='recovery','recovery2');check(advance(s,'wifi',true)==null,'repeat recovery suppressed');
 for(let n=0;n<3;n++)advance(s,'wifi',false);check(s.wifi.seq==2,'new incident id');
 let sms=parseSMS('dir: mt\nfrom: TEST\nscts: test\n\n模拟短信 & 引号" $标记\n第二行\n');
 check(sms.title=='F50 新短信','SMS title');check(sms.body=='发送号码：TEST\n短信原文：模拟短信 & 引号" $标记\n第二行','SMS multiline preservation');
 check(parseSMS('dir: mo\nfrom: TEST\n\noutgoing\n')==null,'outgoing excluded');check(parseSMS('incomplete')==null,'incomplete skipped');
}
print('PASS three rounds: fault/recovery thresholds, flap/dedup, incident IDs, incoming-only SMS and Unicode/multiline preservation\n');

for(let n=0;n<3;n++){check(!notifyAllowed('wan-test-1-fault')&&!notifyAllowed('wan-test-1-recovery'),'WAN state is diagnostic only');check(notifyAllowed('sms-000001')&&!notifyAllowed('dns-test-1-fault')&&notifyAllowed('kernel-test-1-fault'),'SMS and genuine service alarms preserved');}
print('PASS WAN notification policy three rounds\n');
for(let round=0;round<3;round++){
 let boot='aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb',snapshot={version:1,boot:boot,node:'JP-A'},first=routeAdvance(null,snapshot);
 check(first.event==null&&first.changed,'first route is a silent baseline');
 check(!routeAdvance(first.next,snapshot).changed,'healthy route is silent');
 snapshot.node='JP-B';let changed=routeAdvance(first.next,snapshot);
 check(changed.event.id=='route-'+boot+'-1'&&index(changed.event.body,'JP-A')>=0&&index(changed.event.body,'JP-B')>=0,'real change names both routes');
 check(routeAdvance(first.next,snapshot).event.id==changed.event.id,'retry uses same event id');
 check(!routeAdvance(changed.next,snapshot).changed,'worker restart keeps dedup state');
 snapshot.node='JP-A';check(routeAdvance(changed.next,snapshot).next.seq==2,'later actual return is another event');
 snapshot.boot='bbbbbbbb-1111-2222-3333-cccccccccccc';check(routeAdvance(changed.next,snapshot).event==null,'new boot does not replay switch');
 snapshot.boot=boot;snapshot.node='DIRECT';check(index(routeAdvance(changed.next,snapshot).event.body,'直连')>=0,'built-in route is readable');
 snapshot.node='';check(routeAdvance(changed.next,snapshot)==null,'empty observation rejected');
 snapshot.node='JP-C';snapshot.boot='invalid';check(routeAdvance(changed.next,snapshot)==null,'invalid boot rejected');
 check(routeAdvance({node:'JP-A',boot:boot,seq:-1},{version:1,node:'JP-B',boot:boot})==null,'corrupt sequence retained');
}
print('PASS route transition, baseline, restart, event-ID retry and invalid-input tests three rounds\n');
for(let round=0;round<3;round++){
 check(notifyAllowed('route-example-1'),'route notifications allowed on Bark');
 check(!notifyAllowed('route-example-1','wxpusher'),'route notifications disabled on WxPusher');
 check(notifyAllowed('sms-1','wxpusher')&&notifyAllowed('kernel-example-1-fault','wxpusher'),'WxPusher SMS and device faults retained');
}
print('PASS route channel policy three rounds\n');
