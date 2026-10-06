# coding: utf-8
require_relative 'lib/rspec_tesults_formatter/version'

Gem::Specification.new do |spec|
  spec.name          = "rspec_tesults_formatter"
  spec.version       = TesultsFormatter::VERSION
  spec.authors       = ["ajeetd"]
  spec.email         = ["help@tesults.com"]

  spec.summary       = "RSpec Tesults Formatter"
  spec.description   = "RSpec Tesults Formatter makes it easy to push test results data to Tesults from your RSpec tests."
  spec.homepage      = "https://www.tesults.com/docs/rspec"
  spec.files         = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.add_development_dependency 'tesults', ["= 1.1.1"]
  spec.add_development_dependency 'rspec', [">= 3.9", "< 4"]
  spec.add_development_dependency 'minitest', ["~> 5.25.0"]
  spec.add_runtime_dependency 'tesults', ["= 1.1.1"]
  spec.license       = "MIT"
end
