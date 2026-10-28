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

export {advance,parseSMS};
