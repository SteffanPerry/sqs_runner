require 'sqs_runner/active_job_adapter'
require 'sqs_runner/client'
require 'sqs_runner/configuration'
require 'sqs_runner/job'
require 'sqs_runner/queue'
require 'sqs_runner/worker'
require 'sqs_runner/manager'
require 'sqs_runner/cli'
require 'sqs_runner/railtie' if defined?(::Rails::Railtie)

module SqsRunner
  class << self
    attr_accessor :configuration
  end
end
