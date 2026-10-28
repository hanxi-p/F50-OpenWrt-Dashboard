require 'yaml'
path=ARGV.fetch(0)
abort 'unexpected configuration path' unless path.start_with?('/etc/openclash/')
text=File.read(path);c=YAML.load(text)
proxy_names=Array(c['proxies']).select{|v|v['type'] && !%w[direct reject reject-drop pass].include?(v['type'].downcase)}.map{|v|v['name']}
preferred=YAML.load_file('/etc/mu300/bark/preferred-nodes.json') rescue []
nodes=((Array(preferred)&proxy_names)+proxy_names).uniq
abort 'no outbound proxies' if nodes.empty?
before=Marshal.load(Marshal.dump(c));groups=Array(c['proxy-groups']).reject{|g|g['name']=='F50 Bark'}
rules=Array(c['rules']).reject{|r|r=='DOMAIN,api.day.app,F50 Bark'}
groups.unshift({'name'=>'F50 Bark','type'=>'fallback','proxies'=>nodes,'url'=>'https://api.day.app/ping','interval'=>600,'lazy'=>true})
rules.unshift('DOMAIN,api.day.app,F50 Bark')
c['proxy-groups']=groups;c['rules']=rules
# This optional hook only owns the named Bark group and its exact-domain rule.
check=Marshal.load(Marshal.dump(c));old=Marshal.load(Marshal.dump(before))
[check,old].each{|v|v['proxy-groups']=Array(v['proxy-groups']).reject{|g|g['name']=='F50 Bark'};v['rules']=Array(v['rules']).reject{|r|r=='DOMAIN,api.day.app,F50 Bark'}}
abort 'unrelated settings changed' unless check==old
out=YAML.dump(c);abort 'roundtrip failed' unless YAML.load(out)==c
File.write(path+'.bark-tmp',out);File.chmod(0600,path+'.bark-tmp');File.rename(path+'.bark-tmp',path)
