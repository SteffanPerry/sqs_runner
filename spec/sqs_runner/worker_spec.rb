require 'spec_helper'

RSpec.describe SqsRunner::Worker do
  subject { described_class.new(queues, thread_count) }

  let(:queues) { %w[default low_priority] }
  let(:thread_count) { 5 }
  let(:sqs_client) { Aws::SQS::Client.new }

  before do
    default_queue_url       = 'https://sqs.us-east-1.amazonaws.com/123456789012/default'
    low_priority_queue_url  = 'https://sqs.us-east-1.amazonaws.com/123456789012/low_priority'
    
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)

    @message = Aws::SQS::Types::Message.new(
      message_id: 'msg-123',
      receipt_handle: 'rh-123',
      body: '{"task":"test_task"}'
    )

    # Mock get_queue_url
    allow(sqs_client).to receive(:get_queue_url).with(queue_name: 'default').and_return(
      double(queue_url: default_queue_url)
    )
    allow(sqs_client).to receive(:get_queue_url).with(queue_name: 'low_priority').and_return(
      double(queue_url: low_priority_queue_url)
    )

    # Mock receive_message
    allow(sqs_client).to receive(:receive_message).and_return(
      double(messages: [@message])
    )

    # Mock delete_message
    allow(sqs_client).to receive(:delete_message)
  end

  describe '#initialize' do
    context 'when queues are not provided' do
      it 'uses the queues from the Rails configuration' do
        allow(Rails).to receive_message_chain(:application, :config, :sqs_queue, :queues).and_return(queues)

        worker = SqsRunner::Worker.new
        expect(worker.queues).to eq(queues)
      end
    end

    context 'when queues are provided' do
      it 'uses the provided queues' do
        worker = SqsRunner::Worker.new(queues)
        expect(worker.queues).to eq(queues)
      end
    end

    it 'sets the thread count' do
      expect(subject.threads_count).to eq(thread_count)
    end

    it 'initializes the SQS client' do
      expect(subject.instance_variable_get(:@sqs)).to eq(@sqs_client)
    end

    it 'sets the running flag to true' do
      expect(subject.instance_variable_get(:@running)).to be true
    end

    it 'initializes the threads array' do
      expect(subject.instance_variable_get(:@threads)).to eq([])
    end
  end

  describe '#start' do
    it 'traps signals' do
      allow(subject).to receive(:start_threads)
      expect(subject).to receive(:trap_signals)
      subject.start
    end

    it 'starts the threads' do
      allow(subject).to receive(:trap_signals)
      expect(subject).to receive(:start_threads)
      subject.start
    end
  end

  describe '#trap_signals' do
    it 'traps the TERM signal' do
      Process.kill('TERM', Process.pid)
      expect(subject.running).to be false
    end
  end

  describe '#start_threads' do
    it 'creates the specified number of threads' do
      allow(Thread).to receive(:new).and_yield
      expect(Thread).to receive(:new).exactly(thread_count).times

      subject.send(:start_threads)
    end
  end

  describe '#work_loop' do
    it 'loops through each queue' do
      allow(subject).to receive(:running).and_return(true, true, true, false)

      expect(subject).to receive(:run_queue).with('default')
      expect(subject).to receive(:run_queue).with('low_priority')

      subject.send(:work_loop)
    end
  end

  describe '#run_queue' do
    it 'fetches messages from the queue' do
      queue_url = 'https://sqs.us-east-1.amazonaws.com/123456789012/default'
      allow(subject).to receive(:get_queue_url).with('default').and_return(queue_url)

      expect(subject).to receive(:fetch_messages).with(queue_url).and_return([@message])
      subject.send(:run_queue, 'default')
    end

    it 'processes each message' do
      queue_url = 'https://sqs.us-east-1.amazonaws.com/123456789012/default'
      allow(subject).to receive(:get_queue_url).with('default').and_return(queue_url)
      allow(subject).to receive(:fetch_messages).with(queue_url).and_return([@message])

      expect(subject).to receive(:process_message).with(@message, queue_url)
      subject.send(:run_queue, 'default')
    end
  end

  describe '#get_queue_url' do
    it 'returns the queue URL' do
      queue_name = 'default'
      queue_url = 'https://sqs.us-east-1.amazonaws.com/123456789012/default'
      expect(subject.send(:get_queue_url, queue_name)).to eq(queue_url)
    end

    it 'raises an error if the queue URL is not found' do
      queue_name = 'unknown'
      expect { subject.send(:get_queue_url, queue_name) }.to raise_error("Queue URL not found for queue '#{queue_name}'")
    end
  end

  describe '#fetch_messages' do
    it 'fetches messages from the queue' do
      queue_url = 'https://sqs.us-east-1.amazonaws.com/123456789012/default'
      response  = double(messages: [@message])

      expect(sqs_client).to receive(:receive_message).with(
        queue_url: queue_url,
        max_number_of_messages: 10,
        wait_time_seconds: 20
      ).and_return(response)

      expect(subject.send(:fetch_messages, queue_url)).to eq([@message])
    end
  end





  it 'processes messages from the queue' do
    worker = SqsRunner::Worker.new(['default'], 1)
    allow(worker).to receive(:trap_signals)
    allow(worker).to receive(:sleep)

    # Stub the infinite loop
    allow(worker).to receive(:running).and_return(false)

    # Run the work_loop once
    expect { worker.send(:work_loop) }.not_to raise_error
  end

  it 'creates the specified number of threads' do
    allow(Thread).to receive(:new).and_yield
  
    expect(Thread).to receive(:new).exactly(5).times
  
    worker = SqsRunner::Worker.new(['default'], 5)
    allow(worker).to receive(:trap_signals)
    allow(worker).to receive(:work_loop)
  
    worker.start
  end

  it 'handles exceptions during message processing' do
    allow(@sqs_client).to receive(:receive_message).and_return(
      double(messages: [@message])
    )
  
    # Simulate an error in process_message
    allow_any_instance_of(SqsRunner::Worker).to receive(:process_message).and_raise(StandardError.new('Test error'))
  
    worker = SqsRunner::Worker.new(['default'], 1)
    allow(worker).to receive(:trap_signals)
    allow(worker).to receive(:sleep)
  
    expect { worker.send(:work_loop) }.not_to raise_error
  end

  it 'sleeps when no messages are received' do
    allow(@sqs_client).to receive(:receive_message).and_return(
      double(messages: [])
    )
  
    worker = SqsRunner::Worker.new(['default'], 1)
    allow(worker).to receive(:trap_signals)
  
    expect(worker).to receive(:sleep).with(1)
  
    # Run the work_loop once
    allow(worker).to receive(:running).and_return(false)
    worker.send(:work_loop)
  end
end
