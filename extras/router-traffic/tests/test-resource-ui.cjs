const fs=require('node:fs'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
class Base{static extend(m){class X{}Object.assign(X.prototype,m);return X;}}
async function round(){
 const {document}=parseHTML('<html><body><div class="rt-root"><div class="mud-body"></div></div></body></html>');
 const root=document.querySelector('.rt-root');let pending=[],now=0;
 function E(tag,a={},children=[]){const n=document.createElement(tag);for(const [k,v] of Object.entries(a))n.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)n.append(typeof c==='string'?document.createTextNode(c):c);return n;}
 let data={timestamp:1000,cpu:40,cores:[{name:'cpu0',usage:20},{name:'cpu1',usage:60}],memory:{total:1000,available:750},temperatures:[{name:'cpu-thermal',celsius:45}],storage:{total:1000,used:400,available:600}};
 const Class=new Function('baseclass','rpc','Units','E','document','performance','setTimeout','clearTimeout',fs.readFileSync(__dirname+'/../ui/resources.js','utf8'))(Base,{declare:()=>()=>Promise.resolve(data)},{fmtBytes:v=>String(v)},E,document,{now:()=>now},fn=>(pending.push(fn),pending.length),()=>{});
 const dispose=new Class().mount(root);async function tick(){pending.shift()();for(let i=0;i<10;i++)await Promise.resolve();}
 await tick();const cards=[...root.querySelectorAll('.rt-kpis>.rt-kpi')];assert.equal(cards.length,3);assert.equal(cards[0].firstChild.textContent,'40%');assert.equal(cards[1].firstChild.textContent,'25%');assert.equal(cards[2].firstChild.textContent,'45.0°C');
 const cores=root.querySelector('.rt-core-details');assert.equal(cores.hidden,false);assert(cards[0].contains(cores));assert.equal(cards[0].getAttribute('aria-expanded'),null);assert(cores.textContent.includes('CPU0 20%'));assert(cores.textContent.includes('CPU1 60%'));const details=root.querySelector('details');details.setAttribute('open','');
 for(let i=0;i<20;i++){data.timestamp++;now+=1000;await tick();assert.equal(root.querySelector('.rt-kpis').firstChild,cards[0]);assert.equal(cores.hidden,false);assert(details.hasAttribute('open'));}
 now+=5000;await tick();assert.equal(cards[0].firstChild.textContent,'—');dispose();
}
(async()=>{for(let i=0;i<3;i++)await round();console.log('PASS resources three rounds: F50 three-card row, actual readings, storage disclosure, always-visible CPU cores, stable nodes and stale values');})().catch(e=>{console.error(e);process.exitCode=1;});
