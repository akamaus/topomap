require 'sitemapper'

if ARGV.size == 1 then
  s = SiteMapper.new(ARGV[0])
  s.run
else
  puts "run with site url as argument"
end
