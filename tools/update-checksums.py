"""Refresh source package checksums, excluding explicitly local build outputs."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
local={'device-traffic/flow-account','device-traffic/flow-account.build','device-traffic/SHA256SUMS.local'}
for name in ['dashboard','sms-email','system-reliability']:
 folder=root/'extras'/name;rows=[]
 for p in sorted(folder.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(folder).as_posix()
  if rel=='SHA256SUMS' or rel in local or '__pycache__' in p.parts or p.suffix=='.pyc':continue
  assert p.suffix not in ('.ko','.key','.private'),p
  rows.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+rel)
 (folder/'SHA256SUMS').write_text('\n'.join(rows)+'\n',encoding='ascii',newline='\n')
 print(name+': '+str(len(rows))+' source files')
