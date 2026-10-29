'use strict';
'require rpc';
'require baseclass';
var ping=rpc.declare({object:'f50nettest',method:'ping',params:['target'],nobatch:true,expect:{'':{}}});
return baseclass.extend({mount:function(root){
 var stopped=false,busy=false;
 var domestic=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国内延迟');
 var foreign=E('button',{class:'mud-btn f50-test-btn','aria-live':'polite'},'国外延迟');
 var primary=root.querySelector('.f50-primary-controls');
 // Two latency controls occupy the second row before More settings.
 [domestic,foreign].forEach(function(button){primary.insertBefore(button,root.querySelector('#mud-btn-other'));});
 var css=E('style',{},'.f50-home .f50-primary-controls>.f50-test-btn{background:#008cba!important;border-color:#008cba!important;color:#fff!important;opacity:1!important;padding:3px 4px!important;line-height:1.1!important;gap:0!important;flex-direction:column;white-space:normal;overflow-wrap:anywhere}.f50-home .f50-primary-controls>.f50-test-btn[data-running=true]{background:#238b45!important;border-color:#238b45!important;color:#fff!important}.f50-home .f50-primary-controls>.f50-test-btn[data-results=true]{font-size:.65rem!important}.f50-home .f50-test-btn>span{display:block;font-size:inherit!important;line-height:inherit}.f50-home .f50-test-result{font-size:inherit!important}@media(max-width:600px){.f50-home .f50-primary-controls>.f50-test-btn[data-results=true]{font-size:.62rem!important}}');root.appendChild(css);
 function state(button,on){busy=on;[domestic,foreign].forEach(function(b){b.disabled=on;});button.setAttribute('data-running',String(on));}
 var completed=new Map([[domestic,false],[foreign,false]]);
 function show(button,title,a,b){var results=a!=null||b!=null;button.setAttribute('data-results',String(results));button.replaceChildren(E('span',{},results?title.replace(/延迟$/,'')+(a?' '+a:''):title));if(b!=null)button.appendChild(E('span',{class:'f50-test-result'},b));}
 function reset(button,title){if(!completed.get(button))return false;completed.set(button,false);show(button,title);return true;}
 function bounded(promise,ms){return new Promise(function(resolve,reject){var timer=setTimeout(function(){reject(new Error('timeout'));},ms);promise.then(function(v){clearTimeout(timer);resolve(v);},function(e){clearTimeout(timer);reject(e);});});}
 async function connectivity(target,button,title,label){if(stopped||busy)return;if(reset(button,title))return;state(button,true);show(button,title,label,(target==='foreign'?'Https':'Ping')+' —');
  try{
   var result=await bounded(ping(target),12000);if(stopped)return;if(result.error)throw new Error('无法连接');
   var r=result[target==='domestic'?'baidu.com':'google.com']||{},raw=r.ping||'',avg=raw.match(/min\/avg\/max(?:\/[^ ]+)?\s*=\s*([\d.]+)\/([\d.]+)/);
   var value=target==='foreign'?(r.https_ok===true&&typeof r.https_ms==='number'&&Number.isFinite(r.https_ms)&&r.https_ms>=0?'Https '+Number(r.https_ms).toFixed(2)+'ms':'无法连接'):(avg?'Ping '+Number(avg[2]).toFixed(2)+'ms':'无法连接');
   show(button,title,label,value);
  }catch(e){if(!stopped)show(button,title,label,'无法连接');}finally{if(!stopped){completed.set(button,true);state(button,false);}}
 }
 domestic.onclick=function(){return connectivity('domestic',domestic,'国内延迟','Baidu');};foreign.onclick=function(){return connectivity('foreign',foreign,'国外延迟','Google');};
 return function(){stopped=true;[domestic,foreign,css].forEach(function(el){el.remove();});};
}});
