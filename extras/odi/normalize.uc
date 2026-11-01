function macOK(v){return type(v)=='string'&&!!match(lc(v),/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/);}
function clientID(value,mac){
 if(!value||value=='*')return null;
 if(lc(value)=='01:'+lc(mac))return {value:value,independent:false};
 return {value:substr(value,0,256),independent:null};
}
function lease(line,now){
 let a=split(trim(line),/\s+/);
 if(length(a)<4||!macOK(a[1]))return null;
 let expires=+a[0];if(expires!=0&&expires<=now)return null;
 return {mac:lc(a[1]),ip:a[2],hostname:a[3]=='*'?null:substr(a[3],0,96),client_id:clientID(a[4],a[1]),expires:expires};
}
function radio(client){
 let features={};
 for(let key in ['ht','vht','he','eht','wmm','mfp','rrm','extended_capabilities','capabilities'])
  if(client[key]!=null)features[key]=client[key];
 // Keep reported fields, but never turn empty/default driver responses into strong identity evidence.
 let incomplete=!length(client.capabilities??{})&&!client.ht&&!client.vht&&!client.he&&!client.eht;
 return {schema:'wifi-reported-v1',quality:incomplete?'limited':'reported',features:features,
  associated:client.assoc===true,authorized:client.authorized===true,
  diagnostic:{signal:client.signal??null,rate:client.rate??null}};
}
export {macOK,clientID,lease,radio};
