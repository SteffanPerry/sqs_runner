require 'aws-sdk-sqs'
require 'json'

module SqsRunner
  class Job
    def initialize
      @sqs        = ::Aws::SQS::Client.new
      @queue_urls = ::SqsRunner.configuration.queue_urls
    end

    def enqueue(queue_name, job_data)
      queue_url     = get_queue_url(queue_name)
      message_body  = job_data.to_json

      @sqs.send_message(queue_url:, message_body:)
    end

    private

    def get_queue_url(queue_name)
      @queue_urls[queue_name.to_s] || raise("Queue URL not found for queue '#{queue_name}'")
    end
  end
end
