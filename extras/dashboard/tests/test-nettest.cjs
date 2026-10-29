// DOM/transport stubs only; no real network traffic.
const fs=require('fs'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'../f50nettest.js'),'utf8');
function element(tag,attrs={},children=[]){return {tag,attrs,style:{},children:Array.isArray(children)?children:[children],appendChild(v){this.children.push(v);return v;},insertBefore(v){this.children.push(v);return v;},setAttribute(k,v){this.attrs[k]=v;},replaceChildren(...v){this.children=v;},remove(){this.removed=true;}};}
const text=e=>typeof e==='string'?e:e.children.map(text).join('');
(async()=>{for(let round=0;round<3;round++){
 let controls=element('div'),root=element('div'),clock=0,calls=[],fail=false,resolvePing,prepareCalls=0,finishCalls=0,pingCalls=0,timerId=0,timers=new Map();root.querySelector=()=>controls;
 const rpc={declare(spec){if(spec.method==='prepare')return async()=>{prepareCalls++;return {token:'a'.repeat(48)};};if(spec.method==='finish')return async()=>{finishCalls++;return {ok:true};};return ()=>{pingCalls++;return new Promise(resolve=>resolvePing=resolve);};}};
 const fetch=async(url,options)=>{calls.push(options);if(fail)throw new Error('private error');assert.equal(options.method,'POST');return {ok:true,status:200,arrayBuffer:async()=>({byteLength:8388608}),json:async()=>({bytes:8388608})};};
 const cls=new Function('rpc','baseclass','Units','E','fetch','performance','crypto','setTimeout','clearTimeout',source)(rpc,{extend:x=>x},{fmtRate:v=>(v/1e6).toFixed(2)+'M/s'},element,fetch,{now:()=>clock+=1000},{getRandomValues:()=>{}},(fn,ms)=>{let id=++timerId;timers.set(id,{fn,ms});return id;},id=>timers.delete(id));
 const dispose=cls.mount(root);assert.equal(controls.children.length,2);let [domestic,foreign]=controls.children;
 let task=domestic.onclick();assert.equal(domestic.attrs['data-running'],'true');assert.deepEqual(domestic.children.map(text),['国内 Baidu','Ping —']);resolvePing({'baidu.com':{ping:'round-trip min/avg/max = 12/23.456/30 ms'}});await task;
 assert.deepEqual(domestic.children.map(text),['国内 Baidu','Ping 23.46ms']);assert.equal(domestic.children[1].attrs.class,'f50-test-result');assert.equal(domestic.attrs['data-results'],'true');
 await domestic.onclick();assert.equal(text(domestic),'国内延迟');assert.equal(domestic.attrs['data-results'],'false');assert.equal(pingCalls,1,'reset does not trigger another test');
 task=domestic.onclick();resolvePing({'baidu.com':{ping:'round-trip min/avg/max = 1/2/3 ms'}});await task;assert.equal(text(domestic.children[1]),'Ping 2.00ms');
 task=foreign.onclick();resolvePing({'google.com':{https_ok:false,https_ms:0}} );await task;assert.deepEqual(foreign.children.map(text),['国外 Google','无法连接']);
 await foreign.onclick();assert.equal(text(foreign),'国外延迟');task=foreign.onclick();resolvePing({'google.com':{https_ok:true,https_ms:40.567}});await task;assert.equal(text(foreign.children[1]),'Https 40.57ms');
 assert.equal(prepareCalls,0);assert.equal(finishCalls,0);assert.equal(calls.length,0);
 await domestic.onclick();task=domestic.onclick();let timeout=[...timers.values()].find(t=>t.ms===12000);assert(timeout);timeout.fn();await task;assert(!domestic.disabled);assert.equal(text(domestic.children[1]),'无法连接');await domestic.onclick();assert.equal(text(domestic),'国内延迟');
 assert(!source.includes('测速完成'));assert(!source.includes('停止测速'));dispose();assert(controls.children.every(c=>c.removed));
 console.log('nettest two-line/repeat/reset/timeout round '+(round+1)+' PASS');
}})().catch(e=>{console.error(e);process.exit(1);});
