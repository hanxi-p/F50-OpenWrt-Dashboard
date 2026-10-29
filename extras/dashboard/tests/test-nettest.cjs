// DOM and transport stubs only; no browser, Wi-Fi or public network traffic.
const fs=require('fs'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'../f50nettest.js'),'utf8');
function element(tag,attrs={},children=[]){return {tag,attrs,style:{},children:Array.isArray(children)?children:[children],appendChild(v){this.children.push(v);return v;},insertBefore(v){this.children.push(v);return v;},replaceChildren(...v){this.children=v;},remove(){this.removed=true;}};}
(async()=>{for(let round=0;round<3;round++){
 let controls=element('div'),clock=0,calls=[],fail=false;
 const rpc={declare(spec){return async target=>spec.method==='prepare'?{token:'a'.repeat(48)}:target==='domestic'?{'baidu.com':{ping:'round-trip min/avg/max = 12.1/23.456/30.0 ms\n0% packet loss',https_ok:true,https:'200 0.12345'}}:{'google.com':{ping:'PING www.google.com (198.18.0.31)\nping: sendto: Operation not permitted',https_ok:true,https:'200 0.23456'}};}};
 const fetch=async(url,options)=>{calls.push(options);if(fail)throw new Error('transport failed');assert.equal(options.method,'POST');assert(options.headers['Content-Type'].includes('token='));return {ok:true,status:200,arrayBuffer:async()=>({byteLength:8388608}),json:async()=>({bytes:8388608})};};
 const cls=new Function('rpc','baseclass','Units','E','fetch','performance','crypto',source)(rpc,{extend:x=>x},{fmtRate:v=>(v/1e6).toFixed(2)+'M/s'},element,fetch,{now:()=>clock+=1000},{getRandomValues:()=>{}});
 let dispose=cls.mount({querySelector:()=>controls});assert.equal(controls.children.length,1);assert.equal(controls.children[0].children.length,3);
 let [lan,domestic,foreign]=controls.children[0].children;
 await domestic.children[0].onclick();assert(domestic.children[1].children[0].children[0].includes('23.46 ms'));assert(domestic.children[1].children[1].children[0].includes('123.45 ms'));
 await foreign.children[0].onclick();assert(foreign.children[1].children[0].children[0].includes('虚拟 IP'));assert.equal(domestic.children[1].children.length,2);
 await lan.children[0].onclick();assert(calls.some(c=>c.headers['Content-Type'].includes('download')));assert(calls.some(c=>c.headers['Content-Type'].includes('upload')));assert(!lan.children[0].disabled);assert(lan.children[1].children.at(-1).children[0].includes('完成'));
 fail=true;await lan.children[0].onclick();assert(lan.children[1].children.at(-1).children[0].includes('transport failed'));assert(!foreign.children[0].disabled);
 dispose();assert(controls.children.every(c=>c.removed));
 console.log('nettest DOM/transport round '+(round+1)+' PASS');
}})().catch(e=>{console.error(e);process.exit(1);});
