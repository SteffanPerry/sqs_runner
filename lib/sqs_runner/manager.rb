require 'etc'

module SqsRunner
  class Manager
    DEFAULT_NUM_THREADS = 5
    PID_FOLDER          = 'tmp/pids'.freeze

    attr_reader :queue_names, :num_processes, :num_threads, :manager_pid
    attr_accessor :workers, :running

    def initialize(queue_names, num_processes, num_threads)
      @queue_names    = queue_names || all_queues
      @num_processes  = num_processes || ::Etc.nprocessors
      @num_threads    = num_threads || DEFAULT_NUM_THREADS
      @workers        = []
      @running        = true
      @manager_pid    = Process.pid
    end

    def start
      # Stop any orphaned workers
      stop_processes

      # Start new workers
      trap_signals
      start_processes
      monitor_processes
    end

    def stop
      shutdown
    end

    protected

    def stop_processes
      return unless ::File.exist?('tmp/pids/sqs_runner.pid')

      ::File.open('tmp/pids/sqs_runner.pid', 'r') do |f|
        f.each_line do |pid|
          stop_process(pid.to_i)
        end
      end
    end

    def start_processes
      num_processes.times do
        fork_worker
      end
    end

    def monitor_processes
      puts "Monitoring workers..."
      while running
        @workers.each do |pid|
          next unless running

          ::Process.getpgid(pid)
        rescue Errno::ESRCH
          puts "Worker #{pid} died unexpectedly, respawning..."
          workers.delete(pid)
          fork_worker
        end

        sleep(10)
      end
    end

    private

    def fork_worker
      @workers << fork do
        worker = ::SqsRunner::Worker.new(queues, @num_threads, manager_pid)
        worker.start
      end

      save_pids
    end

    def queues
      @queue_names.map do |name|
        ::SqsRunner::Queue.new(name)
      end
    end

    def trap_signals
      Signal.trap('INT') { shutdown }
      Signal.trap('TERM') { shutdown }
    end

    def shutdown
      stop_processes
      sleep(1) until all_processes_stopped?

      puts "All workers stopped."
      begin
        ::File.delete('tmp/pids/sqs_runner.pid')
      rescue
      end
      exit
    end

    def all_queues
      yml = YAML.load_file('config/sqs_runner.yml')
      yml[Rails.env.to_s].keys
    end

    def stop_process(pid)
      Process.kill('TERM', pid)
      puts "Stoped process PID: #{pid}..."
    rescue Errno::ESRCH
      puts "Worker #{pid} not found, skipping..."
    end

    def all_processes_stopped?
      workers.all? do |pid|
        begin
          ::Process.getpgid(pid)
          false
        rescue Errno::ESRCH
          true
        end
      end
    end

    def save_pids
      FileUtils.mkdir_p(PID_FOLDER) unless File.directory?(PID_FOLDER)
      
      ::File.open("#{PID_FOLDER}/sqs_runner.pid", 'w') do |f|
        f.puts(workers.join("\n"))
      end
    end
  end
end
