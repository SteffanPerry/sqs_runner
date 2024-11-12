module SqsRunner
  class MissingConfiguration < StandardError; end
  class QueueNotFound < StandardError; end

  class Queue
    def self.configuration
      @@configuration ||= begin
        config = YAML.load_file(Rails.root.join('config', 'sqs_runner.yml'))
        config[Rails.env.to_s]
      end
    end

    def self.client
      @@client ||= ::Aws::SQS::Client.new
    end

    attr_reader :name, :options

    def initialize(name)
      @name     = name
      @options  = load_configuration
    end

    def fetch_messages(count = 10)
      client = self.class.client
      client.receive_message(queue_url: url, max_number_of_messages: count).messages
    rescue Aws::SQS::Errors::NonExistentQueue
      raise ::SqsRunner::QueueNotFound, "Queue Nout Found: '#{name}'"
    end

    def url
      @options[:url]
    end

    def type
      @options[:type]
    end

    def fifo?
      @options[:fifo]
    end

    def weight
      @options[:weight]
    end

    private

    def load_configuration
      config = queue_config

      config.tap do |hash|
        hash[:type]   = (config[:type] || :active_job).to_sym
        hash[:fifo]   = config[:url].end_with?('.fifo')
        hash[:weight] = [config[:weight].to_i, 1].max
      end
    end

    def queue_config
      config = self.class.configuration[name]
      raise ::SqsRunner::MissingConfiguration, "Queue Nout Found: '#{name}'" unless config

      config = { url: config } if config.is_a?(String)
      config.symbolize_keys
    end
  end
end
