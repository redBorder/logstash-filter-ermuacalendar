require "logstash/filters/base"
require "logstash/namespace"
require 'rss'

class LogStash::Filters::RSS < LogStash::Filters::Base

  config_name "rss"

  config :file, :validate => :string, :required => true
  config :rss_ttl, :validate => :number, :required => true
  config :target, :validate => :string, :default => "rss_event_name"
  config :path, :validate => :string, :default => "rss_event_path"

  public
  def register
    @logger.info("Registering RSS filter", :file => @file)
    @calendar = nil

    Thread.new do
      loop do
        read_calendar
        sleep @rss_ttl
      end
    end
  end

  private

  def handle_response(response)
    body = response
    begin
      feed = RSS::Parser.parse(body)
      @calendar = feed
    rescue RSS::MissingTagError => e
      @logger.error("Invalid RSS feed", :exception => e)
    rescue => e
      @logger.error("Unknown error while parsing the feed", :file => @file, :exception => e)
    end
  end

  def read_calendar
    begin
      @logger.info "Downloading RSS"
      response = `curl #{@file}`
      handle_response(response) unless response.empty?
    rescue => e
      @logger.error("Error fetching RSS feed", :exception => e)
    end
  end

  def event_name_by_date(date)
    return unless @calendar

    date = Time.at(date)
    @calendar.items.each do |item|
      pub_date = item.pubDate
      end_date = pub_date + 1 * 24 * 60 * 60
      return item.title if date.between?(pub_date, end_date)
    end

    nil
  end

  public
  def filter(event)
    date = event.get('timestamp')
    name = event_name_by_date(date)
    event.set(@target, name)

    filter_matched(event)
  end
end
