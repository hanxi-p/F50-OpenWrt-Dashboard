'use strict';
'require rpc';
'require baseclass';
'require f50units as Units';
var prepare=rpc.declare({object:'f50nettest',method:'prepare',nobatch:true,expect:{'':{}}});
var ping=rpc.declare({object:'f50nettest',method:'ping',params:['target'],nobatch:true,expect:{'':{}}});
return baseclass.extend({mount:function(root){
 var stopped=false,busy=false,controller=null;
 var lan=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'内网测速');
 var domestic=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国内测速');
 var foreign=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国外测速');
 var primary=root.querySelector('.f50-primary-controls');
 // The three test buttons occupy the row after AdGuard / reboot / more.
 [lan,domestic,foreign].forEach(function(button){primary.appendChild(button);});
 var css=E('style',{},'.f50-home .f50-primary-controls>.f50-test-btn{background:#008cba!important;border-color:#008cba!important;color:#fff!important;opacity:1!important;flex-direction:column;white-space:normal;overflow-wrap:anywhere}.f50-home .f50-primary-controls>.f50-test-btn[data-running=true]{background:#238b45!important;border-color:#238b45!important;color:#fff!important}');root.appendChild(css);
 function state(button,on){busy=on;[lan,domestic,foreign].forEach(function(b){b.disabled=on;});button.setAttribute('data-running',String(on));}
 var rates={download:null,upload:null};
 function showRates(){lan.replaceChildren(E('span',{},'下载 '+(rates.download==null?'—':Units.fmtRate(rates.download))),E('span',{},'上传 '+(rates.upload==null?'—':Units.fmtRate(rates.upload))));}
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
 lan.onclick=async function(){if(busy)return;state(lan,true);rates={download:null,upload:null};showRates();controller=new AbortController();var timer=setTimeout(function(){controller.abort();},25000);
  try{var job=await prepare();if(job.error || !job.token)throw new Error('无法连接');await transfer(job.token,'download');await transfer(job.token,'upload');}
  catch(e){if(!stopped)lan.textContent='无法连接';}
  finally{clearTimeout(timer);controller=null;if(!stopped)state(lan,false);}
 };
 async function connectivity(target,button,label){if(busy)return;state(button,true);button.textContent=label+' …';
  try{
   var result=await ping(target);if(stopped)return;if(result.error)throw new Error('无法连接');
   var r=result[target==='domestic'?'baidu.com':'google.com']||{},raw=r.ping||'',avg=raw.match(/min\/avg\/max(?:\/[^ ]+)?\s*=\s*([\d.]+)\/([\d.]+)/);
   // The displayed ms is ICMP RTT only; never substitute HTTPS timing for ping.
   button.textContent=avg?label+' '+Number(avg[2]).toFixed(2)+' ms':'无法连接';
  }catch(e){if(!stopped)button.textContent='无法连接';}finally{if(!stopped)state(button,false);}
 }
 domestic.onclick=function(){return connectivity('domestic',domestic,'Baidu');};foreign.onclick=function(){return connectivity('foreign',foreign,'Google');};
 return function(){stopped=true;if(controller)controller.abort();[lan,domestic,foreign,css].forEach(function(el){el.remove();});};
}});
