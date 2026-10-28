const fs=require('fs'),assert=require('assert/strict');
class Class {static extend(methods){class Derived extends this{}Object.assign(Derived.prototype,methods);return Derived;}static isSubclass(ctor){return ctor.prototype instanceof this;}}
const Units=new (new Function('baseclass',fs.readFileSync(__dirname+'/../extras/dashboard/f50units.js','utf8'))(Class))();
const ctor=new Function('baseclass','M','Units',fs.readFileSync(__dirname+'/../extras/dashboard/f50livechart.js','utf8'))(Class,{},Units);assert.ok(Class.isSubclass(ctor));const chart=new ctor();
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-5,`${a} != ${b}`);
for(let round=0;round<3;round++)for(const width of [280,320,768,1180,1440,1800,2560])for(const height of [200,230]){
 let base=1793120000000+round*1000,zero=103;
 let p=chart.texture(width,height,base,zero);
 near(p.width*width/900,6);near(p.height*height/200,5);near(p.blockWidth*width/900,4);near(p.blockHeight*height/200,3);
 near((zero-p.dlY)*height/200,3);near(p.ulY,zero);
 let q=chart.texture(width,height,base+1000,zero),dx=1000/60000*900;
 let periods=(q.x-p.x+dx)/p.width;near(periods,Math.round(periods));
}
assert.equal(chart.curve([{x:0,y:10},{x:10,y:15}]),'M0.00,10.00 H10.00 V15.00');
let width=1500,height=230,observer,frames=new Map(),id=0;
class Node{constructor(){this.attrs={};this.style={};this.nodes=new Map();this.children=[];this.parentNode=null;}querySelector(s){if(!this.nodes.has(s))this.nodes.set(s,new Node());return this.nodes.get(s);}setAttribute(k,v){this.attrs[k]=v;}removeAttribute(k){delete this.attrs[k];}appendChild(n){n.parentNode=this;this.children.push(n);return n;}removeChild(n){this.children.splice(this.children.indexOf(n),1);n.parentNode=null;}getBoundingClientRect(){return this.box||{left:0,top:0,width,height};}}
const root=new Node(),el=root.querySelector('#mud-rate-chart');
const docEvents={};
const doc={body:new Node(),hidden:false,documentElement:{contains:()=>true},addEventListener(k,fn){docEvents[k]=fn;},removeEventListener(k){delete docEvents[k];}};
const win={innerWidth:1600,innerHeight:240,matchMedia:()=>({matches:false}),addEventListener(){},removeEventListener(){}};
class Observer{constructor(fn){this.fn=fn;observer=this;}observe(){this.observed=true;}disconnect(){this.disconnected=true;}}
const mountedCtor=new Function('baseclass','M','Units','window','document','ResizeObserver','requestAnimationFrame','cancelAnimationFrame','performance',fs.readFileSync(__dirname+'/../extras/dashboard/f50livechart.js','utf8'))(Class,{fmtRate:n=>String(n)},Units,win,doc,Observer,fn=>{frames.set(++id,fn);return id;},n=>frames.delete(n),{now:()=>1000});
el.setAttribute('title','仿btop像素填充');
const live=new mountedCtor().mount(root);live.update([1793120000000,1793120001000,1793120002000],[1024,2048,4096],[512,1024,2048]);
function frame(){let [key,fn]=frames.entries().next().value;frames.delete(key);fn(1000);}
frame();near(el.querySelector('#f50-live-dl-pixels').attrs.width*width/900,6);assert.ok(observer.observed);
const svg=el.querySelector('svg'),tip=root.querySelector('#mud-rate-detail');tip.box={left:0,top:0,width:200,height:80};
assert.equal(el.attrs.title,undefined);assert.equal(svg.attrs['aria-label'],'实时下载与上传速率曲线');assert.equal(tip.parentNode,doc.body);
svg.onpointermove({clientX:1499,clientY:229,pointerType:'mouse'});assert.equal(tip.style.display,'block');
assert.equal(tip.querySelector('[data-tip="dl"]').textContent,Units.fmtRate(2048),'tooltip shows raw selected speed, not smoothed geometry');assert.equal(tip.querySelector('[data-tip="ul"]').textContent,Units.fmtRate(1024));
assert.ok(parseFloat(tip.style.left)<1499&&parseFloat(tip.style.top)<229,'tooltip flips near viewport edges');assert.ok(parseFloat(tip.style.left)>=8&&parseFloat(tip.style.top)>=8);
svg.onpointerleave({pointerType:'mouse'});assert.equal(tip.style.display,'none');assert.equal(el.querySelector('#mud-rate-cursor').style.display,'none');
width=320;height=200;observer.fn();frame();near(el.querySelector('#f50-live-dl-pixels').attrs.width*width/900,6);near(el.querySelector('#f50-live-ul-pixels').querySelector('rect').attrs.height*height/200,3);
svg.onpointermove({clientX:200,clientY:180,pointerType:'touch',pointerId:1});assert.equal(tip.style.display,'none','touch cannot hover without pressing');
const times=Array.from({length:61},(_,i)=>1793120000000+i*1000);live.update(times,times.map((_,i)=>i*1024),times.map((_,i)=>i*512));frame();
const transform=el.querySelector('.f50-live-lines').attrs.transform;
svg.onpointerdown({clientX:64,clientY:180,pointerType:'touch',pointerId:1});assert.equal(tip.style.display,'block');assert.equal(tip.querySelector('[data-tip="dl"]').textContent,Units.fmtRate(11*1024));
assert.ok(parseFloat(tip.style.top)+80<180,'mobile tooltip stays above finger');
svg.onpointermove({clientX:256,clientY:180,pointerType:'touch',pointerId:2});assert.equal(tip.querySelector('[data-tip="dl"]').textContent,Units.fmtRate(11*1024),'unrelated contact ignored');
svg.onpointermove({clientX:256,clientY:180,pointerType:'touch',pointerId:1});frame();assert.equal(tip.querySelector('[data-tip="dl"]').textContent,Units.fmtRate(47*1024));assert.equal(el.querySelector('.f50-live-lines').attrs.transform,transform,'drag moves cursor without panning the chart');
svg.onpointerup({pointerType:'touch',pointerId:1});svg.onpointerleave({pointerType:'touch'});assert.equal(tip.style.display,'block','released touch retains selected speed');
svg.onpointermove({clientX:64,clientY:180,pointerType:'touch',pointerId:1});assert.equal(tip.querySelector('[data-tip="dl"]').textContent,Units.fmtRate(47*1024),'released contact cannot scrub');
el.contains=n=>n===svg;docEvents.pointerdown({target:new Node()});assert.equal(tip.style.display,'none','outside tap dismisses selection');frame();
live.dispose();assert.ok(observer.disconnected);assert.equal(frames.size,0);assert.equal(tip.parentNode,null);assert.equal(svg.onpointerleave,null);
console.log('PASS 42 viewport/height cases: fixed 4x3px blocks, 2px gaps, mirrored zero, absolute-time phase, step curve, LuCI constructor');
console.log('PASS mounted chart resize recalculates texture and dispose clears observer/animation');
console.log('PASS mouse hover tooltip and touch-only press/drag cursor, raw historical speeds, frozen chart during scrub, finger-aware positioning, retained selection, outside-tap dismissal and cleanup');
