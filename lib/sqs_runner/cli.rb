require 'thor'
require 'etc'

module SqsRunner
  class CLI < Thor
    desc "start", "Start the SqsRunner worker"
    option :queues,     type: :array,   aliases: '-q', required: true,            banner: 'QUEUE1 QUEUE2'
    option :processes,  type: :numeric, aliases: '-p', default: Etc.nprocessors,  desc: 'Number of worker processes to spawn'
    option :threads,    type: :numeric, aliases: '-t', default: 5,                desc: 'Number of threads per process'

    def start
      manager = ::SqsRunner::Manager.new(options[:queues], options[:processes], options[:threads])
      manager.start
    end
  end
end
