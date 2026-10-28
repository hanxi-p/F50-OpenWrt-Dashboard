"""Read-only comparison with the selected SSH host; prints no device data."""
from pathlib import Path
import argparse,hashlib,re,subprocess,json
p=argparse.ArgumentParser();p.add_argument('--host',default='f50');args=p.parse_args()
assert not args.host.startswith('-')
root=Path(__file__).resolve().parents[1];dash=root/'extras/dashboard'
s=(dash/'install.sh').read_text(encoding='utf-8')
rows=[line.split() for line in re.search(r"done <<'FILES'\n(.*?)\nFILES",s,re.S)[1].splitlines()]
assert all(len(row)==2 and re.fullmatch(r'/[A-Za-z0-9_./-]+',row[1]) for row in rows)
out=subprocess.run(['ssh',args.host,'sha256sum '+' '.join(row[1] for row in rows)],capture_output=True,text=True,encoding='utf-8',check=True).stdout
remote={name:digest for digest,name in (line.split(None,1) for line in out.splitlines())}
bad=[]
for source,target in rows:
 local=dash/source
 if not local.is_file():bad.append({'source':source,'reason':'prepare local build first'});continue
 if hashlib.sha256(local.read_bytes()).hexdigest()!=remote.get(target):bad.append({'source':source,'target':target})
print(json.dumps({'mapped':len(rows),'matched':len(rows)-len(bad),'mismatches':bad},ensure_ascii=False))
raise SystemExit(bool(bad))
