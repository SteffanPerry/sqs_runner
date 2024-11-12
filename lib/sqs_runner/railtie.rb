require 'rails/railtie'

module SqsRunner
  class Railtie < Rails::Railtie
    # Define configuration defaults
    config.sqs_runner             = ::ActiveSupport::OrderedOptions.new
    config.sqs_runner.queues      = ['default']
    config.sqs_runner.aws_region  = 'us-east-1'

    # Run code during initialization
    initializer 'sqs_runner.setup' do |app|
      if app.config.sqs_runner.aws_region
        ::Aws.config.update(region: app.config.sqs_runner.aws_region)
      end
    end

    initializer 'sqs_queue.configure' do |app|
      ::SqsRunner.configuration ||= ::SqsRunner::Configuration.new
      yaml_file = Rails.root.join('config', 'sqs_queues.yml')
      ::SqsRunner.configuration.load_yaml(yaml_file) if ::File.exist?(yaml_file)
    end
  end
end
