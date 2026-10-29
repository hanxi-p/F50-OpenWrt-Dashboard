'use strict';
'require baseclass';
'require rpc';
'require ui';
var list=rpc.declare({object:'routertraffic',method:'profiles',expect:{'':{}}});
var sessionList=rpc.declare({object:'routertraffic',method:'sessions',params:['mac','expected_id'],expect:{'':{}}});
var bind=rpc.declare({object:'routertraffic',method:'bind',params:['mac','device_id','expected_id','confirmed'],expect:{'':{}}});
var detach=rpc.declare({object:'routertraffic',method:'detach',params:['mac','expected_id','confirmed'],expect:{'':{}}});
return baseclass.extend({manage:function(d){
 function modalStyle(){return E('style',{},'.modal.f50-profile-modal{box-sizing:border-box;width:min(360px,calc(100vw - 40px))!important;min-width:0!important;max-width:calc(100vw - 40px)!important}.f50-profile-modal p{overflow-wrap:anywhere}');}
 function error(e){ui.addNotification(null,E('p',{},e.message||String(e)));}
 list().then(function(data){
  if(!data.ok)throw Error('设备档案尚未就绪，请稍后重试');
  var current=(data.profiles||[]).find(function(p){return p.id===d.device_id;});
  if(!current)throw Error('设备归属已变化，请刷新后重试');
  var select=E('select',{style:'width:100%;min-width:0'},data.profiles.map(function(p){return E('option',{value:p.id},p.name+' · '+p.id.slice(-8)+(p.members.length?'':'（无绑定MAC）'));}));select.value=current.id;
  function request(fn,args,button){button.disabled=true;fn.apply(null,args).then(function(r){if(!r.ok)throw Error(r.error||'保存失败');ui.hideModal();}).catch(error).finally(function(){button.disabled=false;});}
  function confirmMove(mac,remove){
   var target=(data.profiles||[]).find(function(p){return p.id===select.value;});
   if(!remove&&(!target||target.id===current.id))return;
   ui.showModal(remove?'解绑MAC':'确认MAC归属',[modalStyle(),
    E('p',{},mac),E('p',{},remove?'此MAC将成为独立设备档案，原始流量保留。':'请确认此地址确属“'+target.name+'”。该MAC的已有流量随归属迁移，不修改其他地址或免登录权限。'),
    E('div',{class:'right'},[E('button',{class:'btn',click:ui.hideModal},'取消'),E('button',{class:'btn cbi-button-positive',click:function(){request(remove?detach:bind,remove?[mac,current.id,true]:[mac,target.id,current.id,true],this);}},'确认')])
   ],'f50-profile-modal');
  }
  var members=current.members.map(function(m){
   var remove=E('button',{class:'btn',type:'button',style:'margin-left:8px'},'解绑');remove.disabled=current.members.length<2;remove.onclick=function(){confirmMove(m.mac,true);};
   return E('div',{style:'margin:8px 0;overflow-wrap:anywhere'},[E('div',{},[m.mac,remove]),E('small',{},(m.online?'在线':'离线')+' · '+(m.ip||'—')+' · 绑定于 '+new Date(m.bound_at*1000).toLocaleString())]);
  });
  function showRecords(title,rows){ui.showModal(title,[modalStyle(),E('div',{style:'max-height:55vh;overflow:auto;font-size:.85em'},rows.length?rows:[E('p',{},'暂无记录')]),E('div',{class:'right'},[E('button',{class:'btn',click:ui.hideModal},'关闭')])],'f50-profile-modal');}
  var sessionsButton=E('button',{class:'btn',type:'button',click:function(){sessionList(d.mac,current.id).then(function(r){if(!r.ok)throw Error(r.error||'读取失败');showRecords('Wi-Fi连接记录',(r.sessions||[]).map(function(v){return E('p',{style:'border-bottom:1px solid #ddd;padding-bottom:8px'},[E('div',{},v.mac+' · '+v.interface),E('div',{},new Date(v.start*1000).toLocaleString()+' → '+(v.online?'在线':v.end?new Date(v.end*1000).toLocaleString():'记录中断')),E('small',{},v.reason==='observation_gap'?'采集曾中断，断开时间未知':'时间按在线检测记录')]);}));}).catch(error);}},'Wi-Fi连接记录');
  var historyButton=E('button',{class:'btn',type:'button',click:function(){showRecords('MAC绑定历史',(data.history||[]).filter(function(h){return h.from===current.id||h.to===current.id;}).reverse().map(function(h){return E('p',{},[E('div',{},h.mac),E('small',{},new Date(h.at*1000).toLocaleString()+' · '+({migrate:'原有绑定迁入',detected:'首次发现',bind:'确认绑定',detach:'解绑为独立设备'}[h.action]||h.action))]);}));}},'MAC绑定历史');
  var save=E('button' ,{class:'btn cbi-button-positive',type:'button'},'绑定当前MAC');save.disabled=true;select.onchange=function(){save.disabled=select.value===current.id;};save.onclick=function(){confirmMove(d.mac,false);};
  ui.showModal('设备档案与MAC绑定',[
   modalStyle(),
   E('p',{},current.name),E('div',{},[sessionsButton,historyButton]),E('p',{style:'font-size:.75em;overflow-wrap:anywhere'},'设备ID：'+current.id),E('div',{},members),
   E('p',{},'将当前MAC归属到已确认的设备：'),select,E('div',{class:'right',style:'margin-top:12px'},[E('button',{class:'btn',click:ui.hideModal},'关闭'),save])
  ],'f50-profile-modal');
 }).catch(error);
}});
