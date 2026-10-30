const fs=require('node:fs'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
class Base{static extend(m){class X extends this{}Object.assign(X.prototype,m);return X;}}
const flush=async()=>{for(let i=0;i<16;i++)await Promise.resolve();};
async function round(){
 const {document,window}=parseHTML('<html><body><div class="rt-root"><div class="mud-body"><section class="mud-sec"></section></div></div></body></html>');let modal,title,calls=[],fail=false,timers=new Map(),n=0;
 function E(tag,a={},children=[]){const node=document.createElement(tag);for(const[k,v]of Object.entries(a))typeof v==='function'?node.addEventListener(k,v):node.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)node.append(typeof c==='string'?document.createTextNode(c):c);return node;}
 const d={mac:'02:11:22:33:44:55',device_id:'12345678-1234-4234-8234-123456789001',name:'Test',online:true,connection:'wifi5',today_rx:10,total:100};let payload={timestamp:1000,devices:[d]},errors=[];
 const ui={showModal(t,items){modal?.remove();title=t;modal=E('div',{},items);document.body.append(modal);},hideModal(){modal?.remove();modal=null;},addNotification(_,e){errors.push(e.textContent);}};
 const rpc={declare:m=>(...args)=>{if(m.method==='devices')return Promise.resolve(payload);calls.push([m.method,...args]);return Promise.resolve(fail?{error:'test failure'}:{ok:true});}};
 const View=new Function('baseclass','rpc','ui','Profiles','Units','E','document','performance','setTimeout','clearTimeout',fs.readFileSync(__dirname+'/../ui/devices.js','utf8'))(Base,rpc,ui,{manage:()=>calls.push(['profiles'])},{fmtBytes:()=> '1M',fmtRate:()=> '0B/s'},E,document,{now:()=>1000},fn=>(timers.set(++n,fn),n),i=>timers.delete(i));
 const stop=new View().mount(document.querySelector('.rt-root'));async function tick(){let [i,f]=timers.entries().next().value;timers.delete(i);f();await flush();}await tick();
 const click=b=>b.dispatchEvent(new window.Event('click')),button=()=>[...modal.querySelectorAll('button')].find(b=>b.textContent==='删除记录'),total=document.querySelector('.rt-device-total-action');
 total.onclick();assert.equal(title,'设备操作');click(button());assert.equal(title,'删除统计记录');assert.equal(calls.length,0);click([...modal.querySelectorAll('button')].find(b=>b.textContent==='取消'));assert.equal(calls.length,0);
 total.onclick();click(button());click(button());await flush();assert.deepEqual(calls.at(-1),['remove',d.mac,d.device_id,true]);assert.equal(modal,null);
 total.onclick();click([...modal.querySelectorAll('button')].find(b=>b.textContent==='设备档案／MAC绑定'));assert.deepEqual(calls.at(-1),['profiles']);ui.hideModal();
 total.onclick();click(button());fail=true;click(button());await flush();assert(errors.includes('test failure'));assert(!button().disabled);ui.hideModal();
 payload={timestamp:1001,devices:[]};await tick();assert(!document.querySelector('.rt-device-total-action'));stop();assert.equal(timers.size,0);
}
(async()=>{for(let i=0;i<3;i++)await round();console.log('PASS delete UI three rounds: total menu, confirmation/cancel, UUID guard args, existing profile entry, errors, row removal and cleanup');})().catch(e=>{console.error(e);process.exit(1);});
