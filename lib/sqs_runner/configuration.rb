require 'yaml'

module SqsRunner
  class Configuration
    attr_accessor :queue_urls

    def initialize
      @queue_urls = {}
    end

    def load_yaml(file_path)
      config      = YAML.load_file(file_path)
      environment = Rails.env
      @queue_urls = config[environment] || {}
    end
  end
end
