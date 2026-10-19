'use strict';
'require baseclass';
'require mu300.common as M';
/* Keep peak values and background records without an expandable history chart. */
return baseclass.extend({mount:function(root){
 var values=[root.querySelector('#mud-peak-download b'),root.querySelector('#mud-peak-upload b')];
 return {update:function(data){
  if(!data||!/^\d{4}-\d{2}-\d{2}$/.test(data.today)||!Array.isArray(data.days))return;
  var today=data.days.find(function(d){return d&&d.date===data.today&&['download','upload'].every(function(k){return Number.isFinite(d[k])&&d[k]>=0&&d[k]<=1250000000;});});
  values.forEach(function(el,i){if(el)el.textContent=today?M.fmtRate(today[i?'upload':'download']):'—';});
 },dispose:function(){values=[];}};
}});
