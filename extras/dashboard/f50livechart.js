'use strict';
'require baseclass';
'require mu300.common as M';

var WINDOW_MS=60000,DELAY_MS=1200;
function clamp(x,a,b){return Math.max(a,Math.min(b,x));}
/* Filtering is display-only. Counters, raw readouts and peak records are untouched. */
function prepare(times,dl,ul){
 if(!Array.isArray(times)||!Array.isArray(dl)||!Array.isArray(ul))return [];
 var rows=[];
 times.slice(-320).forEach(function(t,j){var i=Math.max(0,times.length-320)+j,a=dl[i],b=ul[i];
  if(!Number.isFinite(t)||Math.abs(t)>8640000000000000||!Number.isFinite(a)||!Number.isFinite(b)||a<0||b<0||a>1250000000||b>1250000000)return;
  if(rows.length&&t<=rows[rows.length-1].t)return;
  var last=rows[rows.length-1],dt=last?t-last.t:0,k=last&&dt<=5000?1-Math.exp(-dt/1400):1;
  rows.push({t:t,rawDl:a,rawUl:b,dl:last?last.dl+k*(a-last.dl):a,ul:last?last.ul+k*(b-last.ul):b});
 });return rows;
}
/* btop profile: each sample holds a horizontal step, then changes vertically.
 * The whole pixel-filled area moves continuously; no triangular or spline peaks. */
function curve(points){
 if(!points.length)return '';
 var d='M'+points[0].x.toFixed(2)+','+points[0].y.toFixed(2);
 for(var i=1;i<points.length;i++){
  var b=points[i];d+=' H'+b.x.toFixed(2)+' V'+b.y.toFixed(2);
 }return d;
}
return baseclass.extend({prepare:prepare,curve:curve,mount:function(root){
 var el=root.querySelector('#mud-rate-chart'),rows=[],version='',end=0,received=0,lastFrame=0,raf=0,disposed=false,panEnd=null,drag=null,lastLabel=0,geometryDirty=true,base=0,zero=100,scale=1;
 el.innerHTML='<div class="f50-rate-axis-unit"></div><div class="f50-rate-value-axis" aria-label="动态速率纵轴"></div><div class="f50-btop-label f50-btop-dl"><span></span><span></span></div><svg class="f50-rate-svg" role="img" aria-label="btop风格实时下载上传曲线；横向拖动查看过去五分钟" viewBox="0 0 900 200" preserveAspectRatio="none" style="touch-action:pan-y;cursor:grab"><defs><pattern id="f50-live-dl-pixels" width="9" height="6" patternUnits="userSpaceOnUse"><rect width="7" height="4" fill="#70c8ef"/></pattern><pattern id="f50-live-ul-pixels" width="9" height="6" patternUnits="userSpaceOnUse"><rect width="7" height="4" fill="#4dcbb6"/></pattern></defs><g class="f50-live-grid"></g><g class="f50-live-lines"><path data-area="dl" fill="url(#f50-live-dl-pixels)"/><path data-area="ul" fill="url(#f50-live-ul-pixels)"/><path data-line="dl" fill="none" stroke="#249ad1" stroke-width="1.5" vector-effect="non-scaling-stroke"/><path data-line="ul" fill="none" stroke="#159b85" stroke-width="1.5" vector-effect="non-scaling-stroke"/></g><line class="f50-live-zero" stroke="#adcbd6" x1="0" x2="900"/><line id="mud-rate-cursor" y1="12" y2="186" stroke="#385666" opacity=".6" style="display:none"/></svg><div class="f50-btop-label f50-btop-ul"><span></span><span></span></div><div class="f50-rate-time-axis"><span id="mud-rate-start"></span><span id="mud-rate-end"></span></div><button type="button" class="f50-live-return" hidden style="position:absolute;right:5px;top:1px;font-size:.65rem;padding:1px 5px;border:1px solid #b6d7e4;border-radius:5px;background:white;color:#278eaa;z-index:2">回到实时</button>';
 el.title='仿btop像素填充；图形缓冲约1秒并采用轻度平滑；速率数字、峰值和流量累计保留原始数据';
 var svg=el.querySelector('svg'),group=el.querySelector('.f50-live-lines'),reset=el.querySelector('.f50-live-return'),motion=window.matchMedia?window.matchMedia('(prefers-reduced-motion: reduce)'):null;
 function stamp(t){return new Date(t).toLocaleTimeString('zh-CN',{hour12:false});}
 function viewEnd(){return panEnd==null?end:panEnd;}
 function geometry(){
  if(!rows.length)return;
  var right=viewEnd(),visible=rows.filter(function(p){return p.t>=right-WINDOW_MS-3000&&p.t<=right+DELAY_MS+1000;});if(!visible.length)visible=[rows[rows.length-1]];
  var dlPeak=Math.max.apply(null,visible.map(function(p){return p.dl;})),ulPeak=Math.max.apply(null,visible.map(function(p){return p.ul;})),peak=Math.max(1,dlPeak,ulPeak),divisor=peak>=1048576?1048576:peak>=1024?1024:1,unit=divisor===1048576?'MB/s':divisor===1024?'KB/s':'B/s';
  var v=peak/divisor/5,power=Math.pow(10,Math.floor(Math.log10(v))),f=v/power,step=Math.max(1,(f<=1?1:f<=2?2:f<=5?5:10)*power*divisor),dlLimit=Math.max(step,Math.ceil(dlPeak/step)*step),ulLimit=Math.max(step,Math.ceil(ulPeak/step)*step);
  scale=174/(dlLimit+ulLimit);zero=12+dlLimit*scale;base=rows[0].t;
  /* Anchor the 9-unit pixel texture to absolute sample time. Moving the
   * retained history's origin must not reset its phase on every new sample. */
  var pixelPhase=-(base%600)/600*9;
  el.querySelector('#f50-live-dl-pixels').setAttribute('x',pixelPhase);
  el.querySelector('#f50-live-ul-pixels').setAttribute('x',pixelPhase);
  svg.setAttribute('data-scale',scale);svg.setAttribute('data-zero',zero);svg.setAttribute('data-window-ms',WINDOW_MS);svg.setAttribute('data-render-delay-ms',DELAY_MS);
  var grid='',axis='';
  function mark(v,up){var y=zero+(up?-1:1)*v*scale;grid+='<line x1="0" x2="900" y1="'+y+'" y2="'+y+'" stroke="#557786" opacity=".12"/>';axis+='<span class="'+(v?(up?'f50-axis-dl':'f50-axis-ul'):'')+'" style="top:'+(y/2)+'%">'+Number((v/divisor).toPrecision(2))+'</span>';}
  for(var t=dlLimit;t>step/2;t-=step)mark(t,true);mark(0,true);for(var t=step;t<=ulLimit+step/2;t+=step)mark(t,false);
  el.querySelector('.f50-live-grid').innerHTML=grid;el.querySelector('.f50-rate-value-axis').innerHTML=axis;el.querySelector('.f50-rate-axis-unit').textContent=unit;
  var line=el.querySelector('.f50-live-zero');line.setAttribute('y1',zero);line.setAttribute('y2',zero);
  ['dl','ul'].forEach(function(key){
   var segments=[],segment=[];
   rows.forEach(function(p,i){if(i&&p.t-rows[i-1].t>5000){if(segment.length)segments.push(segment);segment=[];}segment.push({x:(p.t-base)/WINDOW_MS*900,y:zero+(key==='dl'?-1:1)*p[key]*scale});});if(segment.length)segments.push(segment);
   var paths=[],areas=[];segments.forEach(function(points){var d=curve(points);paths.push(d);areas.push(d+' L'+points[points.length-1].x.toFixed(2)+','+zero+' L'+points[0].x.toFixed(2)+','+zero+' Z');});
   el.querySelector('[data-line="'+key+'"]').setAttribute('d',paths.join(' '));el.querySelector('[data-area="'+key+'"]').setAttribute('d',areas.join(' '));
  });
  el.querySelector('.f50-btop-dl span:last-child').textContent='峰值 '+M.fmtRate(Math.max.apply(null,visible.map(function(p){return p.rawDl;})));
  el.querySelector('.f50-btop-ul span:last-child').textContent='峰值 '+M.fmtRate(Math.max.apply(null,visible.map(function(p){return p.rawUl;})));
  geometryDirty=false;
 }
 function paint(now){
  raf=0;if(disposed||!rows.length||document.hidden||!document.documentElement.contains(root)){lastFrame=0;return;}
  var latest=rows[rows.length-1].t,dt=lastFrame?clamp(now-lastFrame,0,100):0;lastFrame=now;
  if(panEnd==null&&!(motion&&motion.matches)){
   var target=latest-DELAY_MS+Math.min(DELAY_MS,Math.max(0,now-received));end=Math.min(latest,end+dt+clamp((target-end)*.02,-dt*.15,dt*.15));
  }
  if(geometryDirty)geometry();
  group.setAttribute('transform','translate('+((WINDOW_MS-(viewEnd()-base))/WINDOW_MS*900).toFixed(3)+' 0)');
  if(now-lastLabel>500||lastLabel===0){el.querySelector('#mud-rate-start').textContent=stamp(viewEnd()-WINDOW_MS);el.querySelector('#mud-rate-end').textContent=stamp(viewEnd());lastLabel=now;}
  reset.hidden=panEnd==null;reset.style.display=panEnd==null?'none':'';
  if(panEnd==null&&!(motion&&motion.matches)&&now-received<2500)raf=requestAnimationFrame(paint);
 }
 function wake(){if(!raf&&!disposed)raf=requestAnimationFrame(paint);}
 function resume(){panEnd=null;lastFrame=0;geometryDirty=true;wake();}
 reset.onclick=resume;
 function point(e){if(!rows.length)return;var box=svg.getBoundingClientRect(),ts=viewEnd()-WINDOW_MS+clamp((e.clientX-box.left)/Math.max(1,box.width),0,1)*WINDOW_MS,p=rows.reduce(function(best,x){return Math.abs(x.t-ts)<Math.abs(best.t-ts)?x:best;},rows[0]);var cursor=el.querySelector('#mud-rate-cursor'),x=(p.t-viewEnd()+WINDOW_MS)/WINDOW_MS*900;cursor.style.display='';cursor.setAttribute('x1',x);cursor.setAttribute('x2',x);var detail=root.querySelector('#mud-rate-detail');if(detail){detail.textContent=stamp(p.t)+' · 下载 '+M.fmtRate(p.rawDl)+' · 上传 '+M.fmtRate(p.rawUl);detail.style.display='';}}
 svg.onpointerdown=function(e){if(e.isPrimary===false||!rows.length)return;drag={id:e.pointerId,x:e.clientX,y:e.clientY,end:viewEnd()};if(svg.setPointerCapture)svg.setPointerCapture(e.pointerId);point(e);};
 svg.onpointermove=function(e){if(drag&&drag.id===e.pointerId){var dx=e.clientX-drag.x;if(Math.abs(dx)>4&&Math.abs(dx)>Math.abs(e.clientY-drag.y)){var width=Math.max(1,svg.getBoundingClientRect().width),min=Math.min(end,rows[0].t+WINDOW_MS);panEnd=clamp(drag.end-dx/width*WINDOW_MS,min,end);if(end-panEnd<300)panEnd=null;geometryDirty=true;wake();}}point(e);};
 svg.onpointerup=svg.onpointercancel=function(){drag=null;};
 function visibility(){if(document.hidden){if(raf)cancelAnimationFrame(raf);raf=0;lastFrame=0;}else{if(rows.length)end=rows[rows.length-1].t-DELAY_MS;lastFrame=0;geometryDirty=true;wake();}}
 document.addEventListener('visibilitychange',visibility);
 return {update:function(times,dl,ul){
  if(disposed||!Array.isArray(times)||!Array.isArray(dl)||!Array.isArray(ul)||times.length>1000||dl.length>1000||ul.length>1000)return;var nextVersion=JSON.stringify([times,dl,ul]);if(nextVersion===version)return;var next=prepare(times,dl,ul);if(!next.length)return;version=nextVersion;
  var latest=next[next.length-1].t,old=rows.length?rows[rows.length-1].t:0;rows=next;
  if(latest!==old){var stalled=performance.now()-received>2500;received=performance.now();if(!end||stalled||panEnd!=null||latest-old>10000||latest<old||(motion&&motion.matches))end=latest-DELAY_MS;}
  if(panEnd!=null)panEnd=clamp(panEnd,Math.min(end,rows[0].t+WINDOW_MS),end);
  geometryDirty=true;wake();
 },dispose:function(){disposed=true;if(raf)cancelAnimationFrame(raf);raf=0;document.removeEventListener('visibilitychange',visibility);svg.onpointerdown=svg.onpointermove=svg.onpointerup=svg.onpointercancel=null;reset.onclick=null;rows=[];}};
}});
