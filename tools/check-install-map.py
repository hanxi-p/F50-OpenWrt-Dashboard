"""Read-only install/restore coverage checks; no device configuration changes."""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
dash=root/'extras/dashboard'
source=(dash/'install.sh').read_text(encoding='utf-8')
backups=set(re.search(r"<<'PATHS'\n(.*?)\nPATHS",source,re.S)[1].splitlines())
rows=re.search(r"done <<'FILES'\n(.*?)\nFILES",source,re.S)[1].splitlines()
mapping=[]
for row in rows:
 fields=row.split();assert len(fields)==2,row
 name,target=fields
 assert target.startswith('/') and target in backups,(name,target)
 assert (dash/name).is_file() or name=='device-traffic/flow-account',name
 mapping.append((name,target))
assert len({t for _,t in mapping})==len(mapping),'duplicate destination'
assert '/etc/f50-devices/ledger.json' not in backups
assert '/etc/f50-devices/aliases.json' not in backups
assert 'if [ -z "$(uci -q get luci.sauth.sessiontime)" ]; then' in source
assert '(cd device-traffic && sha256sum -c SHA256SUMS.local' in source
assert 'f50devices.js /www/luci-static/resources/f50devices.js' in source
restore=(dash/'restore.sh').read_text(encoding='utf-8')
assert restore.count('for service in f50-devices ')==2
assert source.index('/etc/init.d/f50-devices stop')<source.index("done <<'FILES'")
assert '/etc/init.d/f50-devices enable' in source
assert '/etc/init.d/f50-devices start' in source
print(json.dumps({'install_mappings':len(mapping),'backup_coverage':'PASS','history_not_overwritten_by_restore':True,'session_setting_preserved':True}))
