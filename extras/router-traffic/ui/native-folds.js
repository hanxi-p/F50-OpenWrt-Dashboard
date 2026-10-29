'use strict';
'require baseclass';
'require fs';
'require dom';

var targets=['10_system','29_ports','30_network','40_dhcp','60_wifi','80_upnp'];
function mounted(node){return node&&document.documentElement.contains(node);}
function installStyle(){
 if(document.getElementById('rt-native-fold-style'))return;
 document.head.appendChild(E('style',{id:'rt-native-fold-style'},`
 .cbi-section:has(.rt-native-fold)>.cbi-title,.cbi-section:has(.rt-native-group)>.cbi-title{display:none!important}
 .rt-native-fold,.rt-native-group{min-width:0;width:100%}
 .rt-native-fold>summary,.rt-native-subfold>summary{list-style:none;cursor:pointer;user-select:none;font-size:14px;font-weight:600;line-height:1.6;padding:6px 0;color:inherit}
 .rt-native-fold>summary::-webkit-details-marker,.rt-native-subfold>summary::-webkit-details-marker{display:none}
 .rt-native-fold>summary::before,.rt-native-subfold>summary::before{content:'▸';display:inline-block;margin-right:8px;font-size:.8em;opacity:.7}
 .rt-native-fold[open]>summary::before,.rt-native-subfold[open]>summary::before{content:'▾'}
 .rt-native-body{min-width:0;padding-top:6px}
 .rt-native-group>.rt-native-subfold+ .rt-native-subfold{margin-top:6px;border-top:1px solid rgba(127,127,127,.15);padding-top:6px}
 `));
}
function patch(include,name){
 if(include._rtNativeFold)return;include._rtNativeFold=true;include.hide=false;
 var originalLoad=typeof include.load==='function'?include.load.bind(include):function(){return Promise.resolve(null);};
 var originalRender=include.render.bind(include),group=name==='40_dhcp',state={root:null,records:{},subOpen:{},pending:null,mounted:false};
 function fetch(){if(!state.pending)state.pending=Promise.resolve().then(originalLoad).finally(function(){state.pending=null;});return state.pending;}
 function message(body,text){dom.content(body,E('p',{},text));}
 function subfolds(content){
  var wrapper=E('div',{},[content]);
  Array.from(wrapper.querySelectorAll('h3')).forEach(function(heading){
   var key=heading.textContent,details=E('details',{class:'rt-native-subfold'},[E('summary',{},key)]),body=E('div',{class:'rt-native-body'}),node=heading.nextSibling;
   details.appendChild(body);heading.parentNode.insertBefore(details,heading);
   while(node&&node.nodeName!=='H3'){var next=node.nextSibling;body.appendChild(node);node=next;}heading.remove();
   details.open=!!state.subOpen[key];details.ontoggle=function(){state.subOpen[key]=details.open;};
  });return wrapper;
 }
 function paint(data){
  if(!group&&!state.root.open)return;
  if(name==='60_wifi')Array.from(state.body.querySelectorAll('.rt-native-subfold')).forEach(function(details){state.subOpen[details.querySelector('summary').textContent]=details.open;});
  var content=originalRender(data);
  if(!group){if(state.root.open)dom.content(state.body,name==='60_wifi'?subfolds(content):content);return;}
  var wrapper=E('div',{},[content]);
  Array.from(wrapper.querySelectorAll('h3')).forEach(function(heading){
   var key=heading.textContent,record=state.records[key],node=heading.nextSibling,children=[];
   while(node&&node.nodeName!=='H3'){children.push(node);node=node.nextSibling;}
   if(!record){
    var details=E('details',{class:'rt-native-subfold'},[E('summary',{},key)]),body=E('div',{class:'rt-native-body'});
    details.appendChild(body);state.root.appendChild(details);record=state.records[key]={details:details,body:body};
    details.ontoggle=function(){if(details.open){state.mounted=true;refresh(body);}};
   }
   if(record.details.open)dom.content(record.body,children);
  });
 }
 function refresh(body){
  if(!body.firstChild)message(body,_('Collecting data...'));
  fetch().then(function(data){if(mounted(state.root))paint(data);}).catch(function(){if(mounted(state.root))message(body,_('Failed to load data.'));});
 }
 include.load=function(){
  include.hide=false;include.failed=false;
  if(mounted(state.root))state.mounted=true;
  else if(state.mounted){state.root=null;state.records={};state.subOpen={};state.mounted=false;}
  if(group){if(!state.root||Object.keys(state.records).some(function(key){return state.records[key].details.open;}))return fetch();}
  else if(state.root&&state.root.open)return fetch();
  return Promise.resolve(null);
 };
 include.render=function(data){
  var connected=mounted(state.root);
  if(!state.root){
   if(group)state.root=E('div',{class:'rt-native-group'});
   else{
    state.body=E('div',{class:'rt-native-body'});state.root=E('details',{class:'rt-native-fold'},[E('summary',{},include.title||name),state.body]);
    state.root.ontoggle=function(){if(state.root.open){state.mounted=true;refresh(state.body);}};
   }
  }
  if(data!=null){try{paint(data);}catch(error){if(!group&&state.root.open)message(state.body,_('Failed to load data.'));}}
  return connected?null:state.root;
 };
}
return baseclass.extend({title:'',load:function(){
 installStyle();
 return fs.list('/www'+L.resource('view/status/include')).then(function(entries){return Promise.all(entries.filter(function(entry){return targets.indexOf(entry.name.replace(/\.js$/,''))>=0&&/\.js$/.test(entry.name);}).map(function(entry){var name=entry.name.replace(/\.js$/,'');return L.require('view.status.include.'+name).then(function(include){patch(include,name);});}));});
},render:function(){return null;}});
