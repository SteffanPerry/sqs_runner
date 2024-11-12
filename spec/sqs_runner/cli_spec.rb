require 'spec_helper'
require 'thor'

RSpec.describe SqsRunner::CLI do
  it 'starts the manager with the correct options' do
    expect(SqsRunner::Manager).to receive(:new).with(['default'], 4, 5).and_return(double(start: nil))

    argv = ['start', '--queues', 'default', '--processes', '4', '--threads', '5']
    SqsRunner::CLI.start(argv)
  end
end
