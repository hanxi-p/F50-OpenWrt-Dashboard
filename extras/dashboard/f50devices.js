'use strict';
'require baseclass';
'require rpc';
'require ui';
'require f50units as Units';
var status=rpc.declare({object:'f50devices',method:'status',expect:{'':{}}});
var rename=rpc.declare({object:'f50devices',method:'rename',params:['mac','name'],expect:{'':{}}});
function size(n,rate){return rate?Units.fmtRate(n):Units.fmtBytes(n,2,true);}
function todayDownloadRank(d){return d.today_rx!=null&&Number.isFinite(+d.today_rx)&&+d.today_rx>=0?+d.today_rx:-1;}
return baseclass.extend({mount:function(root){
 var section=E('section',{class:'mud-sec f50-devices'},[E('h3',{},'设备流量统计')]);
 var panels=E('div',{class:'f50-device-panels'});section.appendChild(panels);
 var anchor=root.querySelector('.mud-body > .mud-sec');anchor.insertAdjacentElement('afterend',section);
 section.appendChild(E('style',{},`
 .container:has(.f50-home){max-width:1800px!important}
 .f50-home{max-width:1800px!important;width:100%;box-sizing:border-box}
 .f50-devices{min-width:0;--f50-device-total:#8970b3}
 .f50-device-panels{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,680px),1fr));gap:14px}
 .f50-device-panel{--f50-device-accent:color-mix(in srgb,var(--f50-dl,#249ad1) 65%,var(--f50-ul,#159b85));min-width:0;border:1px solid var(--hairline,var(--border,#e3e6ea));border-top:2px solid var(--f50-device-accent);border-radius:var(--radius-base,.5rem);overflow:hidden;background:var(--surface,var(--background-alt,var(--background,#fff)));color:var(--text,#222)}
 .f50-device-panel.wifi5{--f50-device-accent:var(--f50-dl,#249ad1)}
 .f50-device-panel.wired{--f50-device-accent:var(--f50-ul,#159b85)}
 .modal.f50-device-name-modal{box-sizing:border-box;width:min(320px,calc(100vw - 40px))!important;min-width:0!important;max-width:calc(100vw - 40px)!important}
 .modal.f50-device-name-modal p{overflow-wrap:anywhere}
 .f50-device-scroll{max-height:390px;overflow:auto;overflow-anchor:none;scrollbar-gutter:stable}
 .f50-devices table{table-layout:fixed;border-collapse:separate;border-spacing:0;width:100%;min-width:620px;font-size:12px;margin:0}
 .f50-devices th,.f50-devices td{box-sizing:border-box;height:54px;padding:8px 10px;white-space:nowrap;text-align:center;vertical-align:middle;line-height:1.4;font-variant-numeric:tabular-nums;border-bottom:1px solid var(--hairline,var(--border,#e3e6ea))}
 .f50-devices th:first-child,.f50-devices td:first-child{text-align:left;width:26%}
 .f50-devices th:nth-child(2),.f50-devices td:nth-child(2),.f50-devices th:nth-child(3),.f50-devices td:nth-child(3){width:22%}
 .f50-devices th{position:sticky;top:0;z-index:1;height:40px;background:var(--surface-sunken,var(--background-alt,#f5f7fa));font-weight:600;text-align:center}
 .f50-devices th:first-child{text-align:left}
 .f50-devices th span{display:inline;white-space:nowrap}
 .f50-devices tbody tr:nth-child(even){background:color-mix(in srgb,var(--surface-sunken,rgba(127,127,127,.06)) 50%,var(--surface,var(--background,#fff)))}
 .f50-devices tbody tr:hover{background:var(--brand-subtle,var(--hover-faint,rgba(36,154,209,.08)))}
 .f50-device-pair>span{display:block;line-height:1.35}
 .f50-device-pair>span+span{margin-top:2px}
 .f50-devices .f50-device-dl{color:var(--f50-dl,#249ad1)}
 .f50-devices .f50-device-ul{color:var(--f50-ul,#159b85)}
 .f50-devices td:nth-child(4),.f50-devices th:nth-child(4),.f50-devices th:nth-child(5){color:var(--f50-device-total)}
 .f50-devices td:nth-child(4),.f50-devices td:nth-child(5){font-weight:400}
 .f50-devices td:nth-child(5){color:var(--f50-device-total)}
 .f50-device-name{display:block;width:100%;white-space:normal;overflow-wrap:anywhere;border:0!important;background:transparent!important;color:inherit!important;padding:0!important;text-align:left;font:inherit;font-size:.92em;line-height:1.35;font-weight:600;cursor:pointer}
 .f50-device-offline{opacity:.65}.f50-device-offline .f50-device-name:before{content:'○ ';font-weight:400}
 @media(min-width:1500px){.f50-devices table{font-size:13px}.f50-devices td,.f50-devices th{padding:10px 14px}}
 @media(max-width:767px){
  .f50-device-panels{grid-template-columns:minmax(0,1fr);gap:8px}
  .f50-device-scroll{scrollbar-gutter:auto}
  .f50-devices table{min-width:0;width:100%;font-size:10px;line-height:1.3}
  .f50-devices th,.f50-devices td{height:50px;padding:6px 4px;white-space:nowrap;line-height:1.3;vertical-align:middle}
  .f50-devices th{height:36px;font-size:9px}
  .f50-devices th:first-child,.f50-devices td:first-child{width:28%;padding-left:8px}
  .f50-devices th:nth-child(2),.f50-devices td:nth-child(2){width:22%}
  .f50-devices th:nth-child(3),.f50-devices td:nth-child(3){width:20%}
  .f50-devices th:nth-child(4),.f50-devices td:nth-child(4),.f50-devices th:nth-child(5),.f50-devices td:nth-child(5){padding-left:2px;padding-right:2px}
  .f50-devices td:nth-child(4),.f50-devices td:nth-child(5){font-size:9px}
  .f50-device-name{font-size:9px}
 }
 @media(max-width:359px){
  .f50-devices table{font-size:9px}
  .f50-devices th{font-size:8.5px}
  .f50-devices th,.f50-devices td{padding:6px 3px}
  .f50-device-name{font-size:8px}
 }
 @media(orientation:landscape) and (max-height:600px) and (max-width:1100px) and (pointer:coarse){
  .f50-device-panels{grid-template-columns:minmax(0,1fr)}
  .f50-device-scroll{scrollbar-gutter:auto}
  .f50-devices table{min-width:0;width:100%;font-size:11px;line-height:1.2}
  .f50-devices th,.f50-devices td{height:52px;padding:6px 8px;white-space:nowrap;vertical-align:middle}
  .f50-devices th{height:36px;white-space:nowrap}
  .f50-devices th:first-child,.f50-devices td:first-child{padding-left:12px}
  .f50-devices th:first-child,.f50-devices td:first-child{width:26%}
  .f50-devices th:nth-child(2),.f50-devices td:nth-child(2),.f50-devices th:nth-child(3),.f50-devices td:nth-child(3){width:22%}
  .f50-devices td:nth-child(4),.f50-devices td:nth-child(5){font-size:11px}
  .f50-device-name{font-size:10px;line-height:1.25;white-space:normal;overflow:visible;text-overflow:clip;overflow-wrap:anywhere}
 }
 `));
 var cards={},rows={},dead=false,timer,busy=false,lastTimestamp=null,lastAdvance=0;
 function card(kind){if(cards[kind])return cards[kind];var title={wifi24:'无线连接设备 · 2.4 GHz',wifi5:'无线连接设备 · 5 GHz',wired:'USB / 有线设备',unknown:'待识别接口 · 保留历史设备'}[kind];
  var body=E('tbody'),el=E('article',{class:'f50-device-panel '+kind,'aria-label':title},[E('div',{class:'f50-device-scroll'},[E('table',{},[E('thead',{},[E('tr',{},['设备名称','实时速率','今日流量','本月累计','总累计'].map(function(t){return E('th',{},[E('span',{},t.length===3?t.slice(0,1):t.slice(0,2)),E('span',{},t.length===3?t.slice(1):t.slice(2))]);}))]),body])])]);
  panels.appendChild(el);cards[kind]={el:el,body:body};return cards[kind];}
 function edit(d){var input=E('input',{type:'text',value:d.name,style:'width:100%;min-width:0;box-sizing:border-box',maxlength:96});
  ui.showModal('设备名称',[E('p',{},d.mac+' · '+d.ip),input,E('p',{},'留空恢复主机名；名称按 MAC 保存。'),E('div',{class:'right'},[
   E('button',{class:'btn',click:ui.hideModal},'取消'),E('button',{class:'btn cbi-button-positive',click:function(){rename(d.mac,input.value).then(function(r){if(!r.ok)throw Error(r.error||'保存失败');ui.hideModal();}).catch(function(e){ui.addNotification(null,E('p',{},e.message));});}},'保存')])],'f50-device-name-modal');input.focus();}
 function draw(data){
  // Device and computer clocks need not agree. Measure how long the producer
  // has stopped advancing using only this client's monotonic clock.
  var received=performance.now();
  if(data.timestamp&&data.timestamp!==lastTimestamp){lastTimestamp=data.timestamp;lastAdvance=received;}
  var stale=data.stale||!data.timestamp||received-lastAdvance>4000;
  if(stale)Object.keys(rows).forEach(function(mac){rows[mac].rates.forEach(function(el){el.textContent='—';});});
  var positions={},scrolls=Object.keys(cards).map(function(k){var el=cards[k].el.querySelector('.f50-device-scroll');return {el:el,top:el.scrollTop,left:el.scrollLeft};});
  var present={};(data.devices||[]).slice().sort(function(a,b){return todayDownloadRank(b)-todayDownloadRank(a)||a.mac.localeCompare(b.mac);}).forEach(function(d){
   if(present[d.mac])return;present[d.mac]=true;var kind=/^(wifi24|wifi5|wired)$/.test(d.connection)?d.connection:'unknown';var c=card(kind),r=rows[d.mac];
   if(!r){var button=E('button',{class:'f50-device-name',type:'button'}),rates=[E('span',{class:'f50-device-dl','aria-label':'下载'}),E('span',{class:'f50-device-ul','aria-label':'上传'})],daily=[E('span',{class:'f50-device-dl','aria-label':'下载'}),E('span',{class:'f50-device-ul','aria-label':'上传'})];
    var cells=[E('td',{},[button]),E('td',{class:'f50-device-pair'},rates),E('td',{class:'f50-device-pair'},daily),E('td'),E('td')];
    r=rows[d.mac]={el:E('tr',{},cells),cells:cells,button:button,rates:rates,daily:daily};}
   var index=positions[kind]||0;
   if(c.body.children[index]!==r.el)c.body.insertBefore(r.el,c.body.children[index]||null);
   positions[kind]=index+1;
   r.el.className=d.online?'':'f50-device-offline';r.button.textContent=d.name;
   r.button.title=d.name+'\nIP: '+(d.ip||'—')+'\nMAC: '+d.mac+'\n接口: '+(d.interface||'—');r.button.onclick=function(){edit(d);};
   var targets=r.rates.concat(r.daily,[r.cells[3],r.cells[4]]);
   [size(stale?null:d.rx_rate,true),size(stale?null:d.tx_rate,true),size(d.today_rx),size(d.today_tx),size(d.month_total),size(d.total)].forEach(function(v,i){if(targets[i].textContent!==v)targets[i].textContent=v;});
  });
  Object.keys(cards).forEach(function(k){cards[k].el.hidden=!cards[k].body.children.length;});
  scrolls.forEach(function(s){s.el.scrollTop=s.top;s.el.scrollLeft=s.left;});
 }
 function refresh(){if(dead||!document.documentElement.contains(root))return;var start=Date.now();busy=true;
  status().then(draw).catch(function(){draw({stale:true});}).finally(function(){busy=false;if(!dead)timer=setTimeout(refresh,Math.max(20,1000-(Date.now()-start)));});}
 timer=setTimeout(refresh,0);return function(){dead=true;clearTimeout(timer);};
}});
