require 'yaml'
path=File.realpath(ARGV.fetch(0));st=File.lstat(path)
allowed=path.start_with?('/etc/openclash/') || (path.start_with?('/tmp/') && path.match?(/\.ya?ml\z/))
abort 'unsafe configuration input' unless allowed && st.file? && st.uid==0 && (st.mode & 0022)==0
settings=YAML.load_file(ARGV[1] || '/etc/mu300/network-recovery.json')
c=YAML.load_file(path);before=Marshal.load(Marshal.dump(c));groups=Array(c['proxy-groups'])
main=groups.find{|g|g['name']==settings.fetch('main_group') && g['type']=='select'}
active=groups.find{|g|g['name']==settings.fetch('fallback_group') && g['type']=='fallback'}
abort 'selected recovery groups missing' unless main && active
# Membership and region restrictions are owned by the existing subscription hook.
preferred=settings.fetch('preferred_proxy')
abort 'approved recovery pool empty' if Array(active['proxies']).empty?
preferred=active['proxies'].first unless active['proxies'].include?(preferred)
active['proxies']=[preferred]+active['proxies'].reject{|n|n==preferred}
groups.each do |g|
 next unless %w[url-test fallback].include?(g['type'])
 g['interval']=settings.fetch('passive_interval',120);g['timeout']=3000;g['max-failed-times']=2;g['lazy']=true
end
active['url']='https://www.gstatic.com/generate_204';active['expected-status']=204
active['interval']=settings.fetch('probe_interval',30);active['lazy']=false
main['proxies']=[active['name']]+Array(main['proxies']).reject{|n|n==active['name']}
c['profile']||={};c['profile']['store-selected']=true
# Nothing outside health parameters, ordering and the default menu item may change.
check=Marshal.load(Marshal.dump(c));before.key?('profile') ? check['profile']=before['profile'] : check.delete('profile');check['proxy-groups']=before['proxy-groups']
abort 'unrelated settings changed' unless check==before
before_groups=Array(before['proxy-groups'])
groups.each do |g|
 original=before_groups.find{|x|x['name']==g['name']};abort 'group membership changed' unless Array(g['proxies']).sort==Array(original['proxies']).sort
end
out=YAML.dump(c);abort 'YAML roundtrip failed' unless YAML.load(out)==c
tmp=path+".recovery-#{Process.pid}-#{rand(1<<30)}"
begin
 File.open(tmp,File::WRONLY|File::CREAT|File::EXCL,0600){|f|f.write(out);f.flush;f.fsync}
 File.rename(tmp,path)
ensure
 File.unlink(tmp) if File.exist?(tmp)
end
