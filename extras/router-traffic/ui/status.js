'use strict';
'require baseclass';
// Compatibility include: the WAN view owns all four F50 modules and their lifecycle.
return baseclass.extend({title:'',load:function(){return Promise.resolve(null);},render:function(){return null;}});
