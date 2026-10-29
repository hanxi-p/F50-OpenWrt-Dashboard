const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
const dir=path.join(__dirname,'..');class Base{static extend(m){class X extends this{}Object.assign(X.prototype,m);return X;}}
const flush=async()=>{for(let i=0;i<14;i++)await Promise.resolve();};
async function scenario(){
 const {document,window}=parseHTML('<html><body><div class="f50-home"><div class="mud-body"><section class="mud-sec"></section></div></div></body></html>');
 function E(tag,a={},children=[]){const n=document.createElement(tag);for(const[k,v]of Object.entries(a))typeof v==='function'?n.addEventListener(k,v):n.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)n.append(typeof c==='string'?document.createTextNode(c):c);return n;}
 let timers=new Map(),id=0,modal,title,calls=[],errors=[],fail=false,payload={timestamp:1000,devices:[{mac:'02:50:aa:bb:cc:01',name:'Device',online:true,connection:'wifi5',interface:'wlan0',today_rx:200,total:500,month_total:400}]};
 const ui={showModal(t,n){if(modal)modal.remove();title=t;modal=E('div',{},n);document.body.append(modal);},hideModal(){if(modal)modal.remove();modal=null;},addNotification(_,n){errors.push(n.textContent);}};
 const rpc={declare:d=>(...args)=>{if(d.method==='status')return Promise.resolve(payload);calls.push([d.method,...args]);return Promise.resolve(fail?{error:'test failure'}:{ok:true});}};
 const Units=new(new Function('baseclass',fs.readFileSync(path.join(dir,'f50units.js'),'utf8'))(Base))();
 const View=new Function('baseclass','rpc','ui','Units','E','document','performance','setTimeout','clearTimeout',fs.readFileSync(path.join(dir,'f50devices.js'),'utf8'))(Base,rpc,ui,Units,E,document,{now:()=>1000},fn=>{timers.set(++id,fn);return id;},n=>timers.delete(n));
 const stop=new View().mount(document.querySelector('.f50-home'));
 async function tick(){const [n,f]=timers.entries().next().value;timers.delete(n);f();await flush();}
 const click=b=>b.dispatchEvent(new window.Event('click'));
 await tick();let row=document.querySelector('tr[data-connection]'),button=row.querySelector('.f50-device-total-action'),name=row.querySelector('.f50-device-name');
 name.onclick();assert.equal(title,'设备名称');ui.hideModal();button.onclick();assert.equal(title,'设备操作');assert(modal.textContent.includes('踢出并拒绝连接'));assert(!row.onpointerdown);
 click([...modal.querySelectorAll('button')].find(b=>b.textContent==='删除记录'));assert.equal(title,'删除统计记录');click([...modal.querySelectorAll('button')].find(b=>b.textContent==='删除记录'));await flush();assert.equal(calls.at(-1)[0],'remove');assert.equal(modal,null);
 button.onclick();click([...modal.querySelectorAll('button')].find(b=>b.textContent==='踢出并拒绝连接'));await flush();assert.equal(calls.at(-1)[0],'block');
 payload.devices[0].blocked=true;payload.timestamp++;await tick();assert.equal(row.querySelector('.f50-device-total-action'),button);button.onclick();click([...modal.querySelectorAll('button')].find(b=>b.textContent==='允许连接'));await flush();assert.equal(calls.at(-1)[0],'unblock');
 payload.devices[0].blocked=false;payload.timestamp++;await tick();button.onclick();fail=true;click([...modal.querySelectorAll('button')].find(b=>b.textContent==='踢出并拒绝连接'));await flush();assert(modal);assert(errors.includes('test failure'));assert([...modal.querySelectorAll('button')].every(b=>!b.disabled));fail=false;ui.hideModal();
 payload.devices[0].connection='wired';payload.devices[0].interface='usb0';payload.timestamp++;await tick();button.onclick();const deny=[...modal.querySelectorAll('button')].find(b=>b.textContent==='踢出并拒绝连接');assert(deny.disabled);const before=calls.length;deny.onclick();assert.equal(calls.length,before);ui.hideModal();
 stop();assert.equal(timers.size,0);
}
(async()=>{for(let i=0;i<3;i++)await scenario();console.log('PASS three rounds: total-value click only, rename intact, delete confirmation, block/unblock, stable button, errors, USB protection, cleanup');})().catch(e=>{console.error(e);process.exit(1);});
