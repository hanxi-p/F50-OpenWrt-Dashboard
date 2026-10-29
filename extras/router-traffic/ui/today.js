'use strict';
'require baseclass';
return baseclass.extend({mount:function(root){
 if(root.querySelector('#rt-today-extra'))return;
 var total=root.querySelector('#f50-today-total'),session=root.querySelector('#f50-session-rx'),hour=root.querySelector('#f50-hour');
 if(!total||!session||!hour)return;
 var card=total.parentNode,first=session.parentNode.parentNode,second=hour.parentNode.parentNode;
 var content=E('div',{id:'rt-today-extra',hidden:true});first.parentNode.insertBefore(content,first);content.appendChild(first);content.appendChild(second);
 root.classList.add('rt-today-fold-page');card.classList.add('rt-today-toggle');
 card.setAttribute('role','button');card.setAttribute('tabindex','0');card.setAttribute('aria-controls','rt-today-extra');card.setAttribute('aria-expanded','false');
 function toggle(){content.hidden=!content.hidden;card.setAttribute('aria-expanded',String(!content.hidden));}
 card.onclick=toggle;card.onkeydown=function(event){if(event.key==='Enter'||event.key===' '){event.preventDefault();toggle();}};
 root.appendChild(E('style',{},`
 .rt-today-fold-page #rt-today-extra[hidden]{display:none!important}
 .rt-today-fold-page .rt-today-toggle{cursor:pointer}
 .rt-today-fold-page .rt-today-toggle>span:after{content:' ▸';display:inline-block;font-size:.75em;opacity:.7}
 .rt-today-fold-page .rt-today-toggle[aria-expanded=true]>span:after{content:' ▾'}
 body:has(.rt-today-fold-page) h2[name="content"]{display:none!important}
 `));
}});
