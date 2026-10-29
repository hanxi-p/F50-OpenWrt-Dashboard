#!/usr/bin/env python3
"""Build a small static collector and a checksummed, deterministic offline bundle."""
import argparse, gzip, hashlib, io, json, pathlib, struct, subprocess, tarfile, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
compiler=p.add_mutually_exclusive_group(required=True)
compiler.add_argument('--zig', help='Zig 0.13+ executable')
compiler.add_argument('--reuse-archive',type=pathlib.Path,help='Reuse an already built binary only when its source hash matches exactly')
p.add_argument('--output', required=True, type=pathlib.Path)
p.add_argument('--target', default='aarch64-linux-musl')
args = p.parse_args()
args.output = args.output.resolve()
args.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='routertraffic-build-', dir=args.output.parent) as work:
    binary = pathlib.Path(work) / 'flow-account'
    reused=None
    if args.reuse_archive:
        with tarfile.open(args.reuse_archive) as previous:
            provenance=json.load(previous.extractfile('bin/build.json'))
            compiled=previous.extractfile('bin/flow-account').read()
        assert provenance['source_sha256']==hashlib.sha256((ROOT/'native/flow-account.c').read_bytes()).hexdigest(), 'Native source changed; rebuild required'
        assert provenance['binary_sha256']==hashlib.sha256(compiled).hexdigest() and provenance['target']==args.target
        binary.write_bytes(compiled)
        version=provenance['compiler'].removeprefix('zig ')
        reused=hashlib.sha256(args.reuse_archive.read_bytes()).hexdigest()
    else:
        version = subprocess.check_output([args.zig, 'version'], text=True).strip()
        subprocess.run([args.zig, 'cc', '-target', args.target, '-O2', '-s', str(ROOT/'native/flow-account.c'), '-o', str(binary)], check=True)
    data = binary.read_bytes()
    assert data[:4] == b'\x7fELF' and data[4:6] == b'\x02\x01', 'Expected little-endian ELF64'
    # A static aarch64 executable needs neither a matching libc nor kernel module ABI.
    assert struct.unpack_from('<H', data, 18)[0] == 183, 'Current bundle installer supports aarch64 only'
    offset = struct.unpack_from('<Q', data, 32)[0]
    entry_size, count = struct.unpack_from('<HH', data, 54)
    assert all(struct.unpack_from('<I', data, offset+i*entry_size)[0] != 3 for i in range(count)), 'Unexpected dynamic interpreter'
    files = {}
    for f in sorted(ROOT.rglob('*')):
        if f.is_file() and '__pycache__' not in f.parts and f.suffix != '.pyc' and f.name != 'MANIFEST.sha256':
            assert f.suffix not in ('.ko', '.key', '.private'), f
            files[f.relative_to(ROOT).as_posix()] = f.read_bytes()
    files['bin/flow-account'] = data
    files['bin/build.json'] = (json.dumps({'compiler':'zig '+version,'target':args.target,'source_sha256':hashlib.sha256((ROOT/'native/flow-account.c').read_bytes()).hexdigest(),'flags':['-O2','-s'],'binary_sha256':hashlib.sha256(data).hexdigest(),'reused_archive_sha256':reused}, indent=2)+'\n').encode()
    files['MANIFEST.sha256'] = ''.join(hashlib.sha256(value).hexdigest()+'  '+name+'\n' for name,value in sorted(files.items())).encode()
    with args.output.open('wb') as output, gzip.GzipFile(fileobj=output, mode='wb', mtime=0) as compressed, tarfile.open(fileobj=compressed, mode='w') as tar:
        for name, value in sorted(files.items()):
            entry = tarfile.TarInfo(name)
            entry.size, entry.mtime, entry.uid, entry.gid = len(value), 0, 0, 0
            entry.uname = entry.gname = 'root'
            entry.mode = 0o755 if name.endswith('.sh') or name in ('app/service','app/rpc-wrapper','bin/flow-account') else 0o644
            tar.addfile(entry, io.BytesIO(value))
digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
args.output.with_name(args.output.name+'.sha256').write_text(digest+'  '+args.output.name+'\n', encoding='ascii')
print(json.dumps({'output':str(args.output),'sha256':digest,'bytes':args.output.stat().st_size}))
