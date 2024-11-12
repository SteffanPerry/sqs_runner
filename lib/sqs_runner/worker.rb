require 'aws-sdk-sqs'
require 'json'
require 'thread'
require 'rails'

module SqsRunner
  class Worker
    attr_reader :queues, :threads_count, :running, :queue_urls, :manager_pid
    attr_accessor :sqs, :threads

    def initialize(queues, thread_count = 5, manager_pid)
      @queues         = queues
      @threads_count  = thread_count
      @manager_pid    = manager_pid
      @sqs            = ::Aws::SQS::Client.new
      @running        = true
      @queue_urls     = ::SqsRunner.configuration.queue_urls
      @threads        = []
    end

    def start
      manager_checker
      trap_signals
      start_threads
    end

    def stop
      puts "Stopping worker..."
      shutdown!
    end

    protected

    def start_threads
      threads_count.times do |_|
        threads << ::Thread.new do
          work_loop
        end
      end
      threads.each(&:join)
    end

    def work_loop
      loop do
        break unless running

        queues.each do |queue|
          running ? run_queue(queue) : break
        rescue => e
          puts "Error processing queue '#{queue.name}': #{e.message}"
        end
      end
    end

    private

    def run_queue(queue)
      messages  = queue.fetch_messages
      return if messages.empty?

      messages.each do |message|
        process_message(message, queue_url)
      end
    end

    def get_queue_url(queue_name)
      @queue_urls[queue_name.to_s] || raise("Queue URL not found for queue '#{queue_name}'")
    end

    def fetch_messages(queue_url)
      response = @sqs.receive_message(
        queue_url: queue_url,
        max_number_of_messages: 10,
        wait_time_seconds: 20 # Enable long polling
      )
      response.messages
    end

    def process_message(message, queue_url)
      begin
        job_data = JSON.parse(message.body)
        # Implement your job processing logic here
        puts "Processing job from queue #{queue_url} in process #{Process.pid}, thread #{Thread.current.object_id}"
        
        klass = job_data['class'].constantize
        klass.new.perform(*job_data['args'])

        # Delete the message upon successful processing
        @sqs.delete_message(
          queue_url: queue_url,
          receipt_handle: message.receipt_handle
        )
      rescue StandardError => e
        puts "Error processing message: #{e.message}"
        # Optionally implement retry logic or move message to a dead-letter queue
      end
    end

    def trap_signals
      Signal.trap('INT') { shutdown! }
      Signal.trap('TERM') { shutdown! }
    end

    def shutdown!
      @running = false
      shutdown_at = Time.now + shutdown_timeout
      puts "Waiting up to #{shutdown_timeout} seconds for threads to finish..."
      loop do
        break if Time.now > shutdown_at || threads.all?(&:stop?)

        if shutdown_at >= Time.now
          threads.each(&:exit)
        else
          sleep(1)
        end
      end
    end

    # Dont allow the workers to run orphaned if the manager has died
    def monitor
      loop do
        break unless running

        begin
          ::Process.getpgid(manager_pid)
          puts thread_stats
          sleep(5)
        rescue Errno::ESRCH
          puts "Manager process #{manager_pid} died, shutting down worker..."
          shutdown!
        end
      end
    end

    def thread_stats
      {
        job_completed: threads.map(&:job_completed).sum,
        job_failed: threads.map(&:job_failed).sum,
        current_jobs: threads.{ |thr| { id: thr.object_id, current_job: thr.current_job } }
      }
    end
  end
end
