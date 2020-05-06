require 'tesults'

class TesultsFormatter
  RSpec::Core::Formatters.register self, :example_finished, :dump_summary

  def filesForCase(suite, name)
    files = []
    if (@files == nil)
      return files
    end
    path = File.join(@files, suite, name)
    if (File.directory?(path) != true)
      return files
    else 
      Dir.foreach(path) do |filename|
        next if filename == '.' or filename == '..' or filename == '.DS_Store'
        files.push(File.join(path, filename))
      end
    end
    return files
  end

  def initialize(output)
    @output = output

    # args
    @disabled = true
    begin
      @target = RSpec.configuration.tesults_target
    rescue
      @target = nil
    end
    begin
      @files = RSpec.configuration.tesults_files
    rescue
      @files = nil
    end
    begin
      @buildName = RSpec.configuration.tesults_build_name
    rescue
      @buildName = nil
    end
    begin 
      @buildDesc = RSpec.configuration.tesults_build_desc
    rescue
      @buildDesc = nil
    end
    begin
      @buildResult = RSpec.configuration.tesults_build_result
      if (@buildResult != "pass" && @buildResult != "fail")
        @buildResult = "unknown"
      end
    rescue
      @buildResult = "unknown"
    end
    begin 
      @buildReason = RSpec.configuration.tesults_build_reason
    rescue
      @buildReason = nil
    end

    if (@target != nil)
      @disabled = false
    end
    if (@disabled == true)
      puts 'Tesults disabled. No target supplied.'
    end

    @data = {
      :target => @target,
      :results => {
        :cases => []
      }
    }
  end

  def example_finished(notification)
    if (@disabled == true) 
      return
    end
    example = notification.example
    result = example.execution_result.status.to_s
    if result == "passed"
      result = "pass"
    elsif result == "failed"
      result = "fail"
    else
      result = "unknown"
    end

    name = example.description
    desc = example.metadata[:example_group][:description]
    suite = example.metadata[:example_group][:parent_example_group][:description]
    reason = example.exception

    if reason == nil
      reason = ""
    else
      reason = reason.to_s
    end

    @data[:results][:cases].push({
      :name => example.description,
      :result => result,
      :desc => desc,
      :suite => suite,
      :reason => reason,
      :files => filesForCase(suite, example.description)
    })

    #@output.puts name + ": " + result
  end

  def dump_summary (message)
    if (@disabled == true) 
      return
    end
    if (@buildName != nil && @buildResult != nil)
      buildCase = {
        :name => @buildName,
        :suite => "[build]",
        :result => @buildResult
      }
      if (@buildDesc != nil)
        buildCase[:desc] = @buildDesc
      end
      if (@buildReason != nil)
        buildCase[:reason] = @buildReason
      end
      buildCase[:files] = filesForCase("[build]", @buildName)
      @data[:results][:cases].push(buildCase)
    end
    # Use this puts for debugging: puts(@data)
    puts 'Uploading results to Tesults...'
    res = Tesults.upload(@data)
    puts 'Success: ' + (res[:success] ? "true" : "false")
    puts 'Message: ' + res[:message]
    puts 'Warnings: ' + res[:warnings].length.to_s
    puts 'Errors: ' + res[:errors].length.to_s
  end
end