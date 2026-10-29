'use strict';
'require rpc';
'require baseclass';
'require f50units as Units';
var prepare=rpc.declare({object:'f50nettest',method:'prepare',nobatch:true,expect:{'':{}}});
var ping=rpc.declare({object:'f50nettest',method:'ping',params:['target'],nobatch:true,expect:{'':{}}});
return baseclass.extend({mount:function(root){
 var stopped=false,controller=null,busy=false;
 var lanOutput=E('div',{'aria-live':'polite'}),domesticOutput=E('div',{'aria-live':'polite'}),foreignOutput=E('div',{'aria-live':'polite'}),output=lanOutput;
 var lan=E('button',{class:'mud-btn'},'内网测速'),domestic=E('button',{class:'mud-btn'},'国内测速'),foreign=E('button',{class:'mud-btn'},'国外测速'),cancel=E('button',{class:'cbi-button',hidden:true},'停止内网测速');
 var grid=E('div',{style:'grid-column:1 / -1;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;align-items:start'});root.querySelector('.f50-primary-controls').insertBefore(grid,root.querySelector('#mud-btn-adguard'));
 var cards=[[lan,lanOutput],[domestic,domesticOutput],[foreign,foreignOutput]].map(function(item){
  var box=E('div',{class:'f50-nettest-item',style:'min-width:0;text-align:center'},item);
  item[0].style.cssText='width:100%;height:46px;min-width:0;box-sizing:border-box;margin:0;padding:6px;font-size:.75rem;font-weight:500;line-height:1.25;background:#fff;border:1px solid #008cba;color:#008cba';item[1].style.cssText='font-size:.68rem;line-height:1.5;overflow-wrap:anywhere;margin-top:5px';
  grid.appendChild(box);return box;
 });
 cards[0].appendChild(cancel);
 lan.title='当前设备与 F50 的内网吞吐量，不消耗蜂窝流量';domestic.title='F50 到百度的 ping 与 HTTPS 响应时间';foreign.title='F50 到谷歌的 ping 与 HTTPS 响应时间';
 function state(on){busy=on;lan.disabled=on;domestic.disabled=on;foreign.disabled=on;cancel.hidden=!on;}
 function line(text,color){var row=E('div',{style:color?'color:'+color:''},text);output.appendChild(row);return row;}
 cancel.onclick=function(){if(controller)controller.abort();};
 async function transfer(token,direction){
  var bytes=0,start=performance.now(),elapsed=0,row=line(direction==='download'?'正在测试内网下载…':'正在测试内网上传…',direction==='download'?'#509ed2':'#429f91');
  var payload=direction==='upload'?new Uint8Array(8388608):null;
  // Uncompressible payload; crypto.getRandomValues is limited to 65536 bytes/call.
  if(payload)for(var p=0;p<payload.length;p+=65536)crypto.getRandomValues(payload.subarray(p,p+65536));
  start=performance.now();
  do{
   var response;
   for(var retry=0;retry<10;retry++){response=await fetch('/cgi-bin/f50-nettest',{method:'POST',cache:'no-store',credentials:'same-origin',signal:controller.signal,headers:{'Content-Type':'application/x-f50-'+direction+'; token='+token},body:payload});if(response.status!==409)break;await response.text();await new Promise(function(resolve){setTimeout(resolve,100);});}
   if(!response.ok)throw new Error('测速请求失败（'+response.status+'）');
   if(direction==='download'){var data=await response.arrayBuffer();if(data.byteLength!==8388608)throw new Error('下载数据不完整');bytes+=data.byteLength;}
   else {var result=await response.json();if(result.bytes!==payload.length)throw new Error('上传数据不完整');bytes+=result.bytes;}
   elapsed=performance.now()-start;
   row.textContent=(direction==='download'?'内网下载：':'内网上传：')+Units.fmtRate(bytes/(elapsed/1000));
  }while(elapsed<4000 && bytes<134217728);
  row.textContent+=' · '+(elapsed/1000).toFixed(2)+'秒';
 }
 lan.onclick=async function(){if(busy)return;state(true);output=lanOutput;output.replaceChildren();controller=new AbortController();var timer=setTimeout(function(){controller.abort();},25000);
  try{var job=await prepare();if(job.error)throw new Error(job.error);await transfer(job.token,'download');await transfer(job.token,'upload');line('测速完成');}
  catch(e){if(!stopped)line(e.name==='AbortError'?'测速已停止或超时':e.message);}
  finally{clearTimeout(timer);controller=null;if(!stopped)state(false);}
 };
 async function connectivity(target,out){if(busy)return;state(true);cancel.hidden=true;out.replaceChildren();out.appendChild(E('div',{},'检测中…'));
  try{var result=await ping(target);if(stopped)return;out.replaceChildren();if(result.error)throw new Error(result.error);
   var r=result[target==='domestic'?'baidu.com':'google.com']||{},raw=r.ping||'',avg=raw.match(/min\/avg\/max(?:\/[^ ]+)?\s*=\s*([\d.]+)\/([\d.]+)/),loss=raw.match(/([\d.]+)% packet loss/),fake=/198\.(?:18|19)\./.test(raw);
   out.appendChild(E('div',{},avg?'ping '+Number(avg[2]).toFixed(2)+' ms'+(loss?' · 丢包 '+loss[1]+'%':''):fake?'代理虚拟 IP，无法测真实 ping':'ping 未响应（可能被过滤）'));
   var http=(r.https||'').trim().split(/\s+/),ok=r.https_ok===true && /^[23]\d\d$/.test(http[0]);out.appendChild(E('div',{},'HTTPS '+(ok?(Number(http[1])*1000).toFixed(2)+' ms':'未连通')));
  }catch(e){if(!stopped){out.replaceChildren();out.appendChild(E('div',{},e.message));}}finally{if(!stopped)state(false);}
 }
 domestic.onclick=function(){return connectivity('domestic',domesticOutput);};foreign.onclick=function(){return connectivity('foreign',foreignOutput);};
 return function(){stopped=true;if(controller)controller.abort();grid.remove();};
}});
