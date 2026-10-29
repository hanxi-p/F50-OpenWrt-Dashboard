#!/usr/bin/ruby
# Missing optional scheduler flags are disabled; keep the user's UCI untouched.
path = ARGV[0] || '/etc/init.d/openclash'
original = File.binread(path)
patched = original.dup
%w[geo_auto_update geosite_auto_update geoip_auto_update geoasn_auto_update chnr_auto_update auto_restart].each do |key|
  old = %Q{"$(uci_get_config "#{key}")" -eq 1}
  new = %Q{"$(uci_get_config "#{key}" || echo 0)" -eq 1}
  raise "Unsupported OpenClash condition: #{key}" unless patched.scan(old).length + patched.scan(new).length == 1
  patched = patched.sub(old, new)
end
if patched != original
  backup = "#{path}.f50-before-defaults-#{Time.now.to_i}-#{Process.pid}"
  File.binwrite(backup, original)
  File.chmod(File.stat(path).mode & 0777, backup)
  temp = "#{path}.f50-defaults-new-#{Process.pid}"
  File.binwrite(temp, patched)
  File.chmod(File.stat(path).mode & 0777, temp)
  File.rename(temp, path)
end
puts 'OpenClash optional scheduler defaults checked'
