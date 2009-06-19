require 'rubygems'

require 'open-uri'
require 'hpricot'

require 'uri'

require 'rgl/adjacency'

class SiteMapper
  attr_reader :site
  attr_reader :sitemap

  def initialize(site)
    @site = URI::parse(site).normalize
    @sitemap = RGL::DirectedAdjacencyGraph.new
  end

  def run
    unvisited = Set[@site]
    visited = Set[]
    until unvisited.empty?
      s = unvisited.first
      puts "unvisited: #{unvisited.size} pages;  visiting #{s}"
      links = parse_page(s)
      puts "found #{links.size} links"
      links.each { |t|
        @sitemap.add_edge(s,t)
        unvisited << t unless visited.include?(t) || (@site.host != t.host)
      }
      visited << s
      unvisited.delete s
    end
    @sitemap
  end

  def parse_page(page)
    urls = []
    doc = Hpricot(open(page))

    doc.search('a').each { |a|
      begin
        u = URI::parse(a['href'])
        if u.relative? then
          u = @site.merge(u).normalize
        end
        urls << u
      rescue URI::InvalidURIError
        nil
      end
    }
    urls
  end

end
