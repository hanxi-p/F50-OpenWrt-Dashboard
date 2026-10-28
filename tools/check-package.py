"""Read-only package/link/syntax checks; never connects to or modifies an F50."""
from pathlib import Path
import ast,hashlib,json,re,shutil,subprocess
root=Path(__file__).resolve().parents[1]
missing=[];count=0
for folder in ['dashboard','sms-email','system-reliability','notifications']:
 d=root/'extras'/folder
 for line in (d/'SHA256SUMS').read_text(encoding='utf-8').splitlines():
  digest,name=line.split('  ',1)
  assert (d/name).is_file() and hashlib.sha256((d/name).read_bytes()).hexdigest()==digest,(folder,name)
 for p in d.rglob('*'):
  if p.is_file():
   if p.relative_to(d).as_posix() in ('device-traffic/flow-account','device-traffic/SHA256SUMS.local','device-traffic/flow-account.build'):continue
   data=p.read_bytes();assert b'\r\n' not in data,p
   if data.startswith(b'#!/bin/sh') and shutil.which('bash'):subprocess.run(['bash','-n',str(p)],check=True)
   if p.suffix=='.py':ast.parse(p.read_text(encoding='utf-8'))
   count+=1
for p in root.rglob('*.md'):
 if '.git' in p.parts or 'node_modules' in p.parts:continue
 text=re.sub(r'```[\s\S]*?```','',p.read_text(encoding='utf-8'))
 targets=re.findall(r'\]\(([^)]+)\)',text)+re.findall(r'<img[^>]+src="([^"]+)"',text)
 for target in targets:
  if '://' in target or target.startswith(('mailto:','#')):continue
  path=target.strip('<>').partition('#')[0]
  if not (p.parent/path).exists():missing.append((str(p.relative_to(root)),target))
assert not missing,missing
catalog=json.loads((root/'features.json').read_text(encoding='utf-8')) if (root/'features.json').exists() else None
if catalog:
 ids=[f['id'] for f in catalog['features']];assert len(ids)==len(set(ids))
 if 'categories' in catalog:
  assert len(catalog['categories'])==len(set(catalog['categories']))
  assert set(catalog['categories'])=={f['category'] for f in catalog['features']}
  readme=(root/'README.md').read_text(encoding='utf-8');assert all('### '+category in readme for category in catalog['categories'])
 for feature in catalog['features']:
  assert (root/feature['document']).is_file(),feature['id']
  assert feature['document'] in (root/'README.md').read_text(encoding='utf-8'),feature['id']
  for path in feature['files']:assert (root/path).is_file(),(feature['id'],path)
  options=feature.get('options',[]);assert len({o['id'] for o in options})==len(options)
  for option in options:assert (root/option['document']).is_file(),(feature['id'],option['id'])
 selected=json.loads((root/'selection.example.json').read_text(encoding='utf-8'))['features'];assert all(x in ids for x in selected)
 for alias,targets in catalog.get('aliases',{}).items():assert alias not in ids and all(x in ids for x in targets)
 configuration=next((f for f in catalog['features'] if f['id']=='configuration'),None)
 if configuration:
  allowed={o['id'] for o in configuration['options']}
  choice=json.loads((root/'selection.example.json').read_text(encoding='utf-8')).get('configuration',{}).get('options',[]);assert all(x in allowed for x in choice)
  for alias,row in catalog.get('option_aliases',{}).items():assert row['feature']=='configuration' and row['option'] in allowed
js=list((root/'extras/dashboard').rglob('*.js'))+list((root/'extras/dashboard').rglob('*.cjs'))
if shutil.which('node'):
 subprocess.run(['node','-e',"const fs=require('fs');for(const p of process.argv.slice(1))new Function(fs.readFileSync(p,'utf8'));",*[str(p) for p in js]],check=True)
print(json.dumps({'package_files':count,'javascript_files':len(js),'individual_features':len(catalog['features']) if catalog else 0,'missing_links':missing,'result':'PASS'},ensure_ascii=False))
