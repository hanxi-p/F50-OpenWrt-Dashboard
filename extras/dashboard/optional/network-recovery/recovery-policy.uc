function pinDecision(main, group, alive){
 if(type(group)!='object'||group.type!='Fallback'||main!=group.name)return null;
 if(type(group.now)!='string'||group.fixed==group.now||!alive)return null;
 let found=false;for(let name in group.all??[])if(name==group.now)found=true;
 return found?group.now:null;
}
export {pinDecision};
