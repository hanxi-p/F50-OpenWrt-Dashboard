/* In-memory DOM checks; no browser, router access or private fixtures. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {parseHTML}=require('linkedom');
const dir=path.join(__dirname,'../extras/dashboard');
class Base{static extend(methods){class Derived extends this{}Object.assign(Derived.prototype,methods);return Derived;}}
function load(file,imports){return new Function(...Object.keys(imports),fs.readFileSync(path.join(dir,file),'utf8'))(...Object.values(imports));}
function dom(){
 const {document,window}=parseHTML('<html><body></body></html>');
 function E(tag,attrs={},children=[]){const el=document.createElement(tag);for(const [k,v] of Object.entries(attrs))typeof v==='function'?el.addEventListener(k,v):el.setAttribute(k,v);for(const child of [children].flat(Infinity))if(child!=null)el.append(typeof child==='string'?document.createTextNode(child):child);return el;}
 return {document,window,E};
}
const flush=async()=>{for(let i=0;i<12;i++)await Promise.resolve();};
async function scenario(){
 const {document,E,window}=dom(),root=document.body;let pending=[],now=0,payload,notifications=[];
 const rpc={declare:d=>()=>Promise.resolve(d.object==='f50devices'?payload:{ok:true,today:'2026-10-28',month:'2026-10',hour:2,quota_gb:100,monthly_json:'{}',hourly_json:JSON.stringify({interfaces:[{traffic:{hour:[{date:{year:2026,month:10,day:28},time:{hour:2},rx:1000,tx:2000}]}}]}),daily_json:JSON.stringify({interfaces:[{traffic:{day:[{date:{year:2026,month:10,day:28},rx:10000,tx:20000}]}}]})})};
 const ui={addNotification:(_,node)=>notifications.push(node.textContent),showModal:()=>{},hideModal:()=>{}};
 const Home=load('home.js',{view:Base,rpc,_:s=>s,E,document,L:{url:(...p)=>'/cgi-bin/luci/'+p.join('/')},requestAnimationFrame:()=>{},MutationObserver:window.MutationObserver});const home=new Home();root.innerHTML=home.html();
 const Units=new (load('f50units.js',{baseclass:Base}))();
 const common={Units,baseclass:Base,rpc,ui,E,document,setTimeout:fn=>(pending.push(fn),pending.length),clearTimeout:()=>{}};
 const cardIds=['mud-session-rx','mud-session-tx','mud-rx','mud-tx'];
 const cards=cardIds.map(id=>document.getElementById(id));cards[0].textContent='10 MB';cards[1].textContent='2 MB';
 const usage=document.getElementById('f50-usage-inline');assert.equal(usage.hidden,true);
 const quota=new (load('f50quota5.js',common))();const disposeQuota=quota.mount(root);await flush();
 const opener=root.querySelector('[data-q=usage-open]');
 assert.equal(usage.parentNode.id,'f50-quota-card');assert.equal(opener.getAttribute('aria-expanded'),'false');
 for(let i=0;i<3;i++){
  opener.onclick();assert.equal(usage.hidden,false);assert.equal(opener.getAttribute('aria-expanded'),'true');
  for(let n=0;n<4;n++)assert.equal(document.getElementById(cardIds[n]),cards[n],'toggling must preserve live counter nodes');
  assert.equal(cards[0].textContent,'10 MB');assert.equal(cards[1].textContent,'2 MB');assert.equal(cards[2].textContent,'0.00M');assert.equal(cards[3].textContent,'0.03M');
  const refresh=pending.shift();refresh();await flush();assert.equal(usage.hidden,false,'data refresh must not close the expanded panel');
  root.querySelector('[data-q=daily-open]').onclick();assert.equal(usage.hidden,false,'monthly consumed history is independent');
  opener.onclick();assert.equal(usage.hidden,true);
 }
 assert.deepEqual(notifications,[]);disposeQuota();pending=[];
 /* Organize after quota mounting too: the load row cannot depend on section position. */
 home.organize(root);home._actionsObserver.disconnect();
 const NetTest=new (load('f50nettest.js',common))();const disposeNetTest=NetTest.mount(root);
 const primary=root.querySelector('.f50-primary-controls');
 assert.deepEqual(Array.from(primary.children).slice(0,3).map(n=>n.id),['mud-btn-data','mud-btn-power','mud-btn-openclash']);
 assert.equal(primary.children[6].id,'mud-btn-adguard');assert.equal(primary.children[8].id,'mud-btn-other');
 assert.deepEqual(Array.from(primary.children).slice(3,6).map(n=>n.textContent),['内网速度','国内延迟','国外延迟']);
 assert.equal(root.querySelector('#f50-other-controls').contains(primary.children[3]),false);
 disposeNetTest();

 assert.equal(root.querySelectorAll('.f50-load-section > .mud-kpis > .mud-kpi').length,3);
 assert.ok(root.querySelector('#mud-peak-title'));assert.equal(usage.hidden,true);
 const signal=root.querySelector('#f50-signal-toggle'),cell=root.querySelector('#f50-cell-inline');assert.equal(cell.hidden,true);
 assert.ok(cell.previousElementSibling.classList.contains('mud-hero'));assert.equal(root.querySelector('.mud-hero').children.length,2);
 assert.ok(cell.querySelector('.f50-cell-summary #mud-cellline'));assert.equal(cell.querySelector('.f50-cell-grid').children.length,2);assert.equal(root.querySelectorAll('#mud-cellline').length,1);
 for(let i=0;i<3;i++){signal.onclick();assert.equal(cell.hidden,false);assert.equal(signal.getAttribute('aria-expanded'),'true');assert.equal(usage.hidden,true);signal.onclick();assert.equal(cell.hidden,true);}
 assert.ok(![...root.querySelectorAll('summary')].some(n=>n.textContent==='蜂窝网络详情'));
 const Devices=load('f50devices.js',{...common,performance:{now:()=>now}});assert.ok(Devices.prototype instanceof Base);
 const devices=new Devices();const disposeDevices=devices.mount(root);
 const tick=async()=>{assert.ok(pending.length);pending.shift()();await flush();};
 const sample={mac:'02:11:22:33:44:55',name:'A very long device name <script>text only</script>',ip:'192.0.2.2',interface:'wlan0',connection:'wifi5',online:true,today_rx:100,today_tx:99999,month_total:12345,total:999999,rx_rate:10000,tx_rate:300};
 payload={timestamp:1000,devices:[sample,{...sample}, {...sample,mac:'02:22:22:22:22:22',name:'Second',today_rx:200,today_tx:0,rx_rate:1}]};await tick();
 const stats=root.querySelector('.f50-devices'),rows=()=>[...stats.querySelectorAll('tbody tr')];
 assert.deepEqual([...stats.querySelector('table').querySelectorAll('th')].map(n=>n.textContent),['设备名称','实时速率','今日流量','本月累计','总累计']);
 assert.equal(rows().length,2);assert.equal(rows()[0].querySelector('button').textContent,'Second','rank uses daily download, ignoring upload, speed and lifetime');
 const row=rows()[1],scroll=stats.querySelector('.f50-device-scroll');assert.equal(row.querySelector('button').textContent,sample.name);assert.equal(row.querySelectorAll('script').length,0);
 assert.equal(row.children[1].children.length,2);assert.equal(row.children[2].children.length,2);
 scroll.scrollTop=35;scroll.scrollLeft=15;
 for(let i=0;i<12;i++){payload.timestamp++;await tick();assert.equal(rows()[1],row);assert.equal(scroll.scrollTop,35);assert.equal(scroll.scrollLeft,15);}
 now+=5000;await tick();assert.equal(row.children[1].textContent,'——');assert.notEqual(row.children[2].textContent,'——');
 payload.timestamp++;now++;await tick();assert.notEqual(row.children[1].textContent,'——');
 sample.connection='wifi24';payload.timestamp++;await tick();assert.equal(stats.querySelectorAll('tbody tr').length,2);assert.equal(row.getAttribute('data-connection'),'wifi24');
 const usb={...sample,mac:'02:33:33:33:33:33',name:'USB desktop',connection:'wired',interface:'usb0',online:true,today_rx:300};
 payload.devices.push(usb);payload.timestamp++;await tick();
 const usbRow=rows().find(r=>r.querySelector('button').textContent==='USB desktop');
 assert.equal(usbRow.closest('article'),row.closest('article'),'USB and Wi-Fi use the same live table');
 assert.equal(stats.querySelectorAll('.f50-device-panels > article').length,1);
 const offline=stats.querySelector('.f50-device-offline-group'),fold=stats.querySelector('.f50-device-toggle'),body=stats.querySelector('#f50-device-content');
 usb.online=false;payload.timestamp++;await tick();assert.equal(usbRow.closest('details'),offline);assert(!offline.hasAttribute('open'));assert.equal(offline.hidden,false);
 offline.setAttribute('open','');
 for(let i=0;i<3;i++){fold.onclick();assert.equal(body.hidden,true);fold.onclick();assert.equal(body.hidden,false);payload.timestamp++;await tick();assert(offline.hasAttribute('open'));assert.equal(usbRow.closest('details'),offline);}
 usb.online=true;payload.timestamp++;await tick();assert.equal(usbRow.closest('article'),row.closest('article'));assert.equal(offline.hidden,true);
 assert.equal(rows().length,3,'offline/online movements cannot duplicate rows');
 payload.devices=payload.devices.filter(d=>d!==usb);payload.timestamp++;await tick();assert.equal(rows().length,2,'authoritative snapshots remove missing rows');
 payload.devices=Array.from({length:20},(_,i)=>({...sample,mac:'02:44:44:44:44:'+i.toString(16).padStart(2,'0'),today_rx:i}));payload.timestamp++;await tick();assert.equal(rows().length,20,'full expansion has no device row cap');
 assert(fs.readFileSync(path.join(dir,'f50devices.js'),'utf8').includes('max-height:none'));
 disposeDevices();
}
(async()=>{for(let round=0;round<3;round++)await scenario();console.log('PASS 3 rounds: remaining-panel toggle/live values/refresh, three load cards, five device columns, daily-download order, MAC deduplication, stale rates, interface moves, USB unified rows, independent folding, full 20-row expansion and scroll retention. No browser used.');})().catch(e=>{console.error(e);process.exitCode=1;});
