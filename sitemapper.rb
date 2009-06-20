# -*- coding: utf-8 -*-
require 'rubygems'

require 'robots'

require 'hpricot'

require 'uri'
require 'net/http'

require 'rgl/adjacency'

class SiteUri
  def initialize(site)
    @path = site.path
    @query = site.query
  end

  def ==(uri2)
    @path == uri2.path && @query == uri2.query
  end

  def eql?(uri2)
    self.class == uri2.class && self == uri2
  end

  def hash
    self.location.hash
  end

  def location
    if @query.nil? then
      @path
    else
      @path + "?" + @query
    end
  end

  attr_reader :path
  attr_reader :query
end

class SiteMapper
  def initialize(site)
    @site = URI::parse(site).normalize
    @sitemap = RGL::DirectedAdjacencyGraph.new

    @http = Net::HTTP.start(@site.host, @site.port)

    @robots = Robots.new "Yandex"
  end

  def run
    unvisited = Set[SiteUri.new(@site)]
    visited = Set[]
    until unvisited.empty?
      s = unvisited.first
      puts "unvisited: #{unvisited.size} pages;  visiting #{s.location}"
      res = @http.request_get(s.location)
      case res
      when Net::HTTPSuccess
      else
        throw "got response code #{res.code}"
      end
      links = parse_page(res.body)
      puts "found #{links.size} links"
      queries = 0 # количество head запросов
      added = 0
      # пробегаемся по ссылкам
      links.each { |t|
        site_t = SiteUri.new(t)
        if @site.host != t.host # наружу пока не ходим
          next
        end
        if ! @robots.allowed?(t) # уважаем robots.txt
          next
        end
        is_page_link = if @sitemap.has_vertex? site_t then true # старые ссылки можно не прозванивать
                       else
                         puts "requesing head " + t.to_s
                         cont = @http.request_head(site_t.location).header.content_type
                         queries = queries + 1
                         if cont == "text/html" || cont == "text/xml" then true
                         else puts "strange content type"
                           false
                         end
                       end

        if is_page_link
          @sitemap.add_edge(s,site_t)
        end

        unless visited.include? site_t
          if unvisited.add? site_t
            added = added + 1
          end
        end
      }
      puts "made #{queries} HEAD queries; added #{added} vertices"
      visited << s
      unvisited.delete s
    end
    @sitemap
  end

  def parse_page(body)
    urls = []
    doc = Hpricot(body)

    doc.search('a').each { |a|
      begin
        u = URI::parse(a['href']).normalize
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

  attr_reader :site
  attr_reader :sitemap
end
