require 'spec_helper'

RSpec.describe ::SqsRunner::Queue do
  subject { described_class.new(queue_name) }

  let(:queue_name) { 'default_queue' }

  describe '.configuration' do
    it 'returns the configuration' do
      expect(described_class.configuration).to be_a(Hash)
    end
  end

  describe '.client' do
    it 'returns the client' do
      expect(described_class.client).to be_a(Aws::SQS::Client)
    end
  end
  
  describe '#initialize' do
    it 'loads_options' do
      allow_any_instance_of(described_class).to receive(:load_configuration)
      expect(subject).to have_received(:load_configuration)
    end
  end

  describe '#fetch_messages' do
    it 'returns the messages' do
      expect(subject.fetch_messages).to eq([])
    end

    context 'when queue not found' do
      it 'raises an error' do
        allow_any_instance_of(Aws::SQS::Client).to receive(:receive_message).and_raise(Aws::SQS::Errors::NonExistentQueue.new(nil, "Queue Nout Found: 'default_queue'"))
        expect { subject.fetch_messages }.to raise_error(::SqsRunner::QueueNotFound, "Queue Nout Found: 'default_queue'")
      end
    end
  end

  describe '#url' do
    it 'returns the url' do
      expect(subject.url).to eq('https://sqs.us-east-1.amazonaws.com/123456789012/default')
    end
  end

  describe '#type' do
    it 'returns the type' do
      expect(subject.type).to eq(:active_job)
    end

    context 'when event' do
      let(:queue_name) { 'event_queue' }

      it 'returns the type' do
        expect(subject.type).to eq(:event)
      end
    end
  end

  describe '#fifo?' do
    it 'returns the fifo' do
      expect(subject.fifo?).to eq(false)
    end

    context 'when fifo' do
      let(:queue_name) { 'fifo_queue' }

      it 'returns the fifo' do
        expect(subject.fifo?).to eq(true)
      end
    end
  end

  describe '#weight' do
    it 'returns the weight' do
      expect(subject.weight).to eq(1)
    end

    context 'when weight' do
      let(:queue_name) { 'weight_queue' }

      it 'returns the weight' do
        expect(subject.weight).to eq(5)
      end

      context 'when weight is less than 1' do
        let(:queue_name) { 'weight_queue_invalid' }

        it 'returns the weight' do
          expect(subject.weight).to eq(1)
        end
      end

      context 'when weight is not set' do
        let(:queue_name) { 'default_queue' }

        it 'returns the weight' do
          expect(subject.weight).to eq(1)
        end
      end
    end
  end

  describe '#load_configuration' do
    it 'returns the configuration' do
      expect(subject.send(:load_configuration)).to eq(
        url: 'https://sqs.us-east-1.amazonaws.com/123456789012/default',
        type: :active_job,
        fifo: false,
        weight: 1
      )
    end
  end

  describe '#queue_config' do
    it 'returns the queue config' do
      expect(subject.send(:queue_config)).to eq(url: 'https://sqs.us-east-1.amazonaws.com/123456789012/default')
    end

    context 'when queue not found' do
      let(:queue_name) { 'unknown' }

      it 'raises an error' do
        expect { subject.send(:queue_config, queue_name) }.to raise_error(::SqsRunner::MissingConfiguration, "Queue Nout Found: 'unknown'")
      end
    end
  end
end
