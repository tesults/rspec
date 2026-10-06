# Tesults

Tesults is a test automation results reporting service. https://www.tesults.com

RSpec Tesults Formatter makes it easy to push test results data to Tesults from your RSpec tests.

## Installation

`gem install rspec_tesults_formatter`

## Configuration

 ```rb
rspec --format TesultsFormatter spec
```

## Documentation

View https://www.tesults.com/docs/rspec for comprehensive documentation on the RSpec Tesults Formatter including detailed usage instructions and explanations on the arguments that you can supply.

## GitHub Actions

`rspec_tesults_formatter` can produce a local results file for the Tesults Test
Automation Reporting action. No Tesults target token is required for this mode.

Install `rspec_tesults_formatter` 1.2.0 or later, add the action before the test
step, and run RSpec with the formatter as usual:

```yaml
- uses: tesults/test-automation-reporting@v1
- run: rspec --format TesultsFormatter spec
```

The action sets `TESULTS_OUTPUT_FILE` automatically. You can also set a path in
RSpec configuration with `tesults_output_file`; the environment variable takes
precedence when both are present:

```rb
RSpec.configure do |config|
  config.add_setting :tesults_output_file, :default => "/path/to/results.json"
end
```

If both local output and `tesults_target` are configured, the formatter writes
the local results file and uploads the same run to Tesults.

## Support

help@tesults.com
