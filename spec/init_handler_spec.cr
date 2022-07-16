require "./spec_helper"

describe "Sabo::Tabby::InitHandler" do
  it "should initialize context with Content-Type: text/html; charset=UTF-8" do
    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Sabo::Tabby::InitHandler::INSTANCE.next = ->(_context : HTTP::Server::Context) {}
    Sabo::Tabby::InitHandler::INSTANCE.call(context)
    context.response.headers["Content-Type"].should eq "text/html; charset=UTF-8"
  end

  it "should initialize context with Server: sabo-tabby/VERSION" do
    Sabo::Tabby.config.server_header = true

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Sabo::Tabby::InitHandler::INSTANCE.call(context)
    context.response.headers["Server"].should eq "sabo-tabby/#{Sabo::Tabby::VERSION}"
  end

  it "shouldn't initialize context with Server: sabo-tabby/VERSION if it's disabled" do
    Sabo::Tabby.config.server_header = false

    request = HTTP::Request.new("GET", "/")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Sabo::Tabby::InitHandler::INSTANCE.call(context)
    context.response.headers["Server"]?.should be_nil
  end
end
