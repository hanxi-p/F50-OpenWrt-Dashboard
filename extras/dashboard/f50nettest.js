'use strict';
'require rpc';
'require baseclass';
'require f50units as Units';
var prepare=rpc.declare({object:'f50nettest',method:'prepare',nobatch:true,expect:{'':{}}});
var finish=rpc.declare({object:'f50nettest',method:'finish',params:['token'],nobatch:true,expect:{'':{}}});
var ping=rpc.declare({object:'f50nettest',method:'ping',params:['target'],nobatch:true,expect:{'':{}}});
return baseclass.extend({mount:function(root){
 var stopped=false,busy=false,controller=null;
 var lan=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'内网速度');
 var domestic=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国内延迟');
 var foreign=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国外延迟');
 var primary=root.querySelector('.f50-primary-controls');
 // Keep three tests between the first and third control rows.
 [lan,domestic,foreign].forEach(function(button){primary.insertBefore(button,root.querySelector('#mud-btn-adguard'));});
 var css=E('style',{},'.f50-home .f50-primary-controls>.f50-test-btn{background:#008cba!important;border-color:#008cba!important;color:#fff!important;opacity:1!important;padding:3px 4px!important;line-height:1.1!important;gap:0!important;flex-direction:column;white-space:normal;overflow-wrap:anywhere}.f50-home .f50-primary-controls>.f50-test-btn[data-running=true]{background:#238b45!important;border-color:#238b45!important;color:#fff!important}.f50-home .f50-primary-controls>.f50-test-btn[data-results=true]{font-size:.65rem!important}.f50-home .f50-test-btn>span{display:block;font-size:inherit!important;line-height:inherit}.f50-home .f50-test-result{font-size:inherit!important}@media(max-width:600px){.f50-home .f50-primary-controls>.f50-test-btn[data-results=true]{font-size:.62rem!important}}');root.appendChild(css);
 function state(button,on){busy=on;[lan,domestic,foreign].forEach(function(b){b.disabled=on;});button.setAttribute('data-running',String(on));}
 var rates={download:null,upload:null},completed=new Map([[lan,false],[domestic,false],[foreign,false]]);
 function show(button,title,a,b){button.setAttribute('data-results',String(a!=null||b!=null));button.replaceChildren(E('span',{},title));if(a!=null)button.appendChild(E('span',{class:'f50-test-result'},a));if(b!=null)button.appendChild(E('span',{class:'f50-test-result'},b));}
 function reset(button,title){if(!completed.get(button))return false;completed.set(button,false);show(button,title);return true;}
 function showRates(){show(lan,'内网速度','上传 '+(rates.upload==null?'—':Units.fmtRate(rates.upload)),'下载 '+(rates.download==null?'—':Units.fmtRate(rates.download)));}
 function bounded(promise,ms){return new Promise(function(resolve,reject){var timer=setTimeout(function(){reject(new Error('timeout'));},ms);promise.then(function(v){clearTimeout(timer);resolve(v);},function(e){clearTimeout(timer);reject(e);});});}
 async function release(token){if(!token)return;for(var i=0;i<3;i++){try{var r=await bounded(finish(token),1500);if(r.ok)return;}catch(e){}await new Promise(function(resolve){setTimeout(resolve,100);});}}
 async function transfer(token,direction){
  var bytes=0,payload=direction==='upload'?new Uint8Array(8388608):null;
  if(payload)for(var p=0;p<payload.length;p+=65536)crypto.getRandomValues(payload.subarray(p,p+65536));
  var start=performance.now(),elapsed=0;
  do{
   var response;
   for(var retry=0;retry<10;retry++){
    response=await fetch('/cgi-bin/f50-nettest',{method:'POST',cache:'no-store',credentials:'same-origin',signal:controller.signal,headers:{'Content-Type':'application/x-f50-'+direction+'; token='+token},body:payload});
    if(response.status!==409)break;await response.text();await new Promise(function(resolve){setTimeout(resolve,100);});
   }
   if(!response.ok)throw new Error('无法连接');
   if(direction==='download'){var data=await response.arrayBuffer();if(data.byteLength!==8388608)throw new Error('无法连接');bytes+=data.byteLength;}
   else {var result=await response.json();if(result.bytes!==payload.length)throw new Error('无法连接');bytes+=result.bytes;}
   elapsed=performance.now()-start;rates[direction]=bytes/(elapsed/1000);if(!stopped)showRates();
  }while(elapsed<5000);
 }
 lan.onclick=async function(){if(stopped||busy)return;if(reset(lan,'内网速度'))return;state(lan,true);rates={download:null,upload:null};showRates();controller=new AbortController();var job,timer=setTimeout(function(){controller.abort();},25000);
  try{job=await bounded(prepare(),8000);if(job.error || !job.token)throw new Error('无法连接');await transfer(job.token,'download');await transfer(job.token,'upload');}
  catch(e){if(!stopped)show(lan,'内网速度','上传 无法连接','下载 无法连接');}
  finally{clearTimeout(timer);await release(job&&job.token);controller=null;if(!stopped){completed.set(lan,true);state(lan,false);}}
 };
 async function connectivity(target,button,title,label){if(stopped||busy)return;if(reset(button,title))return;state(button,true);show(button,title,label,(target==='foreign'?'HTTPS':'Ping')+' —');
  try{
   var result=await bounded(ping(target),12000);if(stopped)return;if(result.error)throw new Error('无法连接');
   var r=result[target==='domestic'?'baidu.com':'google.com']||{},raw=r.ping||'',avg=raw.match(/min\/avg\/max(?:\/[^ ]+)?\s*=\s*([\d.]+)\/([\d.]+)/);
   var value=target==='foreign'?(r.https_ok===true&&typeof r.https_ms==='number'&&Number.isFinite(r.https_ms)&&r.https_ms>=0?'HTTPS '+Number(r.https_ms).toFixed(2)+'ms':'无法连接'):(avg?'Ping '+Number(avg[2]).toFixed(2)+'ms':'无法连接');
   show(button,title,label,value);
  }catch(e){if(!stopped)show(button,title,label,'无法连接');}finally{if(!stopped){completed.set(button,true);state(button,false);}}
 }
 domestic.onclick=function(){return connectivity('domestic',domestic,'国内延迟','Baidu');};foreign.onclick=function(){return connectivity('foreign',foreign,'国外延迟','Google');};
 return function(){stopped=true;if(controller)controller.abort();[lan,domestic,foreign,css].forEach(function(el){el.remove();});};
}});
