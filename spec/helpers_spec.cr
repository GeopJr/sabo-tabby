require "./spec_helper"

describe "::log" do
  message = "No gods, no masters"
  io = IO::Memory.new

  before_each do
    io = IO::Memory.new
    Sabo::Tabby.config.logger = Sabo::Tabby::LogHandler.new(io)
  end

  it "should use Sabo::Tabby::Config.logger to log a message" do
    log message

    result = io.to_s.split(' ')
    emoji = result.shift

    result.join(' ').should eq("#{message}\n")
    Sabo::Tabby::EMOJIS[:base].should contain(emoji)
  end

  it "should use Sabo::Tabby::Config.logger to log a without emojis set explicitly" do
    log message, emoji: false

    result = io.to_s.split(' ')

    result.join(' ').should eq("#{message}\n")
  end

  it "should use Sabo::Tabby::Config.logger to log a without emojis set on config" do
    Sabo::Tabby.config.emoji = false
    log message

    result = io.to_s.split(' ')

    result.join(' ').should eq("#{message}\n")
    Sabo::Tabby.config.emoji = true
  end

  it "should use Sabo::Tabby::Config.logger to log a message but with a newline at the start" do
    log message, newline: true

    result = io.to_s.split(' ')
    newline, emoji = result.shift
    result[0] = "#{newline}#{result[0]}"

    result.join(' ').should eq("\n#{message}\n")
    Sabo::Tabby::EMOJIS[:base].should contain(emoji.to_s)
  end
end

describe "::abort_log" do
  message = "No gods, no masters"

  it "should return a formatted abort error message" do
    abort_message = disable_colorize do
      abort_log(message).to_s
    end

    abort_message.should eq("[ERROR][#{Sabo::Tabby::APP_NAME}]: #{message}")
  end
end

describe Sabo::Tabby::Utils do
  it "should return whether a file should be compressed" do
    gzip_file = Path["cat", "meow#{Sabo::Tabby::Utils::ZIP_TYPES.sample}"]
    non_gzip_file = Path["cat", "meow.cr"]

    Sabo::Tabby::Utils.zip_types(gzip_file).should be_true
    Sabo::Tabby::Utils.zip_types(non_gzip_file).should be_false
  end
end
