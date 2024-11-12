module SqsRunner
  class EventJob
    attr_reader :records, :queue
    attr_writer :failure_visibility_timeout

    def initialize(records = [], queue)
      @records  = records
      @queue    = queue
    end

    def call
      set_thread_values
      perform
      sqs_delete_success_records
    rescue => e
      puts "Error processing event '#{queue.name}': #{e.message}"
    end

    def sqs_record_success(record)
      record.delete
    end

    def sqs_record_failure(record)
      records.reject! { |r| r.receipt_handle == record.receipt_handle }
      record.set_visibility_timeout(failure_visibility_timeout)
    end

    protected

    def failure_visibility_timeout
      @failure_visibility_timeout ||= 60
    end

    def sqs_delete_success_records
      records.each do |record|
        sqs_record_success(record)
      end
    end

    private

    def set_thread_values
      ::Thread.current[:queue_name] = queue.name
      ::Thread.current[:job_ids]    = records.map(&:message_id)
    end











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
# Compare this snippet from lib/sqs_runner/manager.rb:
# 
# module SqsRunner
#   class Manager
#     DEFAULT_NUM_THREADS = 5
#     PID_FOLDER          = 'tmp/pids'.freeze
# 
#     attr_reader :queue_names, :num_processes, :num_threads, :manager_pid
#     attr_accessor :workers, :running
# 
#     def initialize(queue_names, num_processes, num_threads)
#       @queue_names    = queue_names || all_queues
#       @num_processes  = num_processes || ::Etc.nprocessors
#       @num_threads    = num_threads || DEFAULT_NUM_THREADS
#       @workers        = []
#       @running        = true
#       @manager_pid    = Process.pid
#     end
# 
#     def start
#       # Stop any orphaned workers
#       stop_processes
# 
#       # Start new workers
#       trap_signals
#       start_processes
#       monitor_processes
#     end
# 
#     def stop
#       shutdown
#     end
# 
#     protected
# 
#     def stop_processes
#       return unless ::File.exist?('tmp/pids/sqs_runner.pid')
# 
#       ::File.open('tmp/pids/sqs_runner.pid', 'r') do |f|
#         f.each_line do
end
