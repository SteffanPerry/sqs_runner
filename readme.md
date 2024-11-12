WIP (Not Ready For Development or Production)
  This gem is not ready for use. DO NOT USE IT you will lose data.

SQS Runner is a lightweight job runner designed to process jobs off of Amazon SQS queues for Ruby on Rails applications.

Why Another SQS Gem?
There are two main gems to run sqs jobs with ruby on rails: First is using Shoyuken gem, the second is using AWS Rails SDK.
 - Shoyuken is unfortunatley now in maintance mode and is no longer activley maintained.
 - AWS Rails SDK, while great for running rails in AWS Lambda, has poor support for running jobs on bare metal / containers. It requires to manually spin up multiple processes (one per queue).

 Neither of the two gems above allow for event based jobs to be processed without some sort or intermediary

Core Features of SQS Runner:
  - Multi process, multi threaded out of the box
  - Weighted round robin queueing
  - Easy to deploy
  - ActiveJob and Event based job support
  - Designed to work with AWS SQS best practices

Multi Process:
  SQS Runner can take full advantage of all cores on your machine for processing jobs, By default SQS Runner will create a seperate process for each physical core. This is configurable should you want a different value.

Multi Thread:
  Each process runs multiple threads (5 by default), This value is configurable

Weighted Round Robin Queueing:
  Add priorities for queues for round robin, such as:
  high_prio:
    url: https://my.high-prio-queue.amazon.sqs
    weight: 4
  low_prio:
    url: https://my.high-prio-queue.amazon.sqs
    weight: 1

  In this scenario, 4 high priority jobs will be run for every 1 low_prio job when both queues have ample jobs to run.

Easy to Deploy:
  Deploy with a simple one line command

ActiveJob and Event based job support:
  Most job runners in rails only support ActiveJob jobs. This is great for 90% of Rails applications. However there is some inherent limitations with this. First the job producer much know the consumers class and arguments while enqueueing the job. Secondly it prevents event based jobs (such as a SQS queue listening to a sns topic).

  SQS Runner fully supports active job, as well as event based jobs. With event based jobs, a queue can only invoke a single job in your application. However you get the full message, along with message attributes for processing.

  Below is an example of a queue that will trigger the NewUserJob, which inherits from SqsEventJob. SqsEventJob will assign a messages to the "record" variable and invoke the "perform" method. Failed messages that should be retried should be passed to the sqs_record_failure method, these jobs will not be deleted from sqs and be retried after their message visibility timeout expires. all other jobs will be deleted from AWS SQS AFTER processing of the batch has completed. if you would like to delete the message as soon as it has completed, you can optionally send the record to the sqs_record_success method. If the perform method results in a exception, the jobs will neither deleted nor updated with a new message visibility timeout and instead be shown as "in flight" until the original visibility timeout has ended.

  default_queue:
    url: https://my.default-queue.amazon.sqs
    weight: 4
  new_user_queue:
    url: https://my.new-user-queue.amazon.sqs
    weight: 1
    max_messages: 10
    type: event

  class NewUserJob < SqsEventJob
    queue :new_user_queue
    failure_delay: 30

    def perform
      records.each do |record|
        process_record(record)
        sqs_record_success(record) # Optional to delete message immediatley without waiting for the batch to complete
      rescue
        sqs_record_failure(record) # SqsEventJob method, will update the visibility timeout with the delay specified
      end
    end

    def process_record(record)
      # Work...
    end
  end

Designed to work with AWS SQS best practices
  Both AWS and engineers who have worked with SQS at scale agree that messages should only be deleted AFTER they have been successfully processed. This unfortnatley is not how many gems work. By default other gems immediatley delete the message and "re-enqueue" the message if it fails. In the "rare" situiation the re enqueueing fails (Netowork errors, AWS outage, Server crash durring processing), the message is lost forever.