-- Called through the authenticated RPC and a flock; never writes the ledger.
local fs=require 'nixio.fs'
local nixio=require 'nixio'
local json=require 'luci.jsonc'
local P=os.getenv('F50_DEVICE_DATA_DIR') or '/etc/f50-devices'
local C=os.getenv('F50_DEVICE_UCI_DIR') or '/etc/config'
local verb,mac=arg[1],(arg[2] or ''):lower()
local function valid(m) return #m==17 and m:match('^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$') and tonumber(m:sub(1,2),16)%2==0 end
local function read(path,default)
 local f=io.open(path);if not f then return default end
 local s=f:read('*a');f:close();local v=json.parse(s);assert(type(v)=='table','配置损坏，未覆盖原文件');return v
end
local function atomic(path,v)
 local f=assert(io.open(path..'.new','w'));fs.chmod(path..'.new','600')
 assert(f:write(json.stringify(v)));assert(f:close());assert(fs.rename(path..'.new',path))
end
local tmp='/tmp/f50-device-action-'..nixio.getpid()
local cursor,socket
local function quote(s)return "'"..s:gsub("'","'\\''").."'"end
local function text(path)local f=assert(io.open(path));local v=f:read('*a');f:close();return v end
-- This firmware has ucode UCI but no Lua UCI binding. Use a private CLI
-- delta directory so unrelated pending LuCI changes are never committed.
local function uciCursor()
 -- Merely changing -P/-t still imports /tmp/.uci/wireless on this UCI.
 -- A unique package name avoids importing any pending user delta.
 local package='f50action'..nixio.getpid()
 assert(fs.mkdir(tmp..'/uci','700'))
 local expected=text(C..'/wireless')
 local f=assert(io.open(tmp..'/uci/'..package,'w'));assert(f:write(expected));f:close();fs.chmod(tmp..'/uci/'..package,'600')
 local base='uci -q -c '..quote(tmp..'/uci')..' -t '..quote(tmp)..' '
 local c={}
 local function output(args)
  local p=assert(io.popen(base..args..' 2>/dev/null'));local s=p:read('*a');p:close();return s:gsub('[\r\n]+$','')
 end
 local function exec(args)assert(os.execute(base..args..' >/dev/null 2>&1')==0,'保存无线配置失败');return true end
 function c:get(config,section,key)local s=output('get '..quote(package..'.'..section..'.'..key));return s~='' and s or nil end
 function c:get_list(config,section,key)local a={};for m in (self:get(config,section,key) or ''):gmatch('%S+')do assert(valid(m:lower()),'已有MAC列表格式无效');a[#a+1]=m end;return a end
 function c:set(config,section,key,value)return exec('set '..quote(package..'.'..section..'.'..key..'='..value))end
 function c:delete(config,section,key)os.execute(base..'delete '..quote(package..'.'..section..'.'..key)..' >/dev/null 2>&1');return true end
 function c:set_list(config,section,key,list)self:delete(config,section,key);for _,m in ipairs(list)do exec('add_list '..quote(package..'.'..section..'.'..key..'='..m))end;return true end
 function c:foreach(config,kind,callback)
  for line in output('show '..quote(package)):gmatch('[^\n]+')do
   local section=line:match('^'..package..'%.([%w_]+)=wifi%-iface$')
   if section then callback({['.name']=section,mode=self:get(config,section,'mode'),ifname=self:get(config,section,'ifname')})end
  end
 end
 function c:save()return true end
 function c:commit(config)
  exec('commit '..quote(package))
  assert(text(C..'/wireless')==expected,'无线配置已被其他操作修改，请重试')
  local value=text(tmp..'/uci/'..package)
  local f=assert(io.open(C..'/wireless.f50-action-new','w'));fs.chmod(C..'/wireless.f50-action-new','600');assert(f:write(value));assert(f:close())
  assert(fs.rename(C..'/wireless.f50-action-new',C..'/wireless'));expected=value;return true
 end
 function c:close()end
 return c
end
local function main()
 assert(verb=='remove' or verb=='block' or verb=='unblock','无效操作')
 assert(valid(mac),'无效MAC地址')
 local links=read(P..'/identities.json',{})
 local function identity(m)
  local r=links[m];if type(r)~='string' or not valid(r) or (links[r] and links[r]~=r) then return m end
  return r
 end
 local root=identity(mac)
 local ledger=read(P..'/ledger.json',{devices={}})
 local control=read(P..'/actions.json',{version=1,serial=0,deleted={},blocked={}})
 control.deleted=control.deleted or {};control.blocked=control.blocked or {}
 local known=false;local members={[mac]=true,[root]=true};local iface
 for m,d in pairs(ledger.devices or {}) do if identity(m)==root then
  known=true;members[m]=true
  if d.interface and d.interface:match('^wlan[%w_.%-]*$') then iface=d.interface end
 end end
 for m in pairs(links) do if identity(m)==root then members[m]=true end end
 if control.blocked[root] then for _,m in ipairs(control.blocked[root])do members[m]=true end;known=true end
 assert(known,'设备记录已不存在，请刷新后重试')
 if verb=='remove' then
  control.serial=(control.serial or 0)+1
  control.deleted[root]={id=os.time()..'-'..control.serial,at=os.time()}
  atomic(P..'/actions.json',control)
  return {ok=true,pending=true}
 end
 assert(iface,'只能对无线设备设置拒绝连接，USB管理连接不受此操作影响')
 assert(fs.mkdir(tmp,'700'),'无法建立私有操作目录')
 cursor=uciCursor()
 local section
 cursor:foreach('wireless','wifi-iface',function(s)if s.mode=='ap' and s.ifname==iface then section=s['.name'] end end)
 assert(section,'找不到对应无线接入点')
 local oldMode=cursor:get('wireless',section,'macfilter')
 local oldList=cursor:get_list('wireless',section,'maclist') or {}
 assert(not oldMode or oldMode=='disable' or oldMode=='deny','当前使用无线白名单，不能自动改为黑名单')
 assert(oldMode=='deny' or #oldList==0,'原有未启用的MAC列表需先人工整理，未自动激活')
 control.wifi_original=control.wifi_original or {}
 if verb=='block' and not control.wifi_original[iface] then control.wifi_original[iface]={mode=oldMode or false}end
 socket=assert(nixio.socket('unix','dgram'));assert(socket:bind(tmp..'/ctrl'))
 assert(socket:setopt('socket','rcvtimeo',2))
 assert(socket:connect('/var/run/hostapd/'..iface),'无线接入点尚未就绪')
 local function command(text)
  assert(socket:send(text));local result=socket:recv(8192)
  assert(result and not result:match('UNKNOWN COMMAND') and not result:match('^FAIL'),'无线驱动不支持此操作或响应超时')
  return result
 end
 local runtime=command('DENY_ACL SHOW'):lower()
 local list={};for _,m in ipairs(oldList)do if not members[m:lower()] then list[#list+1]=m end end
 local targets={};for m in pairs(members)do assert(valid(m));targets[#targets+1]=m;if verb=='block' then list[#list+1]=m end end
 table.sort(targets)
 local function restore()
  if oldMode then cursor:set('wireless',section,'macfilter',oldMode)else cursor:delete('wireless',section,'macfilter')end
  if #oldList>0 then cursor:set_list('wireless',section,'maclist',oldList)else cursor:delete('wireless',section,'maclist')end
  cursor:save('wireless');cursor:commit('wireless')
  for _,m in ipairs(targets)do pcall(command,'DENY_ACL '..(runtime:find(m,1,true) and 'ADD_MAC ' or 'DEL_MAC ')..m)end
 end
 local ok,err=pcall(function()
  local original=control.wifi_original[iface]
  if verb=='unblock' and #list==0 and original and not original.mode then cursor:delete('wireless',section,'macfilter')
  elseif verb=='unblock' and #list==0 and original then cursor:set('wireless',section,'macfilter',original.mode)
  else cursor:set('wireless',section,'macfilter','deny')end
  if #list>0 then cursor:set_list('wireless',section,'maclist',list)else cursor:delete('wireless',section,'maclist')end
  assert(cursor:save('wireless'));assert(cursor:commit('wireless'))
  for _,m in ipairs(targets)do assert(command('DENY_ACL '..(verb=='block' and 'ADD_MAC ' or 'DEL_MAC ')..m):match('^OK'),'设置拒绝列表失败')end
  local verified=command('DENY_ACL SHOW'):lower()
  for _,m in ipairs(targets)do assert((verified:find(m,1,true)~=nil)==(verb=='block'),'无线黑名单读回不一致')end
  if verb=='block' then
   local p=assert(io.popen('ubus call '..quote('hostapd.'..iface)..' get_clients 2>/dev/null'))
   local clients=json.parse(p:read('*a'));p:close();assert(clients and clients.clients,'无法检查关联设备')
   for _,m in ipairs(targets)do if clients.clients[m]then
    local payload=json.stringify({addr=m,reason=1,deauth=true,ban_time=0})
    assert(os.execute('ubus call '..quote('hostapd.'..iface)..' del_client '..quote(payload)..' >/dev/null 2>&1')==0,'踢出设备失败')
   end end
  end
  if verb=='block' then control.blocked[root]=targets else control.blocked[root]=nil end
  if verb=='unblock' and #list==0 then control.wifi_original[iface]=nil end
  atomic(P..'/actions.json',control)
 end)
 if not ok then local restored,why=pcall(restore);error(tostring(err)..(restored and '' or '; 恢复需检查: '..tostring(why)))end
 return {ok=true,blocked=verb=='block'}
end
local ok,result=pcall(main)
if socket then socket:close()end
if cursor then cursor:close()end
if fs.stat(tmp..'/uci')then for n in fs.dir(tmp..'/uci')do fs.unlink(tmp..'/uci/'..n)end;fs.rmdir(tmp..'/uci')end
if fs.stat(tmp) then for n in fs.dir(tmp)do fs.unlink(tmp..'/'..n)end;fs.rmdir(tmp)end
print(json.stringify(ok and result or {error=tostring(result)}))
