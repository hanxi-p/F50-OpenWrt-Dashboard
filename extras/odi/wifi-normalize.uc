import {macOK} from './normalize.uc';
function normalize(type,data,object,now){
 if(index(['assoc','sta-authorized','disassoc','deauth'],type)<0)return null;
 let mac=lc(data?.address??data?.addr??'');if(!macOK(mac))return null;
 return {version:1,type:type,mac:mac,object:object,timestamp:now,reason:data.reason!=null?int(data.reason):null,
  stage:type=='sta-authorized'?'authorized':type=='assoc'?'associated':'disconnected',quality:'hostapd_notification'};
}
export {normalize};
