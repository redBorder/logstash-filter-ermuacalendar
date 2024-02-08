require "logstash/filters/base"
require "logstash/namespace"

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
    @calendar = body
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

    closest_event = nil
    closest_time_difference = Float::INFINITY

    @calendar.each do |item|
      pub_date = Time.at(item["field_fecha_inicio"].first["value"])
      end_date = Time.at(item["field_fecha_fin"].first["value"])

      if date.between?(pub_date, end_date)
        time_difference = (date - pub_date).abs
        if time_difference < closest_time_difference
          closest_event = item["title"].first["value"]
          closest_time_difference = time_difference
        end
      end
    end

    closest_event
  end

  public
  def filter(event)
    date = event.get('timestamp')
    name = event_name_by_date(date)
    event.set(@target, name)

    filter_matched(event)
  end
end
