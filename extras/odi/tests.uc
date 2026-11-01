import {suggest,canonical} from './identity.uc';
import {clientID} from './normalize.uc';
function check(v){if(!v)die('ODI shadow fixture failed');}
function observation(name,active){return {expires_at:1090,sources:{dhcp_lease:{observed_at:1000,expires_at:1090,value:{hostname:name}},'wifi:test':{observed_at:1000,expires_at:1090,value:{quality:'reported',frequency:5200,associated:active,authorized:active,features:{he:true,vht:true}}}}};}
for(let round=0;round<3;round++){
 let registry={version:1,profiles:{a:{},b:{}},bindings:{old:{id:'a'}}};
 let devices={old:observation('unique-laptop',false),next:observation('unique-laptop',true)},original=sprintf('%J',devices);
 let r=suggest(devices,registry,1000);
 check(r.results[0].state=='candidate');check(r.results[0].automatic_link===false);
 check(sprintf('%J',devices)==original);
 devices.other=observation('unique-laptop',false);registry.bindings.other={id:'b'};
 check(suggest(devices,registry,1000).results[0].state=='conflict');
 delete registry.bindings.other;delete devices.other;
 devices.old=observation('unique-laptop',true);
 check(suggest(devices,registry,1000).results[0].state=='conflict');
 devices.old=observation('unique-laptop',false);devices.next.expires_at=900;
 check(length(suggest(devices,registry,1000).results)==0);
 check(suggest(devices,null,1000).error=='registry_unavailable');
 check(sprintf('%J',canonical({b:2,a:1}))==sprintf('%J',canonical({a:1,b:2})));
 check(clientID('01:02:00:00:00:00:01','02:00:00:00:00:01').independent===false);
 devices.next=observation('iphone',true);devices.old=observation('iphone',false);
 for(let key in ['next','old'])devices[key].sources['wifi:test'].value.quality='limited';
 check(suggest(devices,registry,1000).results[0].state=='unknown');
 // An active nonmatching interface in a profile still vetoes an apparent match to another member.
 devices={old:observation('unique-laptop',false),next:observation('unique-laptop',true),other:observation('other-device-name',true)};
 devices.other.sources['wifi:test'].value.features={he:false};registry.bindings.other={id:'a'};
 check(suggest(devices,registry,1000).results[0].state=='conflict');
}
print('33 shadow assertions PASS\n');
