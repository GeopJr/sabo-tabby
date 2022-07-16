require "./spec_helper"

private def handle_request(request, decompress = true) : HTTP::Client::Response
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler = Sabo::Tabby::StaticFileHandler.new "#{__DIR__}/static"
  handler.call context
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: decompress)
end

describe Sabo::Tabby::StaticFileHandler do
  file = File.open "#{__DIR__}/static/cats/small.txt"
  file_size = file.size

  it "should serve a file with content type and etag" do
    response = handle_request HTTP::Request.new("GET", "/cats/small.txt")
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/plain; charset=UTF-8"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/cats/small.txt"))
  end

  it "should serve an image file with content type" do
    response = handle_request HTTP::Request.new("GET", "/cats/garfield.svg")
    response.status_code.should eq(200)
    response.headers["Content-Type"].downcase.should match(/^image\/.+(?<!charset=utf-8)$/) # shouldnt set charset
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/cats/garfield.svg"))
  end

  it "should serve the 'index.html' file when a directory is requested and index serving is enabled" do
    Sabo::Tabby.config.dir_index = true

    response = handle_request HTTP::Request.new("GET", "/")
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq "text/html; charset=UTF-8"
    response.headers["Etag"].should contain "W/\""
    response.body.should eq(File.read("#{__DIR__}/static/index.html"))
  end

  it "should respond with 304 if file has not changed" do
    response = handle_request HTTP::Request.new("GET", "/cats/small.txt")
    response.status_code.should eq(200)
    etag = response.headers["Etag"]

    headers = HTTP::Headers{"If-None-Match" => etag}
    response = handle_request HTTP::Request.new("GET", "/cats/small.txt", headers)
    response.headers["Content-Type"]?.should be_nil
    response.status_code.should eq(304)
    response.body.should eq ""
  end

  it "should not list directory's entries" do
    Sabo::Tabby.config.dir_listing = false

    response = handle_request HTTP::Request.new("GET", "/cats/")
    response.status_code.should eq(404)
  end

  it "should list directory's entries" do
    Sabo::Tabby.config.dir_listing = true

    response = handle_request HTTP::Request.new("GET", "/cats/")
    response.status_code.should eq(200)
    response.body.should match(/big.txt/)
  end

  it "should gzip a file if config is true, headers accept gzip and file is > 880 bytes" do
    Sabo::Tabby.config.gzip = true

    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle_request HTTP::Request.new("GET", "/cats/big.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"].should eq "gzip"
  end

  it "should not gzip a file if config is true, headers accept gzip and file is < 880 bytes" do
    Sabo::Tabby.config.gzip = true

    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle_request HTTP::Request.new("GET", "/cats/small.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should be_nil
  end

  it "should not gzip a file if config is false, headers accept gzip and file is > 880 bytes" do
    Sabo::Tabby.config.gzip = false

    headers = HTTP::Headers{"Accept-Encoding" => "gzip, deflate, sdch, br"}
    response = handle_request HTTP::Request.new("GET", "/cats/big.txt", headers), decompress: false
    response.status_code.should eq(200)
    response.headers["Content-Encoding"]?.should be_nil
  end

  it "should not serve a not found file" do
    response = handle_request HTTP::Request.new("GET", "/not_found_file.txt")
    response.status_code.should eq(404)
  end

  it "should not serve a not found directory" do
    response = handle_request HTTP::Request.new("GET", "/not_found_dir/")
    response.status_code.should eq(404)
  end

  it "should not serve a file as directory" do
    response = handle_request HTTP::Request.new("GET", "/cats/small.txt/")
    response.status_code.should eq(404)
  end

  it "should not serve hidden files and folders" do
    Sabo::Tabby.config.serve_hidden = false

    response = handle_request HTTP::Request.new("GET", "/cats/.dog")
    response.status_code.should eq(404)

    response = handle_request HTTP::Request.new("GET", "/.dogs/")
    response.status_code.should eq(404)

    response = handle_request HTTP::Request.new("GET", "/.dogs/ragoon.txt")
    response.status_code.should eq(404)
  end

  it "should serve hidden files or folders" do
    Sabo::Tabby.config.serve_hidden = true
    Sabo::Tabby.config.dir_listing = true

    response = handle_request HTTP::Request.new("GET", "/cats/.dog")
    response.status_code.should eq(200)

    response = handle_request HTTP::Request.new("GET", "/.dogs/")
    response.status_code.should eq(200)

    response = handle_request HTTP::Request.new("GET", "/.dogs/ragoon.txt")
    response.status_code.should eq(200)
  end

  it "should handle only GET and HEAD methods" do
    %w(GET HEAD).each do |method|
      response = handle_request HTTP::Request.new(method, "/cats/small.txt")
      response.status_code.should eq(200)
    end

    %w(POST PUT DELETE).each do |method|
      response = handle_request HTTP::Request.new(method, "/cats/small.txt")
      response.status_code.should eq(405)
      response.headers["Allow"].should eq("GET, HEAD")
    end
  end

  it "should send part of files when requested (RFC7233)" do
    %w(POST PUT DELETE HEAD).each do |method|
      headers = HTTP::Headers{"Range" => "0-100"}
      response = handle_request HTTP::Request.new(method, "/cats/small.txt", headers)
      response.status_code.should_not eq(206)
      response.headers.has_key?("Content-Range").should eq(false)
    end

    %w(GET).each do |method|
      headers = HTTP::Headers{"Range" => "0-100"}
      response = handle_request HTTP::Request.new(method, "/cats/small.txt", headers)
      response.status_code.should eq(206 || 200)
      if response.status_code == 206
        response.headers.has_key?("Content-Range").should eq true
        match = response.headers["Content-Range"].match(/bytes (\d+)-(\d+)\/(\d+)/)
        match.should_not be_nil
        if match
          start_range = match[1].to_i { 0 }
          end_range = match[2].to_i { 0 }
          range_size = match[3].to_i { 0 }

          range_size.should eq file_size
          (end_range < file_size).should eq true
          (start_range < end_range).should eq true
        end
      end
    end
  end
end
