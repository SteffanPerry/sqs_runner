module SqsRunner
  class Processor
    attr_reader :message, :queue

    def initialize(message, queue)
      @message  = message
      @queue    = queue
    end

    def call
      is_event? ? process_event : process_message
    end

    protected

    # Event messages process raw sqs messages
    # an event queue is tied to a worker 1:1
    def process_event
      event_klass = queue.event_klass
      event_klass.new(message:).perform
      delete_message
    rescue => e
      puts "Error processing event '#{queue.name}': #{e.message}"
    end

    def process_message
      message_klass = message.job_klass
      job
      message_klass.new(me
      delete_message
    rescue => e
      puts "Error processing message '#{queue.name}': #{e.message}"
    end

    private

    def is_event?
      queue.job_type == :event
    end
  end
end