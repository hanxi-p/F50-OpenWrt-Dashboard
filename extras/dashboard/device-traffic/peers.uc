// Bridge membership supplies the port, not byte counters. Wi-Fi/USB share
// the existing conntrack ledger, so moving a row never adds traffic twice.
function usbPeers(peers, fdb, neighbours, carrier) {
 for(let line in split(neighbours??'', '\n')){
  let n=match(line,/^(\d+\.\d+\.\d+\.\d+) lladdr ([0-9a-fA-F:]{17})\s/);
  if(n){let mac=lc(n[2]);peers[mac]??={};peers[mac].ip=n[1];}
 }
 if(!carrier)return peers;
 for(let line in split(fdb??'', '\n')){
  let n=match(line,/^([0-9a-fA-F:]{17}) dev usb0\s.*master/);
  if(!n || index(line,'permanent')>=0 || index(line,'self')>=0)continue;
  let mac=lc(n[1]);
  if(peers[mac]?.online)continue;
  peers[mac]??={};peers[mac].connection='wired';peers[mac].interface='usb0';peers[mac].online=true;
 }
 return peers;
}
export {usbPeers};
