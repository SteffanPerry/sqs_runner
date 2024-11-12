require 'spec_helper'

RSpec.describe ::SqsRunner::Job do
  before do
    @sqs_client = Aws::SQS::Client.new
    allow(Aws::SQS::Client).to receive(:new).and_return(@sqs_client)

    # Mock the get_queue_url response
    allow(@sqs_client).to receive(:get_queue_url).with(queue_name: 'default').and_return(
      double(queue_url: 'https://sqs.us-east-1.amazonaws.com/123456789012/default')
    )

    # Mock send_message
    allow(@sqs_client).to receive(:send_message)
  end

  it 'initializes with an SQS client' do
    job = SqsRunner::Job.new
    expect(job).to be_a(SqsRunner::Job)
  end

  it 'enqueues a job to the correct SQS queue' do
    expect(@sqs_client).to receive(:send_message).with(
      queue_url: 'https://sqs.us-east-1.amazonaws.com/123456789012/default',
      message_body: '{"task":"test_task"}'
    )

    job = SqsRunner::Job.new
    job.enqueue('default', { task: 'test_task' })
  end
end
