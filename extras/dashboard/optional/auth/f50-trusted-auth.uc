// Local MAC allowlist authentication. No password is stored in this module.
import { readfile, popen, glob, open } from 'fs';
import { connect, error as ubus_error } from 'ubus';

export function match_peer(addr, entries, neighbors, fdb, wifi) {
 if (type(addr) != 'string' || !match(addr, /^[0-9a-fA-F:.]+$/) || addr == '127.0.0.1' || addr == '::1') return null;
 let mac = null;
 for (let line in split(neighbors || '', '\n')) {
  let p = split(trim(line), /\s+/);
  if (p[0] != addr || p[1] != 'lladdr' || !match(p[2] || '', /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i)) continue;
  if (index(line, 'FAILED') >= 0 || index(line, 'INCOMPLETE') >= 0) continue;
  if (mac && mac != lc(p[2])) return null;
  mac = lc(p[2]);
 }
 if (!mac || !entries?.[mac]) return null;
 let entry = entries[mac], port = null;
 for (let line in split(fdb || '', '\n')) {
  let p = split(trim(line), /\s+/);
  if (lc(p[0] || '') == mac && p[1] == 'dev' && index(line, 'master br-lan') >= 0 && index(line, 'permanent') < 0) {
   if (port && port != p[2]) return null;
   port = p[2];
  }
 }
 if (entry.port != port || !port) return null;
 if (port == 'wlan0' && !(wifi?.clients?.[mac]?.authorized && wifi.clients[mac].assoc)) return null;
 if (port != 'wlan0' && port != 'usb0') return null;
 return { mac, port };
};

function capture(command) {
 let p = popen(command, 'r'); if (!p) return null;
 let text = p.read('all'), rc = p.close(); return rc == 0 ? text : null;
}

export function setup(ubus, addr) {
 let sid = null;
 try {
  let config = json(readfile('/etc/f50-trusted-devices.json') || '{}');
  if (config.enabled !== true) return null;
  ubus = connect(null, 2);
  if (!ubus) return null;
  let peer = match_peer(addr, config.devices,
   capture('/usr/libexec/f50-bounded 2 /sbin/ip neigh show dev br-lan'),
   capture('/usr/libexec/f50-bounded 2 /usr/sbin/bridge fdb show br br-lan'),
   ubus.call('hostapd.wlan0', 'get_clients', {}));
  if (!peer) return null;
  let login = ubus.call('session', 'create', { timeout: 43200 });
  sid = login?.ubus_rpc_session;
  if (type(sid) != 'string' || !match(sid, /^[0-9a-f]{32}$/)) return null;
  // Apply the installed ACL definitions as rpcd does for the existing root '*'.
  for (let file in glob('/usr/share/rpcd/acl.d/*.json')) {
   let groups = json(readfile(file));
   for (let group, rules in groups) {
    for (let perm in ['read', 'write']) {
     if (type(rules[perm]) != 'object') continue;
     ubus.call('session', 'grant', {ubus_rpc_session:sid, scope:'access-group', objects:[[group,perm]]});
     if (ubus_error()) die('ACL grant failed');
     for (let scope, objects in rules[perm]) {
      let grants = [];
      if (type(objects) == 'array') { for (let object in objects) push(grants, [object, perm]); }
      else { for (let object, methods in objects) for (let method in methods) push(grants, [object,method]); }
      if (length(grants)) {
       ubus.call('session','grant',{ubus_rpc_session:sid,scope,objects:grants});
       if (ubus_error()) die('ACL scope failed');
      }
     }
    }
   }
  }
  let f = open('/dev/urandom','r'); let token = f?.read(16); f?.close();
  if (length(token) != 16) die('No random token');
  ubus.call('session','set',{ubus_rpc_session:sid,values:{username:'root',token:hexenc(token),f50_trusted_mac:peer.mac}});
  if (ubus_error()) die('Session data failed');
  return sid;
 } catch (e) {
  warn('F50 trusted authentication failed: ', e, '\n');
  if (sid) ubus.call('session','destroy',{ubus_rpc_session:sid});
  return null;
 }
};
