import {advance,parseSMS} from '../f50-bark-state.uc';
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
