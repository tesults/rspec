require 'json'
require 'minitest/autorun'
require 'open3'
require 'ostruct'
require 'stringio'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('support', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'rspec/core'
require 'rspec_tesults_formatter'

class FormatterConfiguration
  def initialize(values = {})
    @values = values
  end

  def method_missing(name, *arguments)
    return @values[name] if arguments.empty? && @values.key?(name)

    super
  end

  def respond_to_missing?(name, include_private = false)
    @values.key?(name) || super
  end
end

class RspecTesultsFormatterIntegrationTest < Minitest::Test
  def setup
    @original_output_file = ENV['TESULTS_OUTPUT_FILE']
    @original_capture_file = ENV['TESULTS_UPLOAD_CAPTURE']
    ENV.delete('TESULTS_OUTPUT_FILE')
    ENV.delete('TESULTS_UPLOAD_CAPTURE')
    Tesults.reset!
  end

  def teardown
    restore_environment('TESULTS_OUTPUT_FILE', @original_output_file)
    restore_environment('TESULTS_UPLOAD_CAPTURE', @original_capture_file)
  end

  def test_neither_target_nor_output_preserves_disabled_behavior
    formatter = nil
    stdout, = capture_io do
      formatter = with_configuration { TesultsFormatter.new(StringIO.new) }
    end

    assert_includes stdout, 'Tesults disabled. No target supplied.'
    formatter.example_started(notification(example))
    formatter.example_finished(notification(example))
    formatter.dump_summary(nil)
    assert_empty Tesults.uploads
  end

  def test_target_only_uploads_once_with_existing_result_fields_and_metadata
    formatter = with_configuration(:tesults_target => 'target-token') do
      TesultsFormatter.new(StringIO.new)
    end
    current_example = example(:status => :failed, :exception => RuntimeError.new('expected 2, got 1'))

    formatter.example_started(notification(current_example))
    formatter.example_finished(notification(current_example))
    capture_io { formatter.dump_summary(nil) }

    assert_equal 1, Tesults.uploads.length
    payload = json_round_trip(Tesults.uploads.first)
    assert_equal 'target-token', payload['target']
    assert_equal expected_metadata, payload['metadata']
    test_case = payload['results']['cases'].first
    assert_equal 'fails clearly', test_case['name']
    assert_equal 'fail', test_case['result']
    assert_equal 'Example description', test_case['desc']
    assert_equal 'Example suite', test_case['suite']
    assert_equal 'expected 2, got 1', test_case['reason']
    assert_kind_of Integer, test_case['start']
    assert_kind_of Integer, test_case['end']
  end

  def test_output_only_writes_results_metadata_location_and_absolute_files
    Dir.mktmpdir('rspec-tesults-output') do |directory|
      attachment = File.join(directory, 'files', 'Example suite', 'passes clearly', 'evidence.txt')
      FileUtils.mkdir_p(File.dirname(attachment))
      File.write(attachment, 'evidence')
      output_file = File.join(directory, 'nested', 'results.json')

      formatter = with_configuration(
        :tesults_files => File.join(directory, 'files'),
        :tesults_output_file => output_file
      ) { TesultsFormatter.new(StringIO.new) }
      current_example = example(:description => 'passes clearly')
      formatter.example_started(notification(current_example))
      formatter.example_finished(notification(current_example))
      capture_io { formatter.dump_summary(nil) }

      payload = JSON.parse(File.read(output_file))
      assert_equal '', payload['target']
      assert_equal expected_metadata, payload['metadata']
      assert_empty Tesults.uploads
      test_case = payload['results']['cases'].first
      assert_equal 'pass', test_case['result']
      assert_equal [File.expand_path(attachment)], test_case['files']
      location = JSON.parse(test_case['_Location'])
      assert_equal File.expand_path('spec/example_spec.rb'), location['file']
      assert_equal 17, location['line']
    end
  end

  def test_environment_output_takes_precedence_and_combines_with_upload
    Dir.mktmpdir('rspec-tesults-combined') do |directory|
      configured_output = File.join(directory, 'configured.json')
      environment_output = File.join(directory, 'environment.json')
      ENV['TESULTS_OUTPUT_FILE'] = environment_output

      formatter = with_configuration(
        :tesults_target => 'combined-target',
        :tesults_output_file => configured_output
      ) { TesultsFormatter.new(StringIO.new) }
      current_example = example
      formatter.example_started(notification(current_example))
      formatter.example_finished(notification(current_example))
      capture_io { formatter.dump_summary(nil) }

      refute File.exist?(configured_output)
      local_payload = JSON.parse(File.read(environment_output))
      uploaded_payload = json_round_trip(Tesults.uploads.first)
      assert_equal '', local_payload['target']
      assert_equal 'combined-target', uploaded_payload['target']
      assert_equal local_payload['results'], uploaded_payload['results']
      assert_equal local_payload['metadata'], uploaded_payload['metadata']
    end
  end

  def test_build_configuration_and_files_are_preserved
    Dir.mktmpdir('rspec-tesults-build') do |directory|
      attachment = File.join(directory, 'files', '[build]', 'build-42', 'build.log')
      FileUtils.mkdir_p(File.dirname(attachment))
      File.write(attachment, 'build output')
      output_file = File.join(directory, 'results.json')

      formatter = with_configuration(
        :tesults_output_file => output_file,
        :tesults_files => File.join(directory, 'files'),
        :tesults_build_name => 'build-42',
        :tesults_build_desc => 'Build description',
        :tesults_build_result => 'fail',
        :tesults_build_reason => 'Build reason'
      ) { TesultsFormatter.new(StringIO.new) }
      capture_io { formatter.dump_summary(nil) }

      build = JSON.parse(File.read(output_file))['results']['cases'].first
      assert_equal '[build]', build['suite']
      assert_equal 'build-42', build['name']
      assert_equal 'fail', build['result']
      assert_equal 'Build description', build['desc']
      assert_equal 'Build reason', build['reason']
      assert_equal [File.expand_path(attachment)], build['files']
    end
  end

  def test_output_error_does_not_prevent_upload
    Dir.mktmpdir('rspec-tesults-error') do |directory|
      ENV['TESULTS_OUTPUT_FILE'] = directory
      formatter = with_configuration(:tesults_target => 'upload-after-error') do
        TesultsFormatter.new(StringIO.new)
      end
      current_example = example
      formatter.example_started(notification(current_example))
      formatter.example_finished(notification(current_example))

      stdout, = capture_io { formatter.dump_summary(nil) }

      assert_includes stdout, 'Error writing Tesults results file:'
      assert_equal 1, Tesults.uploads.length
      assert_equal 'upload-after-error', Tesults.uploads.first[:target]
    end
  end

  def test_real_rspec_cli_writes_pass_fail_and_pending_results
    Dir.mktmpdir('rspec-tesults-cli') do |directory|
      spec_file = File.join(directory, 'sample_spec.rb')
      output_file = File.join(directory, 'results.json')
      File.write(spec_file, <<~RUBY)
        RSpec.describe 'CLI suite' do
          context 'CLI description' do
            it('passes') { expect(2 + 2).to eq(4) }
            it('fails') { expect('actual').to eq('expected') }
            xit('is pending') { expect(true).to eq(false) }
          end
        end
      RUBY

      environment = {
        'TESULTS_OUTPUT_FILE' => output_file,
        'RUBYLIB' => [
          File.expand_path('support', __dir__),
          File.expand_path('../lib', __dir__),
          ENV['RUBYLIB']
        ].compact.join(File::PATH_SEPARATOR)
      }
      executable = Gem.bin_path('rspec-core', 'rspec')
      stdout, stderr, status = Open3.capture3(
        environment,
        Gem.ruby,
        executable,
        '--require',
        'rspec_tesults_formatter',
        '--format',
        'TesultsFormatter',
        spec_file
      )

      refute status.success?, stdout + stderr
      payload = JSON.parse(File.read(output_file))
      assert_equal expected_metadata, payload['metadata']
      results = payload['results']['cases'].each_with_object({}) do |test_case, mapped|
        mapped[test_case['name']] = test_case
      end
      assert_equal 'pass', results['passes']['result']
      assert_equal 'fail', results['fails']['result']
      assert_equal 'unknown', results['is pending']['result']
      assert_includes results['fails']['reason'], 'expected: "expected"'
      location = JSON.parse(results['fails']['_Location'])
      assert_equal File.expand_path(spec_file), location['file']
      assert_operator location['line'], :>, 0
    end
  end

  private

  def expected_metadata
    {
      'integration_name' => 'rspec_tesults_formatter',
      'integration_version' => '1.2.0',
      'test_framework' => 'rspec'
    }
  end

  def example(options = {})
    defaults = {
      :id => 'spec/example_spec.rb[1:1]',
      :description => 'fails clearly',
      :status => :passed,
      :exception => nil,
      :file_path => 'spec/example_spec.rb',
      :line_number => 17
    }
    values = defaults.merge(options)
    OpenStruct.new(
      :id => values[:id],
      :description => values[:description],
      :execution_result => OpenStruct.new(:status => values[:status]),
      :exception => values[:exception],
      :metadata => {
        :example_group => {
          :description => 'Example description',
          :parent_example_group => { :description => 'Example suite' }
        },
        :file_path => values[:file_path],
        :line_number => values[:line_number]
      }
    )
  end

  def notification(current_example)
    OpenStruct.new(:example => current_example)
  end

  def with_configuration(values = {})
    singleton = RSpec.singleton_class
    original = RSpec.method(:configuration)
    configuration = FormatterConfiguration.new(values)
    singleton.send(:define_method, :configuration) { configuration }
    yield
  ensure
    singleton.send(:define_method, :configuration, original)
  end

  def json_round_trip(value)
    JSON.parse(JSON.generate(value))
  end

  def restore_environment(name, value)
    if value.nil?
      ENV.delete(name)
    else
      ENV[name] = value
    end
  end
end
