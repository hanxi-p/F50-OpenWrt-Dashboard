'use strict';
'require baseclass';
'require rpc';
'require routertraffic.devices_v022 as Devices';
'require routertraffic.livechart_v022 as Chart';
'require routertraffic.units_v022 as Units';
'require routertraffic.resources_v022 as Resources';
var status=rpc.declare({object:'routertraffic',method:'status',expect:{'':{}}});
return baseclass.extend({title:'',load:function(){if(this._rtRoot&&document.documentElement.contains(this._rtRoot))return Promise.resolve(null);return status().catch(function(){return {};});},render:function(initial){
 // LuCI calls render on every overview poll. Returning null keeps the mounted
 // section intact; its own one-second loop already updates the live values.
 if(this._rtRoot&&document.documentElement.contains(this._rtRoot))return null;
 if(this._rtDispose)this._rtDispose();initial=initial||{};
 var wan=E('section',{class:'mud-sec rt-wan',hidden:initial.show_wan===false},[
  E('h3',{class:'rt-rate-title'},[E('span',{},'流量'),E('span',{},'今日峰值')]),
  E('div',{class:'rt-rates'},[
   E('div',{class:'rt-download'},[E('span',{},'下载 '),E('b',{'data-rate':'rx'},'—'),E('span',{'data-peak':'rx'},'—')]),
   E('div',{class:'rt-upload'},[E('span',{},'上传 '),E('b',{'data-rate':'tx'},'—'),E('span',{'data-peak':'tx'},'—')])]),
  E('div',{id:'mud-rate-chart'})]);
 var root=E('div',{class:'rt-root'},[E('link',{rel:'stylesheet',href:L.resource('routertraffic/style.css')+'?v=0.2.2'}),E('div',{class:'mud-body'},[wan])]);
 var disposeDevices=Devices.mount(root),disposeResources=Resources.mount(root),chart=initial.show_wan===false?null:Chart.mount(root),stopped=false,timer,lastTimestamp=null,lastAdvance=0;
 function draw(data){
  var now=performance.now();if(data.timestamp&&data.timestamp!==lastTimestamp){lastTimestamp=data.timestamp;lastAdvance=now;}
  var stale=data.stale||!data.timestamp||now-lastAdvance>4000;
  ['rx','tx'].forEach(function(key){root.querySelector('[data-rate="'+key+'"]').textContent=Units.fmtRate(stale?null:data[key+'_rate']);});
  ['rx','tx'].forEach(function(key){var el=root.querySelector('[data-peak="'+key+'"]'),value=Units.fmtRate(stale?null:data['peak_'+key]);if(el.textContent!==value)el.textContent=value;});
  if(chart&&!stale&&Array.isArray(data.history))chart.update(data.history.map(function(r){return r[0]*1000;}),data.history.map(function(r){return r[1];}),data.history.map(function(r){return r[2];}));
 }
 function refresh(){
  if(stopped)return;if(!document.documentElement.contains(root)){dispose();return;}
  var start=performance.now();status().then(draw).catch(function(){draw({stale:true});}).finally(function(){if(!stopped)timer=setTimeout(refresh,Math.max(20,1000-(performance.now()-start)));});
 }
 function dispose(){if(stopped)return;stopped=true;clearTimeout(timer);disposeDevices();disposeResources();if(chart)chart.dispose();window.removeEventListener('pagehide',dispose);}
 this._rtRoot=root;this._rtDispose=dispose;
 window.addEventListener('pagehide',dispose);draw(initial);if(chart)timer=setTimeout(refresh,1000);
 return root;
}});
