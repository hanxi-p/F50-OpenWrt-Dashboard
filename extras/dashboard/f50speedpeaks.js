'use strict';
'require baseclass';
'require mu300.common as M';
function series(data) {
 var map={},end=Date.parse(data.today+'T00:00:00+08:00');
 (data.days||[]).forEach(function(d){if(/^\d{4}-\d{2}-\d{2}$/.test(d.date))map[d.date]=d;});
 return Array.from({length:30},function(_,i){var date=new Date(end-(29-i)*86400000+28800000).toISOString().slice(0,10);return map[date]||{date:date,download:null,upload:null};});
}
return baseclass.extend({mount:function(root){
 var buttons=[root.querySelector('#mud-peak-download'),root.querySelector('#mud-peak-upload')],title=root.querySelector('#mud-peak-title'),controls=buttons.concat(title?[title]:[]),panel=root.querySelector('#mud-peaks-panel'),latest=null,open=false,lastVersion='',lastWidth=0;
 function draw(){
  if(!latest)return;
  lastWidth=panel.clientWidth||350;
  var rate=root.querySelector('#mud-rate-chart'),height=Math.max(140,(rate&&rate.clientHeight||200)-40),rows=series(latest),width=1320,top=24,bottom=height-24,step=(width-24)/29;
  function nice(v){var power=Math.pow(10,Math.floor(Math.log10(Math.max(1,v)))),n=v/power;return (n<=1?1:n<=2?2:n<=5?5:10)*power;}
  var rawDl=Math.max.apply(null,[1].concat(rows.map(function(d){return d.download||0;}))),rawUl=Math.max.apply(null,[1].concat(rows.map(function(d){return d.upload||0;}))),maximum=Math.max(rawDl,rawUl),divisor=maximum>=1048576?1048576:maximum>=1024?1024:1,unit=divisor===1048576?'MB/s':divisor===1024?'KB/s':'B/s',dlMax=nice(Math.max(rawDl,maximum/5)/divisor)*divisor,ulMax=nice(Math.max(rawUl,maximum/5)/divisor)*divisor,scale=(bottom-top)/(dlMax+ulMax),zero=top+dlMax*scale;
  var svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 '+width+' '+height+'" role="img" aria-label="最近30天每日峰值：下载在上，上传在下" data-zero="'+zero+'" data-scale="'+scale+'" style="display:block;width:1320px;height:'+height+'px">';
  var ticks=[{y:zero,value:0,color:'#74858c'}];
  ['download','upload'].forEach(function(key){var max=key==='download'?dlMax:ulMax;for(var i=1;i<=2;i++)ticks.push({y:zero+(key==='download'?-1:1)*max*i/2*scale,value:max*i/2/divisor,color:key==='download'?'#249ad1':'#159b85'});});
  ticks.forEach(function(t){svg+='<line x1="12" x2="'+(width-12)+'" y1="'+t.y+'" y2="'+t.y+'" stroke="#e5eef2"/>';});
  svg+='<line x1="12" x2="'+(width-12)+'" y1="'+zero+'" y2="'+zero+'" stroke="#adcbd6" stroke-width="1.2"/>';
  ['download','upload'].forEach(function(key){var color=key==='download'?'#249ad1':'#159b85',segments=[],segment=[];
   rows.forEach(function(d,i){if(d[key]==null){if(segment.length)segments.push(segment);segment=[];}else segment.push({x:12+i*step,y:zero+(key==='download'?-1:1)*d[key]*scale,d:d});});if(segment.length)segments.push(segment);
   segments.forEach(function(seg){var line=seg.map(function(p){return p.x.toFixed(1)+','+p.y.toFixed(1);}).join(' '),area=seg[0].x+','+zero+' '+line+' '+seg[seg.length-1].x+','+zero;
    svg+='<polygon data-series="'+key+'" points="'+area+'" fill="'+(key==='download'?'#dff3fa':'#dcf4ee')+'"/><polyline data-series="'+key+'" points="'+line+'" fill="none" stroke="'+color+'" stroke-width="3" stroke-linejoin="round"/>';
    seg.forEach(function(p){var label=key==='download'?'下载':'上传',v=M.fmtRate(p.d[key]);svg+='<circle data-series="'+key+'" cx="'+p.x+'" cy="'+p.y+'" r="2.5" fill="'+color+'"><title>'+p.d.date+' '+label+' '+v+'</title></circle>';});});
  });
  [0,5,10,15,20,25,29].forEach(function(i){svg+='<text x="'+(12+i*step)+'" y="'+(height-4)+'" text-anchor="'+(i===0?'start':i===29?'end':'middle')+'" font-size="10" fill="#74858c">'+rows[i].date.slice(5)+'</text>';});svg+='</svg>';
  var axis='<svg data-peak-axis="right" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 '+height+'" aria-label="速率纵轴 '+unit+'" style="display:block;width:64px;height:'+height+'px;flex:0 0 64px;background:white"><text x="12" y="10" font-size="10" fill="#74858c">'+unit+'</text><line x1="5" x2="5" y1="'+top+'" y2="'+bottom+'" stroke="#adcbd6"/>';
  ticks.forEach(function(t){axis+='<line x1="5" x2="10" y1="'+t.y+'" y2="'+t.y+'" stroke="'+t.color+'"/><text data-axis-value="'+t.value+'" x="14" y="'+t.y+'" dominant-baseline="middle" font-size="11" fill="'+t.color+'">'+Number(t.value.toFixed(2))+'</text>';});axis+='</svg>';
  panel.innerHTML='<div class="f50-peak-legend"><span>下载</span><span>上传</span></div><div style="display:flex;align-items:flex-start;max-width:100%;overflow:hidden"><div class="f50-peak-scroll" style="min-width:0;flex:1">'+svg+'</div>'+axis+'</div>';
  panel.querySelector('.f50-peak-scroll').scrollLeft=width;
 }
 function toggle(){open=!open;panel.hidden=!open;controls.forEach(function(b){b.setAttribute('aria-expanded',String(open));});if(open)draw();}
 controls.forEach(function(b){b.onclick=toggle;});
 var observer=typeof ResizeObserver==='function'?new ResizeObserver(function(){if(open&&panel.clientWidth&&Math.abs(panel.clientWidth-lastWidth)>1)draw();}):null;
 if(observer)observer.observe(panel);
 return {update:function(data){
  if(!data||!/^\d{4}-\d{2}-\d{2}$/.test(data.today)||!Number.isFinite(Date.parse(data.today+'T00:00:00+08:00'))||!Array.isArray(data.days))return;
  data=Object.assign({},data,{days:data.days.filter(function(d){return d&&/^\d{4}-\d{2}-\d{2}$/.test(d.date)&&['download','upload'].every(function(k){return Number.isFinite(d[k])&&d[k]>=0&&d[k]<=1250000000;});})});
  latest=data;var today=data.days.find(function(d){return d.date===data.today;});
  buttons.forEach(function(b,i){var value=today&&today[i?'upload':'download'];b.querySelector('b').textContent=value==null?'—':M.fmtRate(value);});
  var version=JSON.stringify(data.days);if(open&&version!==lastVersion)draw();lastVersion=version;
 },dispose:function(){if(observer)observer.disconnect();controls.forEach(function(b){b.onclick=null;});latest=null;}};
}});
