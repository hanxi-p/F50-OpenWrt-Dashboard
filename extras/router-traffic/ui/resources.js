'use strict';
'require baseclass';
'require rpc';
'require routertraffic.units_v032 as Units';
var sample=rpc.declare({object:'routertraffic',method:'resources',expect:{'':{}}});
function percent(value){return Number.isFinite(value)?Math.round(Math.max(0,Math.min(100,value)))+'%':'—';}
return baseclass.extend({mount:function(root){
 function card(label,kind){var value=E('b',{},'—'),sub=E('span',{class:'rt-kpi-sub'}),bar=E('i'),meter=E('div',{class:'mud-meter rt-meter'},[bar]),el=E('div',{class:'mud-kpi rt-kpi '+kind},[value,E('span',{},label),sub,meter]);return {el:el,value:value,sub:sub,bar:bar};}
 var cpu=card('CPU 占用','rt-cpu-card'),ram=card('内存','rt-ram-card'),temp=card('','rt-temp-card'),disk=card('存储','rt-disk-card');
 temp.el.lastChild.remove();var details=E('details',{class:'rt-storage-details'},[E('summary',{},'存储详情'),E('div',{class:'rt-extra-cards'},[disk.el])]);
 var cores=E('div',{class:'rt-core-details rt-core-inline'}),section=E('section',{class:'mud-sec f50-load-section rt-load-section'},[E('h3',{},'设备负载与温度'),E('div',{class:'mud-kpis rt-kpis'},[cpu.el,ram.el,temp.el]),details]);
 cpu.el.insertBefore(cores,cpu.el.lastChild);root.querySelector('.mud-body').appendChild(section);
 var dead=false,timer,stamp=null,last=0;
 function text(el,value){if(el.textContent!==value)el.textContent=value;}
 function draw(data){
  var now=performance.now();if(data.timestamp&&stamp!==data.timestamp){stamp=data.timestamp;last=now;}var stale=!data.timestamp||now-last>4000;
  var usage=stale?null:data.cpu,m=data.memory||{},memory=m.total>0&&m.available>=0&&m.available<=m.total?100*(m.total-m.available)/m.total:null;
  text(cpu.value,percent(usage));cpu.bar.style.width=(usage==null?0:Math.max(0,Math.min(100,usage)))+'%';
  text(ram.value,percent(stale?null:memory));text(ram.sub,m.total>0?'余'+Units.fmtBytes(m.available,2,true)+'\n共'+Units.fmtBytes(m.total,2,true):'—');ram.bar.style.width=(memory==null?0:Math.max(0,Math.min(100,memory)))+'%';
  var temperatures=(data.temperatures||[]).filter(function(t){return Number.isFinite(t.celsius);}),average=temperatures.length?temperatures.reduce(function(s,t){return s+t.celsius;},0)/temperatures.length:null;
  text(temp.value,stale||average==null?'—':average.toFixed(1)+'°C');var signature=JSON.stringify(temperatures);if(temp.signature!==signature){temp.signature=signature;temp.sub.replaceChildren.apply(temp.sub,temperatures.map(function(t){var color=t.celsius>=75?'var(--danger,#8d1925)':t.celsius>=60?'var(--warning,#643e00)':'color-mix(in oklab,var(--success,#004f3e) 62%,var(--text,#121a22))';return E('span',{style:'color:'+color},(t.name==='cpu-thermal'?'CPU':t.name)+' '+t.celsius.toFixed(1)+'°C');}));}
  text(cores,(data.cores||[]).map(function(c){return c.name.toUpperCase()+' '+percent(stale?null:c.usage);}).join('\n'));
  var s=data.storage||{},used=s.total>0?100*s.used/s.total:null;text(disk.value,percent(stale?null:used));text(disk.sub,s.total>0?'余'+Units.fmtBytes(s.available,2,true)+' / 共'+Units.fmtBytes(s.total,2,true):'—');disk.bar.style.width=(used==null?0:Math.max(0,Math.min(100,used)))+'%';
 }
 function refresh(){if(dead)return;if(!document.documentElement.contains(root)){dispose();return;}var start=performance.now();sample().then(draw).catch(function(){draw({});}).finally(function(){if(!dead)timer=setTimeout(refresh,Math.max(20,1000-(performance.now()-start)));});}
 function dispose(){dead=true;clearTimeout(timer);}
 timer=setTimeout(refresh,0);return dispose;
}});
