#!/usr/bin/env python3
"""Optional, narrow adapter for an existing F50-style WAN include.

Use separate input/output files; back up the installed file before deploying.
No network access and no change to the collector, counters, or chart itself.
"""
import argparse, pathlib
p=argparse.ArgumentParser()
p.add_argument('input',type=pathlib.Path)
p.add_argument('output',type=pathlib.Path)
a=p.parse_args()
assert a.input.resolve()!=a.output.resolve(), 'Keep the original as a backup'
source=a.input.read_text(encoding='utf-8')
guard='if (this.root && document.documentElement.contains(this.root)) return null;'
needle='\trender: function(raw) {\n\t\tthis.dispose();'
if guard not in source:
    assert source.count(needle)==1, 'Unsupported legacy include: do not guess'
    source=source.replace(needle,'\trender: function(raw) {\n\t\t'+guard+'\n\t\tthis.dispose();')
a.output.write_text(source,encoding='utf-8',newline='\n')
