require 'spec_helper'

RSpec.describe SqsRunner::Manager do
  subject { described_class.new(queue_names, num_processes, num_threads) }

  let(:queue_names) { %w[default_queue another_queue] }
  let(:num_processes) { 2 }
  let(:num_threads) { 5 }
  let(:all_queues) { YAML.load_file('spec/fixtures/sample.yml')['test'].keys }

  before do
    allow(Rails).to receive(:env).and_return('test')
    allow(YAML).to receive(:load_file).and_return(YAML.load_file('spec/fixtures/sample.yml'))
  end

  after do
    subject.stop
  end

  describe 'constants' do
    it 'default number of threads' do
      expect(described_class::DEFAULT_NUM_THREADS).to eq(5)
    end
  end

  describe 'initialize' do
    it 'sets the queue names' do
      expect(subject.queue_names).to eq(queue_names)
    end

    it 'sets the number of processes' do
      expect(subject.num_processes).to eq(num_processes)
    end

    it 'sets the number of threads' do
      expect(subject.num_threads).to eq(num_threads)
    end

    context 'when queue names are not provided' do
      let(:queue_names) { nil }

      it 'uses all queues' do
        allow_any_instance_of(described_class).to receive(:all_queues).and_call_original
        expect(subject).to have_received(:all_queues)
        expect(subject.queue_names).to eq(all_queues)
      end
    end

    context 'when number of processes is not provided' do
      let(:num_processes) { nil }

      it 'uses the default number of processes' do
        allow(::Etc).to receive(:nprocessors).and_return(4)

        expect(::Etc).to receive(:nprocessors)
        expect(subject.num_processes).to eq(4)
      end
    end

    context 'when number of threads is not provided' do
      let(:num_threads) { nil }

      it 'uses the default number of threads' do
        expect(subject.num_threads).to eq(described_class::DEFAULT_NUM_THREADS)
      end
    end
  end

  describe '#start' do
    it 'starts runner' do
      expect(subject).to receive(:stop_processes)
      expect(subject).to receive(:trap_signals)
      expect(subject).to receive(:start_processes)
      expect(subject).to receive(:monitor_processes)

      subject.start
    end

    it 'stops orphaned workers' do
      File.open('tmp/pids/sqs_runner.pid', 'w') { |f| f.puts '123' }
      allow(subject).to receive(:trap_signals)
      allow(subject).to receive(:start_processes)
      allow(subject).to receive(:monitor_processes)

      expect(subject).to receive(:stop_processes).with(123)

      subject.start
    end
  end

  describe '#start_processes' do
    it 'starts' do
      subject.instance_variable_set(:@num_processes, 1)
      subject.send :start_processes
    end

    it 'forks the specified number of worker processes' do
      expect(subject).to receive(:fork_worker).exactly(num_processes).times

      subject.send(:start_processes)
    end
  end

  describe '#monitor_processes' do
    it 'breaks when running is false' do
      allow(subject).to receive(:sleep)
      allow(subject).to receive(:fork_worker)
      allow(Process).to receive(:getpgid).and_raise(Errno::ESRCH)

      subject.instance_variable_set(:@running, false)
      subject.send(:monitor_processes)

      expect(subject).to_not have_received(:fork_worker)
    end

    it 'forks a new worker when a worker dies' do
      allow(subject).to receive(:running).and_return(true, true, false)
      allow(subject).to receive(:sleep)
      allow(Process).to receive(:getpgid).and_raise(Errno::ESRCH)

      subject.instance_variable_set(:@workers, [1])
      subject.send(:monitor_processes)

      expect(subject.instance_variable_get(:@workers).size).to eq(1)
      expect(subject.instance_variable_get(:@workers)).not_to include(1)
    end
  end

  describe '#fork_worker' do
    it 'forks a new worker process' do
      expect(subject).to receive(:fork)

      subject.send(:fork_worker)
    end

    it 'adds the worker process to the workers array' do
      allow(subject).to receive(:fork).and_return(123)
      subject.send(:fork_worker)

      expect(subject.instance_variable_get(:@workers)).to eq([123])
    end

    it 'starts a new worker' do
      allow(subject).to receive(:fork).and_yield
      expect_any_instance_of(SqsRunner::Worker).to receive(:start)

      subject.send(:fork_worker)
    end
  end

  describe '#queues' do
    it 'returns an array of Queue objects' do
      expect(subject.send(:queues)).to all(be_a(SqsRunner::Queue))
    end

    it 'sends the queue names to the Queue constructor' do
      expect(SqsRunner::Queue).to receive(:new).with('default_queue')
      expect(SqsRunner::Queue).to receive(:new).with('another_queue')

      subject.send(:queues)
    end
  end
end
