require 'fileutils'
require 'json'
require 'tesults'
require_relative 'rspec_tesults_formatter/version'

class TesultsFormatter
  RSpec::Core::Formatters.register self, :example_started, :example_finished, :dump_summary

  def filesForCase(suite, name)
    files = []
    return files if @files.nil?

    path = File.join(@files, suite, name)
    return files unless File.directory?(path)

    Dir.foreach(path) do |filename|
      next if filename == '.' || filename == '..' || filename == '.DS_Store'

      files.push(File.expand_path(File.join(path, filename)))
    end
    files
  end

  def initialize(output)
    @output = output

    @target = configuration_value(:tesults_target)
    @files = configuration_value(:tesults_files)
    @buildName = configuration_value(:tesults_build_name)
    @buildDesc = configuration_value(:tesults_build_desc)
    @buildResult = configuration_value(:tesults_build_result, 'unknown')
    @buildResult = 'unknown' unless ['pass', 'fail'].include?(@buildResult)
    @buildReason = configuration_value(:tesults_build_reason)
    @outputFile = configuration_value(:tesults_output_file)

    environmentOutputFile = ENV['TESULTS_OUTPUT_FILE']
    @outputFile = environmentOutputFile unless blank?(environmentOutputFile)

    @disabled = @target.nil? && blank?(@outputFile)
    puts 'Tesults disabled. No target supplied.' if @disabled

    @data = {
      :target => @target,
      :results => {
        :cases => []
      },
      :metadata => {
        :integration_name => 'rspec_tesults_formatter',
        :integration_version => TesultsFormatter::VERSION,
        :test_framework => 'rspec'
      }
    }

    @starttimes = {}
  end

  def example_started(notification)
    return if @disabled

    example = notification.example
    @starttimes[example.id] = (Time.now.to_f * 1000).to_i
  end

  def example_finished(notification)
    return if @disabled

    example = notification.example
    result = example.execution_result.status.to_s
    if result == 'passed'
      result = 'pass'
    elsif result == 'failed'
      result = 'fail'
    else
      result = 'unknown'
    end

    group = example.metadata[:example_group] || {}
    parentGroup = group[:parent_example_group] || {}
    desc = group[:description]
    suite = parentGroup[:description] || ''
    reason = example.exception.nil? ? '' : example.exception.to_s

    testCase = {
      :name => example.description,
      :result => result,
      :desc => desc,
      :suite => suite,
      :reason => reason,
      :files => filesForCase(suite, example.description),
      :start => @starttimes[example.id],
      :end => (Time.now.to_f * 1000).to_i
    }

    source = example.metadata[:file_path]
    line = example.metadata[:line_number]
    unless source.nil?
      location = { :file => File.expand_path(source) }
      location[:line] = line.to_i unless line.nil?
      testCase[:_Location] = JSON.generate(location)
    end

    @data[:results][:cases].push(testCase)
  end

  def dump_summary(_message)
    return if @disabled

    if !@buildName.nil? && !@buildResult.nil?
      buildCase = {
        :name => @buildName,
        :suite => '[build]',
        :result => @buildResult
      }
      buildCase[:desc] = @buildDesc unless @buildDesc.nil?
      buildCase[:reason] = @buildReason unless @buildReason.nil?
      buildCase[:files] = filesForCase('[build]', @buildName)
      @data[:results][:cases].push(buildCase)
    end

    writeOutputFile
    return if @target.nil?

    puts 'Uploading results to Tesults...'
    res = Tesults.upload(@data)
    puts 'Success: ' + (res[:success] ? 'true' : 'false')
    puts 'Message: ' + res[:message]
    puts 'Warnings: ' + res[:warnings].length.to_s
    puts 'Errors: ' + res[:errors].length.to_s
  end

  private

  def blank?(value)
    value.nil? || value.to_s.empty?
  end

  def configuration_value(name, default = nil)
    RSpec.configuration.public_send(name)
  rescue StandardError
    default
  end

  def writeOutputFile
    return false if blank?(@outputFile)

    begin
      outputFile = File.expand_path(@outputFile)
      FileUtils.mkdir_p(File.dirname(outputFile))
      localData = @data.merge(:target => '')
      File.open(outputFile, 'w') do |file|
        file.write(JSON.generate(localData))
      end
      puts 'Tesults results written to ' + outputFile
      true
    rescue StandardError => error
      puts 'Error writing Tesults results file: ' + error.to_s
      false
    end
  end
end
