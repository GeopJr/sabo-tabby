module Sabo::Tabby
  # Initializes the context with default values, such as
  # *Content-Type* or *Server* headers.
  class InitHandler
    include HTTP::Handler

    INSTANCE = new

    def call(context : HTTP::Server::Context)
      context.response.headers.add "Server", Sabo::Tabby::SERVER_HEADER if Sabo::Tabby.config.server_header
      context.response.content_type = "text/html; charset=UTF-8" unless context.response.headers.has_key?("Content-Type")
      call_next context
    end
  end
end
