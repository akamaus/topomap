require 'sitemapper'

require 'rgl/dot'


if ARGV.size == 1 then
  s = SiteMapper.new(ARGV[0])

  sitemap = s.run
  sitemap.write_to_graphic_file('png',s.site.host)
else
  puts "run with site url as argument"
end
