require "logstash/filters/base"
require "logstash/namespace"
require "json"

class LogStash::Filters::ErmuaCalendar < LogStash::Filters::Base

  config_name "ermuacalendar"

  config :url, :validate => :string, :required => true
  config :calendar_ttl, :validate => :number, :required => true
  config :target, :validate => :string, :default => "calendar_item_name"

  public
  def register
    @logger.info("Registering ERMUA Calendar filter", :url => @url)
    @calendar = nil

    Thread.new do
      loop do
        read_calendar
        sleep @calendar_ttl
      end
    end
  end

  private

  def handle_response(response)
    body = response
    @calendar = JSON.load(body)
  end

  def read_calendar
    begin
      @logger.info "Downloading ERMUA Calendar"
      response = `curl #{@url}`
      handle_response(response) unless response.empty?
    rescue => e
      @logger.error("Error fetching ERMUA Calendar feed", :exception => e)
    end
  end

  def event_name_by_date(date)
    return unless @calendar

    date = Time.at(date)

    event = ""

    @calendar.each_with_index do |item, index|
      pub_date = Time.at(Time.parse(item["field_fecha_inicio"].first["value"]))
      end_date = Time.at(Time.parse(item["field_fecha_fin"].first["value"]))

      if date.between?(pub_date, end_date)
        event += item["title"].first["value"].gsub(";","").strip
        event += "; "
      end
    end
    event = event.sub(/; \z/, '')
    event
  end

  public
  def filter(event)
    date = event.get('timestamp')
    name = event_name_by_date(date)
    event.set(@target, name)

    filter_matched(event)
  end
end
