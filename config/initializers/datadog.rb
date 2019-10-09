require 'ddtrace'

Datadog.configure do |c|
  service_name = 'ddog'
  # service_name = Settings.DATADOG_SERVICE_NAME
  # https://docs.datadoghq.com/tracing/trace_search_and_analytics/?tab=ruby#automatic-configuration
  # enable trace analytics (extra costs?)
  c.analytics_enabled = true
  c.tracer hostname: 'localhost'
  # case Settings.HOST
  # when 'staging5.babylist.com'
  #   # debug mode on staging5
  #   c.tracer debug: true, hostname: Socket.gethostname, log: Logger.new(File.new('log/datadog.log', 'w+'))
  # else
  #   c.tracer hostname: Socket.gethostname
  # end
  # https://docs.datadoghq.com/tracing/setup/ruby/#rails
  # https://docs.datadoghq.com/logs/log_collection/ruby/
  # http://gems.datadoghq.com/trace/docs/#nethttp
  # manually set env (vs in agent conf if different for all host's instances)
  # c.tracer tags: { 'env' => 'prod' }
  c.use :rails, service_name: service_name, database_service: "#{service_name}-active_record"
  # c.use :redis, service_name: "#{service_name}-redis"
  # c.use :sidekiq, client_service_name: "#{service_name}-sidekiq-client", service_name: "#{service_name}-sidekiq-worker", analytics_enabled: true
  # c.use :dalli, service_name: "#{service_name}-memcached"
  # c.use :rake, service_name: "#{service_name}-rake"

  # http://gems.datadoghq.com/trace/docs/#Processing_Pipeline
  # filter verbose and useless controller trace
  Datadog::Pipeline.before_flush(
    # https://github.com/DataDog/dd-trace-rb/blob/master/lib/ddtrace/span.rb
    # span.name == "rack.request" && span.get_tag("http.url") == "/xxx"
    # ignore verbose AppleAppSiteAssociationController
    Datadog::Pipeline::SpanFilter.new { |span| span.resource =~ /AppleAppSiteAssociationController/ },

    # ignore 503 (rack attack)
    Datadog::Pipeline::SpanFilter.new { |span| span.get_tag('http.status_code') == '503' },

    # ignore ErrorsController as the origin controller will also emit request log
    Datadog::Pipeline::SpanFilter.new { |span| span.resource =~ /ErrorsController/ },

    # ignore "normal" errors ... this is mainly to address ddog agent not ignoring
    # raised exceptions that are later rescued via rescue_from (e.g. gift_tracker)
    # Datadog::Pipeline::SpanFilter.new do |span|
    #   [BLRegistry::User::NotAuthorized, BLRegistry::User::Forbidden, ActiveRecord::RecordNotFound].map(&:name).include?(span.get_tag('error.type'))
    # end,

    # debug dup rack request APM
    # Datadog::Pipeline::SpanFilter.new { |span| Rails.logger.info "#{span.to_hash}" if span.name == 'rack.request'; false },
    # Datadog::Pipeline::SpanFilter.new { |span| Rails.logger.info "#{span.to_hash}" if span.name == 'rails.action_controller'; false },
  )
end
# end unless Settings.DATADOG_SERVICE_NAME.nil? # disable APM trace unless we have a service name (prod && staging5)
# alternative filter...
# Rails.env.test? || Rails.env.development? || (Rails.env.staging? && ENV['APP_INSTANCE'] != 'staging5' )
