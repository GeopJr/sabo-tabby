module Sabo::Tabby
  enum Config::LoggerStyle
    Default
    Extended
    NCSA
    NCSA_Extended
    Kemal
  end

  # Uses `STDOUT` by default and handles the logging of request/response process time.
  class LogHandler
    include HTTP::Handler

    TTY = STDOUT.tty?

    macro generate_loggers(io)
      # Colorize with green if successful else red.
      Colorize.with.fore(success ? :green : :red).surround({{io}}) do
        case Sabo::Tabby.config.logger_style
        when Sabo::Tabby::Config::LoggerStyle::NCSA, Sabo::Tabby::Config::LoggerStyle::NCSA_Extended
          ncsa(context, io: {{io}})
        when Sabo::Tabby::Config::LoggerStyle::Kemal
          kemal(context, elapsed_text(elapsed_time), io: {{io}})
        else
          sabo(context, elapsed_text(elapsed_time), success, io: {{io}})
        end
      end
    end

    def initialize(@io : IO = STDOUT)
    end

    def call(context : HTTP::Server::Context)
      elapsed_time = Time.measure { call_next(context) }
      success = context.response.status_code < 400

      # In multithreaded mode, STDOUT is not "safe" so we need to
      # create a string instead of appending directly to it.
      #
      # https://github.com/crystal-lang/crystal/issues/8140
      {% if flag?(:preview_mt) %}
        print(String.build do |io|
          generate_loggers(io)
        end)
      {% else %}
        generate_loggers(@io)

        @io.flush if TTY
      {% end %}

      context
    end

    def write(message : String, ignore_pipe : Bool = false)
      return @io if ignore_pipe && !@io.tty?
      @io << message
      @io.flush
      @io
    end

    private def kemal(context : HTTP::Server::Context, elapsed_text : String, io : IO = @io)
      io << Time.utc
      io << ' '
      io << context.response.status_code
      io << ' '
      io << context.request.method
      io << ' '
      io << context.request.resource
      io << ' '
      io << elapsed_text
      io << '\n'
    end

    private def sabo(context : HTTP::Server::Context, elapsed_text : String, success : Bool, emoji : Bool = Sabo::Tabby.config.emoji, extended : Bool = Sabo::Tabby.config.logger_style == Sabo::Tabby::Config::LoggerStyle::Extended, io : IO = @io)
      req = context.request
      res = context.response

      if emoji
        io << EMOJIS[success ? :happy : :sad].sample
        io << ' '
      end
      io << '['
      io << Time.utc
      io << "] ["
      unless (address = req.remote_address).nil?
        if address.is_a?(Socket::IPAddress)
          io << address.address
        elsif address.is_a?(Socket::UNIXAddress)
          io << address.path
        else
          io << "0.0.0.0"
        end
      else
        io << "0.0.0.0"
      end
      io << "] ["
      io << context.response.status_code
      io << "] ["
      io << context.request.method
      io << "] ["
      io << context.request.resource
      io << "] "
      if extended
        io << "["
        io << res.headers.fetch("Content-Length", "compressed")
        io << "] ["
        io << req.headers.fetch("Referer", "-")
        io << "] ["
        io << req.headers.fetch("User-Agent", "-")
        io << "] "
      end
      io << "["
      io << elapsed_text
      io << ']'
      io << '\n'
    end

    # https://en.wikipedia.org/wiki/Common_Log_Format
    private def ncsa(context : HTTP::Server::Context, extended : Bool = Sabo::Tabby.config.logger_style == Sabo::Tabby::Config::LoggerStyle::NCSA_Extended, io : IO = @io)
      req = context.request
      res = context.response

      unless (address = req.remote_address).nil?
        if address.is_a?(Socket::IPAddress)
          io << address.address
        elsif address.is_a?(Socket::UNIXAddress)
          io << address.path
        else
          io << "0.0.0.0"
        end
      else
        io << "0.0.0.0"
      end
      io << " - - ["
      io << Time.local.to_s("%d/%b/%Y:%H:%M:%S %z")
      io << "] \""
      io << req.method
      io << ' '
      io << req.resource
      io << ' '
      io << req.version
      io << "\" "
      io << res.status_code
      io << ' '
      io << res.headers.fetch("Content-Length", "0")
      if extended
        io << " \""
        io << req.headers.fetch("Referer", "-")
        io << "\" \""
        io << req.headers.fetch("User-Agent", "-")
        io << '"'
      end
      io << '\n'
    end

    private def elapsed_text(elapsed)
      millis = elapsed.total_milliseconds
      return "#{millis.round(2)}ms" if millis >= 1

      "#{(millis * 1000).round(2)}µs"
    end
  end
end
