#!/usr/bin/env ruby -wKU
require 'rss/2.0'
require 'nokogiri'
require 'open-uri'
require 'text'
require 'pp'
require 'erubis'

class NetflixTrailers
  QUEUE_URL_BASE = "http://rss.netflix.com/QueueEDRSS?id="
  INSTANT_PLAY_URL_BASE = "http://www.netflix.com/WiPlayer?movieid="
  APPLE_URL = "http://trailers.apple.com/trailers/home/xml/widgets/indexall.xml"
  
  def initialize(api)
    @queue_url = QUEUE_URL_BASE + api
  end
  
  def get_queue(url)
    titles = {}
    open(url) do |rss|
      RSS::Parser.parse(rss, false).items.each do |item|
        if item.title =~ /^\d.+-\s(.+)/
          titles[$1] = item.link.split('/').last
        end
      end
    end
    titles
  end
  
  def get_trailers(url)
    doc = Nokogiri::XML(open(url))
    trailers = {}
    doc.xpath("//movieinfo").each do |film|
      trailers[film.xpath("info/title").text] = film.xpath("previews/preview[@type='medium']").text
    end
    trailers
  end
  
  def get_netflix_trailers
    titles = get_queue(@queue_url)
    movies = get_trailers(APPLE_URL)
    netflix_trailers = titles.map {|title, id| {:instant_play_url => INSTANT_PLAY_URL_BASE + id, :trailer_url => movies.fetch(title)  {|t| movies[find_closest_key(movies.keys, t)]}}}
    netflix_trailers.delete_if {|i| i[:trailer_url].nil?}
  end  
  
  def find_closest_key(keys, title)
    closest = keys.collect {|key| [key, title, Text::Levenshtein.distance(key, title)]}.sort {|x,y| x[2] <=> y[2]}[0]
    closest[2] < 2 ? closest[0] : nil
  end
  
  def build_page
    trailers = get_netflix_trailers
    template  = File.read('template.eruby')
    eruby = Erubis::Eruby.new(template)
    eruby.result(:trailers => trailers)
  end
end

netflix = NetflixTrailers.new(ARGV[0])
puts netflix.build_page