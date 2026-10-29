// DOM/transport stubs only; no real network traffic.
const fs=require('fs'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'../f50nettest.js'),'utf8');
function element(tag,attrs={},children=[]){return {tag,attrs,style:{},children:Array.isArray(children)?children:[children],appendChild(v){this.children.push(v);return v;},setAttribute(k,v){this.attrs[k]=v;},replaceChildren(...v){this.children=v;},remove(){this.removed=true;}};}
(async()=>{for(let round=0;round<3;round++){
 let controls=element('div'),root=element('div'),clock=0,calls=[],fail=false,resolvePing;
 root.querySelector=()=>controls;
 const rpc={declare(spec){return spec.method==='prepare'?async()=>({token:'a'.repeat(48)}):()=>new Promise(resolve=>resolvePing=resolve);}};
 const fetch=async(url,options)=>{calls.push(options);if(fail)throw new Error('private error');assert.equal(options.method,'POST');assert(options.headers['Content-Type'].includes('token='));return {ok:true,status:200,arrayBuffer:async()=>({byteLength:8388608}),json:async()=>({bytes:8388608})};};
 const cls=new Function('rpc','baseclass','Units','E','fetch','performance','crypto',source)(rpc,{extend:x=>x},{fmtRate:v=>(v/1e6).toFixed(2)+'M/s'},element,fetch,{now:()=>clock+=1000},{getRandomValues:()=>{}});
 const dispose=cls.mount(root);assert.equal(controls.children.length,3);let [lan,domestic,foreign]=controls.children;
 let task=domestic.onclick();assert.equal(domestic.attrs['data-running'],'true');assert(lan.disabled);resolvePing({'baidu.com':{ping:'round-trip min/avg/max = 12.1/23.456/30.0 ms',https_ok:true,https:'200 0.1'}});await task;assert.equal(domestic.textContent,'Baidu 23.46 ms');assert.equal(domestic.attrs['data-running'],'false');
 task=foreign.onclick();resolvePing({'google.com':{ping:'PING www.google.com (198.18.0.31)',https_ok:true,https:'200 0.2'}});await task;assert.equal(foreign.textContent,'无法连接');
 task=foreign.onclick();resolvePing({'google.com':{ping:'round-trip min/avg/max = 32/40.567/45 ms'}});await task;assert.equal(foreign.textContent,'Google 40.57 ms');
 await lan.onclick();assert.equal(calls.filter(c=>c.headers['Content-Type'].includes('download')).length,5);assert.equal(calls.filter(c=>c.headers['Content-Type'].includes('upload')).length,5);
 assert.equal(lan.children.length,2);assert(lan.children[0].children[0].startsWith('下载 '));assert(lan.children[1].children[0].startsWith('上传 '));assert(!lan.disabled);assert.equal(lan.attrs['data-running'],'false');
 assert(!source.includes('测速完成'));assert(!source.includes('停止测速'));assert(source.includes('background:#008cba'));assert(source.includes('background:#238b45'));
 fail=true;await lan.onclick();assert.equal(lan.textContent,'无法连接');assert(!foreign.disabled);dispose();assert(controls.children.every(c=>c.removed));assert(root.children.every(c=>c.removed));
 console.log('nettest button/rate/timing round '+(round+1)+' PASS');
}})().catch(e=>{console.error(e);process.exit(1);});
