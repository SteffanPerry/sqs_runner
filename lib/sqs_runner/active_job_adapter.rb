require 'active_job'
require 'sqs_runner/job'

module ActiveJob
  module QueueAdapters
    class SqsQueueAdapter
      def enqueue(job) # For normal jobs
        enqueue_at(job, nil)
      end

      def enqueue_at(job, timestamp) # For scheduled jobs
        serialized_job = job.serialize
        queue_name = job.queue_name
        job_data = {
          job_class: serialized_job['job_class'],
          job_id: serialized_job['job_id'],
          arguments: serialized_job['arguments'],
          locale: serialized_job['locale'],
          enqueued_at: Time.now.to_f,
          scheduled_at: timestamp ? Time.at(timestamp) : nil
        }

        sqs_job = ::SqsRunner::Job.new
        sqs_job.enqueue(queue_name, job_data)
      end
    end
  end
end
