const fs=require('node:fs'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
class Base{static extend(m){class X{}Object.assign(X.prototype,m);return X;}}
for(let round=0;round<3;round++){
 const {document}=parseHTML('<html><body><h2 name="content">状态</h2><div class="f50-home"><section><div><div><b id="f50-today-total">12M</b><span>今日总流量</span></div></div><div class="mud-kpis"><div><b id="f50-session-rx">1M</b></div><div><b id="f50-session-tx">2M</b></div></div><div class="mud-kpis"><div><b id="f50-hour">3M</b></div><div><b id="f50-day">4M</b></div></div></section></div></body></html>');
 function E(tag,a={},children=[]){const n=document.createElement(tag);for(const [k,v] of Object.entries(a))n.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)n.append(typeof c==='string'?document.createTextNode(c):c);return n;}
 const Class=new Function('baseclass','E',fs.readFileSync(__dirname+'/../ui/today.js','utf8'))(Base,E),view=new Class(),root=document.querySelector('.f50-home'),value=document.getElementById('f50-today-total'),four=['f50-session-rx','f50-session-tx','f50-hour','f50-day'].map(id=>document.getElementById(id));
 view.mount(root);const card=value.parentNode,content=root.querySelector('#rt-today-extra');assert(content.hidden);assert.equal(content.children.length,2);assert(four.every(n=>content.contains(n)));assert(!content.contains(value));
 for(let i=0;i<10;i++){card.onclick();assert(!content.hidden);four[0].textContent=String(i);assert(!content.hidden);card.onclick();assert(content.hidden);}
 card.onkeydown({key:'Enter',preventDefault(){}});assert(!content.hidden);card.onkeydown({key:' ',preventDefault(){}});assert(content.hidden);
 view.mount(root);assert.equal(root.querySelectorAll('#rt-today-extra').length,1);assert(four.every(n=>content.contains(n)));assert(root.querySelector('style').textContent.includes('h2[name="content"]'));
}
console.log('PASS three rounds: four existing counters preserved in today-total disclosure, default closed, updates, keyboard, duplicate mount and scoped status heading');
