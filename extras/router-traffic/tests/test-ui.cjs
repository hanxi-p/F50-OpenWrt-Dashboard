/* In-memory DOM regression tests. No browser, router, or private fixtures. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {parseHTML}=require('linkedom');const dir=path.join(__dirname,'../ui');
class Base{static extend(m){class Child extends this{}Object.assign(Child.prototype,m);return Child;}}
function load(file,imports){return new Function(...Object.keys(imports),fs.readFileSync(path.join(dir,file),'utf8'))(...Object.values(imports));}
const flush=async()=>{for(let i=0;i<12;i++)await Promise.resolve();};
async function scenario(){
 const {document}=parseHTML('<html><body><div class="rt-root"><div class="mud-body"><section class="mud-sec"></section></div></div></body></html>');
 const root=document.querySelector('.rt-root');let pending=[],payload,now=0;
 function E(tag,attrs={},children=[]){const el=document.createElement(tag);for(const [k,v] of Object.entries(attrs))typeof v==='function'?el.addEventListener(k,v):el.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)el.append(typeof c==='string'?document.createTextNode(c):c);return el;}
 const Units=new (load('units.js',{baseclass:Base}))();
 const rpc={declare:d=>()=>{assert.equal(d.object,'routertraffic');return Promise.resolve(d.method==='devices'?payload:{ok:true});}};
 const ui={showModal:()=>{},hideModal:()=>{},addNotification:()=>{}};
 const Devices=load('devices.js',{baseclass:Base,rpc,ui,Units,E,document,performance:{now:()=>now},setTimeout:fn=>(pending.push(fn),pending.length),clearTimeout:()=>{}});
 assert.ok(Devices.prototype instanceof Base,'LuCI factory must return a constructor');
 const disposeDevices=new Devices().mount(root);
 const tick=async()=>{assert.ok(pending.length);pending.shift()();await flush();};
 const sample={mac:'02:11:22:33:44:55',name:'A very long device name <script>text only</script>',ip:'192.0.2.2',interface:'wlan0',connection:'wifi5',online:true,today_rx:100,today_tx:99999,month_total:12345,total:999999,rx_rate:10000,tx_rate:300};
 payload={timestamp:1000,devices:[sample,{...sample}, {...sample,mac:'02:22:22:22:22:22',name:'Second',today_rx:200,today_tx:0,rx_rate:1}]};await tick();
 const stats=root.querySelector('.rt-devices'),rows=()=>[...stats.querySelectorAll('tbody tr[data-connection]')];
 assert.deepEqual([...stats.querySelector('table').querySelectorAll('th')].map(n=>n.textContent),['设备名称','实时速率','今日流量','本月累计','总累计']);
 assert.equal(rows().length,2);assert.equal(rows()[0].querySelector('button').textContent,'Second','rank uses daily download, ignoring upload, speed and lifetime');
 const row=rows()[1],scroll=stats.querySelector('.rt-device-scroll');assert.equal(row.querySelector('button').textContent,sample.name);assert.equal(row.querySelectorAll('script').length,0);
 assert.equal(row.children[1].children.length,2);assert.equal(row.children[2].children.length,2);
 scroll.scrollTop=35;scroll.scrollLeft=15;
 for(let i=0;i<12;i++){payload.timestamp++;await tick();assert.equal(rows()[1],row);assert.equal(scroll.scrollTop,35);assert.equal(scroll.scrollLeft,15);}
 now+=5000;await tick();assert.equal(row.children[1].textContent,'——');assert.notEqual(row.children[2].textContent,'——');
 payload.timestamp++;now++;await tick();assert.notEqual(row.children[1].textContent,'——');
 sample.connection='wifi24';payload.timestamp++;await tick();assert.equal(stats.querySelectorAll('tbody tr[data-connection]').length,2);assert.equal(row.getAttribute('data-connection'),'wifi24');
 const usb={...sample,mac:'02:33:33:33:33:33',name:'USB desktop',connection:'wired',interface:'usb0',online:true,today_rx:300};
 payload.devices.push(usb);payload.timestamp++;await tick();
 const usbRow=rows().find(r=>r.querySelector('button').textContent==='USB desktop');
 assert.equal(usbRow.closest('article'),row.closest('article'),'USB and Wi-Fi use the same live table');
 assert.equal(stats.querySelectorAll('.rt-device-panels > article').length,1);
 const offline=stats.querySelector('.rt-device-offline-group'),fold=stats.querySelector('.rt-device-toggle'),body=stats.querySelector('#rt-device-content');
 usb.online=false;payload.timestamp++;await tick();assert.equal(usbRow.parentNode.id,'rt-device-offline-rows');assert.equal(stats.querySelector('.rt-device-offline-toggle').getAttribute('aria-expanded'),'false');assert.equal(offline.hidden,false);
 const offlineToggle=stats.querySelector('.rt-device-offline-toggle');offlineToggle.onclick();
 assert.equal(offline.closest('table'),row.closest('table'));assert.equal(stats.querySelectorAll('table').length,1);assert.equal(stats.querySelectorAll('article').length,1);assert.equal(stats.querySelectorAll('thead').length,1);
 for(let i=0;i<3;i++){fold.onclick();assert.equal(body.hidden,true);fold.onclick();assert.equal(body.hidden,false);payload.timestamp++;await tick();assert.equal(offlineToggle.getAttribute('aria-expanded'),'true');assert.equal(usbRow.parentNode.hidden,false);}
 usb.online=true;payload.timestamp++;await tick();assert.equal(usbRow.closest('article'),row.closest('article'));assert.equal(offline.hidden,true);
 assert.equal(rows().length,3,'offline/online movements cannot duplicate rows');
 payload.devices=payload.devices.filter(d=>d!==usb);payload.timestamp++;await tick();assert.equal(rows().length,2,'authoritative snapshots remove missing rows');
 payload.devices=Array.from({length:20},(_,i)=>({...sample,mac:'02:44:44:44:44:'+i.toString(16).padStart(2,'0'),today_rx:i}));payload.timestamp++;await tick();assert.equal(rows().length,20,'full expansion has no device row cap');
 assert(fs.readFileSync(path.join(dir,'devices.js'),'utf8').includes('max-height:none'));
 disposeDevices();
}
(async()=>{for(let i=0;i<3;i++)await scenario();console.log('PASS three DOM rounds: constructor, columns, daily-download order, dedup, stale, names, shared wired/Wi-Fi table, child offline fold, full expansion and retained scroll');})().catch(e=>{console.error(e);process.exitCode=1;});
