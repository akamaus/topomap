# -*- coding: utf-8 -*-
require 'rubygems'

require 'rainbow'

require 'robots'
require 'hpricot'

require 'uri'
require 'net/http'
require 'http_encoding_helper'

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

  def to_s
    self.location
  end

  attr_reader :path
  attr_reader :query
end

class MyHTTP
  def initialize(host, port)
    @host = host
    @port = port

    @http = nil
  end

  private

  def MyHTTP.make_tries(name)
    define_method("try_" + name) { |*args|
      res = nil
      sleep_time = 1
      tries = 0;
      while true:
        begin
          tries = tries + 1
          if @http.nil?
            @http = Net::HTTP.start(@host,@port)
          end
          res = @http.send(name, *args)
          break
        rescue StandardError,Timeout::Error  => err
          puts (("Error occured: " + err.inspect + "; sleeping #{sleep_time}").color(:red))
          sleep sleep_time
          sleep_time *= 2
          @http = nil
        end
      end
      if res.nil?
        throw "several tries were unsuccessful"
      else
        res
      end
    }
  end

  make_tries("request_get")
  make_tries("request_head")
end


class SiteMapper
  def initialize(site)
    @site = URI::parse(site).normalize
    @sitemap = RGL::DirectedAdjacencyGraph.new

    @http = MyHTTP.new(@site.host, @site.port)

    @robots = Robots.new "Yandex"
  end

  def run
    unvisited = Set[SiteUri.new(@site)]
    visited = Set[]

    headers={'Accept-Encoding' => 'gzip, deflate'}

    until unvisited.empty?
      s = unvisited.first
      puts "visited: #{visited.size}; unvisited: #{unvisited.size} pages; visiting #{s.location}"
      res = @http.try_request_get(s.location, headers)
      case res
      when Net::HTTPSuccess
      else
        puts "got response code #{res.code}".color(:yellow)
        visited << s
        unvisited.delete s
      end
      links = parse_page(res.plain_body)
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
                         res = @http.try_request_head(site_t.location)
                         cont = res.header.content_type
                         queries = queries + 1
                         case res
                         when Net::HTTPClientError then
                           puts "Broken link: #{site_t.location} on page #{s.location}".color(:red)
                           false
                         else
                           if cont == "text/html" || cont == "text/xml" then true
                           else puts "strange content type: #{cont} on link #{site_t.location}".color(:red)
                             false
                           end
                         end
                       end

        if is_page_link
          @sitemap.add_edge(s,site_t)
          unless visited.include? site_t
            if unvisited.add? site_t
              added = added + 1
            end
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
