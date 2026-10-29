'use strict';
'require baseclass';
'require rpc';
'require ui';
'require routertraffic.units_v022 as Units';
var status=rpc.declare({object:'routertraffic',method:'devices',expect:{'':{}}});
var rename=rpc.declare({object:'routertraffic',method:'rename',params:['mac','name'],expect:{'':{}}});
function size(n,rate){return rate?Units.fmtRate(n):Units.fmtBytes(n,2,true);}
function todayDownloadRank(d){return d.today_rx!=null&&Number.isFinite(+d.today_rx)&&+d.today_rx>=0?+d.today_rx:-1;}
return baseclass.extend({mount:function(root){
 var toggle=E('button',{type:'button',class:'rt-device-toggle','aria-expanded':'true','aria-controls':'rt-device-content',title:'按外网连接字节统计，包含协议开销及实际 TCP 重传'},'设备流量统计');
 var content=E('div',{id:'rt-device-content'}),section=E('section',{class:'mud-sec rt-devices'},[E('h3',{},[toggle]),content]);
 var panels=E('div',{class:'rt-device-panels'});content.appendChild(panels);
 toggle.onclick=function(){content.hidden=!content.hidden;toggle.setAttribute('aria-expanded',String(!content.hidden));};
 var anchor=root.querySelector('.mud-body > .mud-sec');anchor.insertAdjacentElement('afterend',section);
 section.appendChild(E('style',{},`
 .rt-devices{min-width:0;--rt-device-total:#8970b3}
 .rt-device-panels{display:grid;grid-template-columns:minmax(0,1fr);gap:14px}
 .rt-device-toggle{border:0!important;background:transparent!important;color:inherit!important;font:inherit!important;padding:0!important;text-align:left;cursor:pointer}
 .rt-devices .rt-device-offline-heading>td{width:auto!important;height:32px;padding:6px 10px;text-align:left;background:var(--surface-sunken,var(--background-alt,#f5f7fa))}
 .rt-root .rt-devices .rt-device-offline-toggle{border:0!important;background:transparent!important;color:var(--text-muted,#666)!important;font:inherit!important;font-size:.7rem!important;font-weight:500!important;padding:0!important;text-align:left;cursor:pointer}
 .rt-device-panel{--rt-device-accent:color-mix(in srgb,var(--f50-dl,#249ad1) 65%,var(--f50-ul,#159b85));min-width:0;border:1px solid var(--hairline,var(--border,#e3e6ea));border-top:2px solid var(--rt-device-accent);border-radius:var(--radius-base,.5rem);overflow:hidden;background:var(--surface,var(--background-alt,var(--background,#fff)));color:var(--text,#222)}
 .rt-device-panel.wifi5{--rt-device-accent:var(--f50-dl,#249ad1)}
 .rt-device-panel.wired{--rt-device-accent:var(--f50-ul,#159b85)}
 .modal.rt-device-name-modal{box-sizing:border-box;width:min(320px,calc(100vw - 40px))!important;min-width:0!important;max-width:calc(100vw - 40px)!important}
 .modal.rt-device-name-modal p{overflow-wrap:anywhere}
 .rt-device-scroll{max-height:none;overflow:auto;overflow-anchor:none;scrollbar-gutter:stable}
 .rt-devices table{table-layout:fixed;border-collapse:separate;border-spacing:0;width:100%;min-width:620px;font-size:12px;margin:0}
 .rt-devices th,.rt-devices td{box-sizing:border-box;height:54px;padding:8px 10px;white-space:nowrap;text-align:center;vertical-align:middle;line-height:1.4;font-variant-numeric:tabular-nums;border-bottom:1px solid var(--hairline,var(--border,#e3e6ea))}
 .rt-devices th:first-child,.rt-devices td:first-child{text-align:left;width:26%}
 .rt-devices th:nth-child(2),.rt-devices td:nth-child(2),.rt-devices th:nth-child(3),.rt-devices td:nth-child(3){width:22%}
 .rt-devices th{position:sticky;top:0;z-index:1;height:40px;background:var(--surface-sunken,var(--background-alt,#f5f7fa));font-weight:600;text-align:center}
 .rt-devices th:first-child{text-align:left}
 .rt-devices th span{display:inline;white-space:nowrap}
 .rt-devices tbody tr:nth-child(even){background:color-mix(in srgb,var(--surface-sunken,rgba(127,127,127,.06)) 50%,var(--surface,var(--background,#fff)))}
 .rt-devices tbody tr:hover{background:var(--brand-subtle,var(--hover-faint,rgba(36,154,209,.08)))}
 .rt-device-pair>span{display:block;line-height:1.35}
 .rt-device-pair>span+span{margin-top:2px}
 .rt-devices .rt-device-dl{color:var(--f50-dl,#249ad1)}
 .rt-devices .rt-device-ul{color:var(--f50-ul,#159b85)}
 .rt-devices td:nth-child(4),.rt-devices th:nth-child(4),.rt-devices th:nth-child(5){color:var(--rt-device-total)}
 .rt-devices td:nth-child(4),.rt-devices td:nth-child(5){font-weight:400}
 .rt-devices td:nth-child(5){color:var(--rt-device-total)}
 .rt-device-name{display:block;width:100%;white-space:normal;overflow-wrap:anywhere;border:0!important;background:transparent!important;color:inherit!important;padding:0!important;text-align:left;font:inherit;font-size:.92em;line-height:1.35;font-weight:600;cursor:pointer}
 .rt-device-offline{opacity:.65}.rt-device-offline .rt-device-name:before{content:'○ ';font-weight:400}
 @media(min-width:1500px){.rt-devices table{font-size:13px}.rt-devices td,.rt-devices th{padding:10px 14px}}
 @media(max-width:767px){
  .rt-device-panels{grid-template-columns:minmax(0,1fr);gap:8px}
  .rt-device-scroll{scrollbar-gutter:auto}
  .rt-devices table{min-width:0;width:100%;font-size:10px;line-height:1.3}
  .rt-devices th,.rt-devices td{height:50px;padding:6px 4px;white-space:nowrap;line-height:1.3;vertical-align:middle}
  .rt-devices th{height:36px;font-size:9px}
  .rt-devices th:first-child,.rt-devices td:first-child{width:28%;padding-left:8px}
  .rt-devices th:nth-child(2),.rt-devices td:nth-child(2){width:22%}
  .rt-devices th:nth-child(3),.rt-devices td:nth-child(3){width:20%}
  .rt-devices th:nth-child(4),.rt-devices td:nth-child(4),.rt-devices th:nth-child(5),.rt-devices td:nth-child(5){padding-left:2px;padding-right:2px}
  .rt-devices td:nth-child(4),.rt-devices td:nth-child(5){font-size:9px}
  .rt-device-name{font-size:9px}
 }
 @media(max-width:359px){
  .rt-devices table{font-size:9px}
  .rt-devices th{font-size:8.5px}
  .rt-devices th,.rt-devices td{padding:6px 3px}
  .rt-device-name{font-size:8px}
 }
 @media(orientation:landscape) and (max-height:600px) and (max-width:1100px) and (pointer:coarse){
  .rt-device-panels{grid-template-columns:minmax(0,1fr)}
  .rt-device-scroll{scrollbar-gutter:auto}
  .rt-devices table{min-width:0;width:100%;font-size:11px;line-height:1.2}
  .rt-devices th,.rt-devices td{height:52px;padding:6px 8px;white-space:nowrap;vertical-align:middle}
  .rt-devices th{height:36px;white-space:nowrap}
  .rt-devices th:first-child,.rt-devices td:first-child{padding-left:12px}
  .rt-devices th:first-child,.rt-devices td:first-child{width:26%}
  .rt-devices th:nth-child(2),.rt-devices td:nth-child(2),.rt-devices th:nth-child(3),.rt-devices td:nth-child(3){width:22%}
  .rt-devices td:nth-child(4),.rt-devices td:nth-child(5){font-size:11px}
  .rt-device-name{font-size:10px;line-height:1.25;white-space:normal;overflow:visible;text-overflow:clip;overflow-wrap:anywhere}
 }
 `));
 var rows={},dead=false,timer,busy=false,lastTimestamp=null,lastAdvance=0;
 var online={body:E('tbody')},offline={body:E('tbody',{id:'rt-device-offline-rows',hidden:true})};
 var offlineLabel=E('button',{type:'button',class:'rt-device-offline-toggle','aria-expanded':'false','aria-controls':'rt-device-offline-rows'},'离线设备');
 var offlineGroup=E('tbody',{class:'rt-device-offline-group',hidden:true},[E('tr',{class:'rt-device-offline-heading'},[E('td',{colspan:5},[offlineLabel])])]);
 var table=E('table',{},[E('thead',{},[E('tr',{},['设备名称','实时速率','今日流量','本月累计','总累计'].map(function(t){return E('th',{},t);} ))]),online.body,offlineGroup,offline.body]);
 var scroll=E('div',{class:'rt-device-scroll'},[table]);
 panels.appendChild(E('article',{class:'rt-device-panel','aria-label':'设备流量统计'},[scroll]));
 offlineLabel.onclick=function(){offline.body.hidden=!offline.body.hidden;offlineLabel.setAttribute('aria-expanded',String(!offline.body.hidden));};
 function edit(d){var input=E('input',{type:'text',value:d.name,style:'width:100%;min-width:0;box-sizing:border-box',maxlength:96});
  ui.showModal('设备名称',[E('p',{},d.mac+' · '+d.ip),input,E('p',{},'留空恢复主机名；名称按 MAC 保存。'),E('div',{class:'right'},[
   E('button',{class:'btn',click:ui.hideModal},'取消'),E('button',{class:'btn cbi-button-positive',click:function(){rename(d.mac,input.value).then(function(r){if(!r.ok)throw Error(r.error||'保存失败');ui.hideModal();}).catch(function(e){ui.addNotification(null,E('p',{},e.message));});}},'保存')])],'rt-device-name-modal');input.focus();}
 function draw(data){
  // Device and computer clocks need not agree. Measure how long the producer
  // has stopped advancing using only this client's monotonic clock.
  var received=performance.now();
  if(data.timestamp&&data.timestamp!==lastTimestamp){lastTimestamp=data.timestamp;lastAdvance=received;}
  var stale=data.stale||!data.timestamp||received-lastAdvance>4000;
  if(stale)Object.keys(rows).forEach(function(mac){rows[mac].rates.forEach(function(el){if(el.textContent!=='—')el.textContent='—';});});
  var positions={},scrolls=[{el:scroll,top:scroll.scrollTop,left:scroll.scrollLeft}];
  var present={};(data.devices||[]).slice().sort(function(a,b){return (+!!a.aggregate)-(+!!b.aggregate)||todayDownloadRank(b)-todayDownloadRank(a)||a.mac.localeCompare(b.mac);}).forEach(function(d){
   if(present[d.mac])return;present[d.mac]=true;var kind=d.online?'online':'offline',c=d.online?online:offline,r=rows[d.mac];
   if(!r){var button=E('button',{class:'rt-device-name',type:'button'}),rates=[E('span',{class:'rt-device-dl','aria-label':'下载'}),E('span',{class:'rt-device-ul','aria-label':'上传'})],daily=[E('span',{class:'rt-device-dl','aria-label':'下载'}),E('span',{class:'rt-device-ul','aria-label':'上传'})];
    var cells=[E('td',{},[button]),E('td',{class:'rt-device-pair'},rates),E('td',{class:'rt-device-pair'},daily),E('td'),E('td')];
    r=rows[d.mac]={el:E('tr',{},cells),cells:cells,button:button,rates:rates,daily:daily};}
   var index=positions[kind]||0;
   if(c.body.children[index]!==r.el)c.body.insertBefore(r.el,c.body.children[index]||null);
   positions[kind]=index+1;
   var rowClass=d.online?'':'rt-device-offline',connection=d.connection||'unknown';
   if(r.el.className!==rowClass)r.el.className=rowClass;
   if(r.el.getAttribute('data-connection')!==connection)r.el.setAttribute('data-connection',connection);
   if(r.button.textContent!==d.name)r.button.textContent=d.name;
   r.button.title=d.aggregate?'LAN 外网流量 · '+(d.members||[]).length+' 台设备':d.name+'\nIP: '+(d.ip||'—')+'\nMAC: '+d.mac+'\n接口: '+(d.interface||'—');r.button.onclick=d.aggregate?null:function(){edit(d);};r.button.disabled=!!d.aggregate;
   var targets=r.rates.concat(r.daily,[r.cells[3],r.cells[4]]);
   [size(stale?null:d.rx_rate,true),size(stale?null:d.tx_rate,true),size(d.today_rx),size(d.today_tx),size(d.month_total),size(d.total)].forEach(function(v,i){if(targets[i].textContent!==v)targets[i].textContent=v;});
  });
  if(Array.isArray(data.devices))Object.keys(rows).forEach(function(mac){if(!present[mac]){rows[mac].el.remove();delete rows[mac];}});
  offlineGroup.hidden=!offline.body.children.length;var label='离线设备 · '+offline.body.children.length;if(offlineLabel.textContent!==label)offlineLabel.textContent=label;
  scrolls.forEach(function(s){if(s.el.scrollTop!==s.top)s.el.scrollTop=s.top;if(s.el.scrollLeft!==s.left)s.el.scrollLeft=s.left;});
 }
 function refresh(){if(dead||!document.documentElement.contains(root))return;var start=Date.now();busy=true;
  status().then(draw).catch(function(){draw({stale:true});}).finally(function(){busy=false;if(!dead)timer=setTimeout(refresh,Math.max(20,1000-(Date.now()-start)));});}
 timer=setTimeout(refresh,0);return function(){dead=true;clearTimeout(timer);};
}});
