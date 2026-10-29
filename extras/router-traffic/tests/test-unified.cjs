/* Unified owner: real device/resource modules, no browser or router required. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
const dir=path.join(__dirname,'..');class Base{static extend(m){class X extends this{}Object.assign(X.prototype,m);return X;}}
async function scenario(){
 const {document,window}=parseHTML('<html><body></body></html>');let timers=new Map(),seq=0,reads=0,updates=0,disposed=0;
 function E(tag,a={},children=[]){const n=document.createElement(tag);for(const[k,v]of Object.entries(a))typeof v==='function'?n.addEventListener(k,v):n.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)n.append(typeof c==='string'?document.createTextNode(c):c);return n;}
 const timeout=fn=>{timers.set(++seq,fn);return seq;},clear=n=>timers.delete(n);
 const Units={fmtRate:n=>n==null?'—':String(n),fmtBytes:n=>String(n)};
 const rpc={declare:d=>()=>Promise.resolve(d.method==='devices'?{timestamp:1000,devices:[]}:{timestamp:1000,cpu:20,cores:[],memory:{},temperatures:[],storage:{}})};
 function load(file,scope){return new Function(...Object.keys(scope),fs.readFileSync(path.join(dir,file),'utf8'))(...Object.values(scope));}
 const scope={baseclass:Base,rpc,ui:{},Units,E,document,performance:{now:()=>1000},setTimeout:timeout,clearTimeout:clear};
 const Devices=new(load('ui/devices.js',scope))(),Resources=new(load('ui/resources.js',scope))();
 const raw=JSON.stringify({timestamp:1000,date:'2026-10-30',rx_rate:0,tx_rate:0,daily_rx:10,daily_tx:20,month_rx:30,month_tx:40,total_rx:50,total_tx:60});
 const File={read:p=>{reads++;return Promise.resolve(p.endsWith('status.json')?raw:p.endsWith('.css')?'/* stylesheet */':'');}};
 const View=load('wan/view.js',{baseclass:Base,fs:File,L:{resolveDefault:(p,v)=>p.catch(()=>v)},F50LiveChart:{mount:()=>({update:()=>updates++,dispose:()=>disposed++})},Units,Devices,Resources,E,document,window,setTimeout:timeout,clearTimeout:clear});
 const view=new View(),root=view.render(await view.load());document.body.append(root);
 const sections=[...root.querySelector('.mud-body').children];assert.equal(sections.length,4);assert(sections[0].querySelector('#mud-rate-chart'));assert(sections[1].classList.contains('rt-totals-section'));assert(sections[2].classList.contains('rt-devices'));assert(sections[3].classList.contains('rt-load-section'));
 assert.equal(root.querySelectorAll('.mud-card').length,1);assert.equal(root.querySelectorAll('.rt-kpis>.rt-kpi').length,3);
 const values=['f50-today-rx','f50-today-tx','f50-month-total','f50-total'].map(id=>root.querySelector('#'+id));assert.deepEqual(values.map(x=>x.textContent),['10','20','70','110']);
 const before=reads;for(let i=0;i<60;i++){assert.equal(await view.load(),null);assert.equal(view.render(null),null);assert.equal(root.querySelectorAll('[data-f50-inline-style]').length,1);assert.equal(root.querySelectorAll('.rt-devices').length,1);}assert.equal(reads,before);
 for(let i=0;i<10;i++)view.update({...JSON.parse(raw),timestamp:1001+i,total_rx:100+i});assert.equal(root.querySelector('#f50-total'),values[3]);assert(updates>=11);
 root.remove();const next=view.render(await view.load());document.body.append(next);assert.notEqual(next,root);view.dispose();next.remove();assert.equal(disposed,2);assert.equal(timers.size,0);
 const Shim=load('ui/status.js',{baseclass:Base}),shim=new Shim();assert.equal(await shim.load(),null);assert.equal(shim.render(),null);
}
(async()=>{for(let i=0;i<3;i++)await scenario();console.log('PASS three rounds: four ordered modules, one F50 card, all four totals, 180 stable polls, real device/resource mounts, cleanup, no duplicate panel');})().catch(e=>{console.error(e);process.exit(1);});
