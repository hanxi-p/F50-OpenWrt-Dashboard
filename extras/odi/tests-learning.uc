import {update,infer} from './learning.uc';
import {suggest} from './identity.uc';
import {correlate} from './mdns.uc';
function check(v){if(!v)die('feature learning fixture failed');}
function device(name,at){return {expires_at:at+90,sources:{dhcp_lease:{observed_at:at,expires_at:at+90,value:{hostname:name,ip:'192.0.2.1'}}}};}
for(let round=0;round<3;round++){
 let registry={version:1,profiles:{a:{},b:{}},bindings:{old:{id:'a'}}};
 let devices={old:device('first-name',1000)},h=update(null,devices,1000);
 h=update(h,devices,1001);check(h.devices.old.fields.hostname.variants[0].windows==1);
 devices.old=device('second-name',1002);h=update(h,devices,1002);
 check(length(h.devices.old.fields.hostname.variants)==2);
 devices.old=device('first-name',1300);h=update(h,devices,1300);
 let count=0;for(let v in h.devices.old.fields.hostname.variants)if(v.value=='first-name')count=v.windows;
 check(count==2);
 // A historical name still recalls its profile after the newest name changes.
 devices.old=device('second-name',1600);h=update(h,devices,1600);devices.next=device('first-name',1600);
 let result=infer(h,devices,registry,1600,suggest(devices,registry,1600));
 check(result.results[0].candidates[0].device_id=='a');
 check(result.results[0].automatic_link===false);
 check(result.results[0].candidates[0].learned_evidence[0].observed_windows==2);
 // Registry reassignment affects lookup, without rewriting MAC feature history.
 registry.bindings.old.id='b';
 check(infer(h,devices,registry,1600,suggest(devices,registry,1600)).results[0].candidates[0].device_id=='b');
 registry.bindings.other={id:'a'};devices.other=device('first-name',1600);h=update(h,devices,1600);
 result=infer(h,devices,registry,1600,suggest(devices,registry,1600));
 check(result.results[0].state=='conflict');
 check(result.results[0].candidates[0].learned_evidence[0].matching_profiles==2);
 let obs={one:device('name-one',1000)},data={'_example._tcp':{instance:{ipv4:'192.0.2.1',host:'example'}}};
 check(length(correlate(data,obs,1000))==1);
 data['_example._tcp'].instance.txt='model=fixture-model manufacturer=fixture-vendor';
 check(correlate(data,obs,1000)[0].value.model_hint=='fixture-model');
 data['_example._tcp'].instance.ttl=0;check(length(correlate(data,obs,1000))==0);delete data['_example._tcp'].instance.ttl;
 obs.two=device('name-two',1000);check(length(correlate(data,obs,1000))==0);
 delete obs.two;check(length(correlate(data,obs,1200))==0);
 for(let i=0;i<8;i++){devices.old=device('version-'+i,2000+i);h=update(h,devices,2000+i);}
 check(length(h.devices.old.fields.hostname.variants)<=4);
 h=update(h,{},1000000);check(length(h.devices)==0);
}
print('48 learning and mDNS assertions PASS\n');
