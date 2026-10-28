'use strict';
'require baseclass';
var K = 1000, M = 1000000, G = 1000000000;
function scale(n, rate) { return n >= G ? {divisor:G,unit:'G'} : (rate && n < K ? {divisor:1,unit:'B'} : (rate && n < M ? {divisor:K,unit:'K'} : {divisor:M,unit:'M'})); }
function format(n, rate, places, fixed) {
 if (n == null || !Number.isFinite(+n) || +n < 0) return '—';
 n = +n;
 var s=scale(n,rate), value=n/s.divisor;
 var precision=places==null?(value>0&&value<0.001?6:3):places;
 var text=value.toFixed(precision);
 if (!fixed && text.indexOf('.')>=0) text=text.replace(/\.?0+$/, '');
 if (!text) text='0';
 return text+s.unit+(rate?'/s':'');
}
return baseclass.extend({
 fmtBytes:function(n,places,fixed){return format(n,false,places,fixed);},
 fmtRate:function(n){return format(n,true);},
 rateScale:function(n){var s=scale(n,true);return {divisor:s.divisor,unit:s.unit+'/s'};}
});
