"""Test the actual worker awk program without emitting any system log messages."""
from pathlib import Path
import re, subprocess, tempfile, shutil, json

root=Path(__file__).resolve().parents[1]
worker=(root/'extras/dashboard/f50-diagnostics-worker').read_text(encoding='utf-8')
program=re.search(r"   awk '\n(.*?)    }' <",worker,re.S)
assert program, 'worker awk program not found'
awk=shutil.which('awk')
if not awk and Path('C:/Program Files/Git/usr/bin/awk.exe').exists():
    awk='C:/Program Files/Git/usr/bin/awk.exe'
assert awk, 'awk is required'
cases=[
    (['kernel: WCN PCIEWARN edma_pending_q_buffer(10) full'],True),
    (['kernel: sprd-wlan: sc2355_pcie_push_link: push link fail: -1, chn: 10!'],True),
    (['kernel: sprd-wlan: tx_handle_to_send_list, 345: tx return err!'],True),
    (['kernel: sprd-wlan: SPRD_CMD_STATUS_ERROR'],True),
    (['kernel: sipa_eth: fail to send ret -115'],True),
    (['kernel: ordinary DEBUG: trace','kernel: ordinary traffic'],False),
    (['kernel: sprd-wlan: incoming ARP packet'],False),
    (['kernel: Kernel panic - not syncing','kernel: stack frame'],True),
    (['kernel: kernel panic - not syncing','kernel: stack frame'],True),
    (['kernel: BUG: real fault','kernel: stack frame'],True),
    (['kernel: Out of memory: Killed process'],True),
]
with tempfile.TemporaryDirectory() as directory:
    p=Path(directory)/'filter.awk';p.write_text(program[1]+'    }\n',encoding='utf-8')
    def run(lines):
        result=subprocess.run([awk,'-f',str(p)],input=('\n'.join(lines)+'\n').encode(),capture_output=True,check=True)
        return result.stdout.decode().splitlines()
    for _ in range(3):
        for lines,keep in cases:
            assert run(lines)==(lines if keep else []),lines
        context=['kernel: BUG: bounded context']+['kernel: frame '+str(i) for i in range(100)]
        assert run(context)==context[:96]
        assert run(['kernel: DEBUG: no fault']+['kernel: ordinary traffic']*1000)==[]
print(json.dumps({'filter_scenarios':len(cases)+2,'rounds':3,'result':'PASS'}))
