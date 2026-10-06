require 'fileutils'
require 'json'

module Tesults
  class << self
    attr_accessor :uploads
  end

  self.uploads = []

  def self.reset!
    self.uploads = []
  end

  def self.upload(data)
    self.uploads << data
    capture = ENV['TESULTS_UPLOAD_CAPTURE']
    unless capture.nil? || capture.empty?
      FileUtils.mkdir_p(File.dirname(File.expand_path(capture)))
      File.open(capture, 'w') { |file| file.write(JSON.generate(data)) }
    end
    {
      :success => true,
      :message => 'captured',
      :warnings => [],
      :errors => []
    }
  end
end
