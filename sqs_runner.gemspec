Gem::Specification.new do |spec|
  spec.name          = 'sqs_queue'
  spec.version       = '0.1.0'
  spec.summary       = 'A background job processor for Rails using AWS SQS'
  spec.authors       = ['Steffan Perry']
  spec.email         = ['sperry1988@gmail.com']

  spec.files         = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.0'
  spec.add_dependency 'aws-sdk-sqs', '~> 1.34'
  spec.add_dependency 'thor'

  spec.add_development_dependency 'rspec', '~> 3.10'
end
