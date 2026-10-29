import {pinDecision} from './recovery-policy.uc';
function check(v,m){if(!v)die(m);}
for(let n=0;n<3;n++){
 let g={type:'Fallback',name:'Auto',all:['A','B'],now:'A',fixed:'A'};
 check(pinDecision('Auto',g,true)==null,'healthy current retained');
 g.now='B';g.fixed='';check(pinDecision('Auto',g,true)=='B','pin only after underlying health event selected replacement');
 g.fixed='B';check(pinDecision('Auto',g,true)==null,'recovered preferred A does not trigger a return');
 check(pinDecision('Manual',g,true)==null,'manual choice respected');g.fixed='';check(pinDecision('Auto',g,false)==null,'all circuits bad: no forced rotation');
 g.now='Outside';check(pinDecision('Auto',g,true)==null,'outside regional pool rejected');
 print('PASS sticky failure-driven policy round\n');
}
