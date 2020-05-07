# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "rspec_tesults_formatter"
  spec.version       = "1.0.1"
  spec.authors       = ["Ajeet Dhaliwal"]
  spec.email         = ["help@tesults.com"]

  spec.summary       = "RSpec Tesults Formatter"
  spec.description   = "RSpec Tesults Formatter makes it easy to push test results data to Tesults from your RSpec tests."
  spec.homepage      = "https://www.tesults.com"
  spec.files         = ["lib/rspec_tesults_formatter.rb"]
  spec.add_development_dependency 'tesults', ["= 1.1.1"]
  spec.add_runtime_dependency 'tesults', ["= 1.1.1"]
  spec.license       = "MIT"
end