require "http"
require "json"
require "uri"
require "colorize"
require "crustache"

require "./sabo-tabby/*"
require "./sabo-tabby/helpers/*"

module Sabo::Tabby
  # The app name, shown in logs and CLI messages.
  APP_NAME = "sabo-tabby"
  # The app version, read from its `shard.yml`.
  VERSION = {{read_file("#{__DIR__}/../shard.yml").split("version: ")[1].split("\n")[0]}}
  # The app logo, URI encoded for usage in ecr.
  LOGO = URI.encode_path({{read_file("#{__DIR__}/../logo.svg")}})
  # The `Server` header.
  SERVER_HEADER = "#{Sabo::Tabby::APP_NAME}/#{Sabo::Tabby::VERSION}"
  # Licenses of sabo-tabby, kemal and shards
  LICENSE = {{run("./licenses.cr").stringify}}
  # Emojis used in logs.
  EMOJIS = {
    base: {
      "🐈",
      "🐱",
    },
    happy: {
      "😺",
      "😽",
      "😻",
      "😸",
    },
    sad: {
      "😿",
      "🙀",
      "😾",
    },
    sleepy: {
      "😴",
      "😪",
      "🥱",
      "💤",
      "🛏️",
    },
  }

  # Only colorize on tty.
  Colorize.on_tty_only!

  # The command to run a `Sabo::Tabby` application.
  #
  # To use custom command line arguments, set args to nil
  def self.run(args : Array(String)? = ARGV) : Nil
    Sabo::Tabby::CLI.new args
    config = Sabo::Tabby.config
    config.setup
    setup_trap_signal
    server = config.server ||= HTTP::Server.new(config.handlers)
    config.running = true

    # Abort if block called `Sabo::Tabby#stop`
    return unless config.running

    unless server.each_address { |_| break true }
      begin
        {% if flag?(:without_openssl) %}
          server.bind_tcp(config.host_binding, config.port)
        {% else %}
          if ssl = config.ssl
            server.bind_tls(config.host_binding, config.port, ssl)
          else
            server.bind_tcp(config.host_binding, config.port)
          end
        {% end %}
      rescue ex
        unless (msg = ex.message).nil?
          abort abort_log(msg)
        else
          raise ex
        end
      end
    end

    display_startup_message(config, server)

    server.listen
  end

  # Logs a startup message.
  def self.display_startup_message(config : Sabo::Tabby::Config, server : HTTP::Server) : Nil
    addresses = server.addresses.join ", " { |address| "#{config.scheme}://#{address}" }
    log "[#{APP_NAME}] is ready to lead at #{addresses.colorize.mode(:bold)}".colorize(:light_magenta), ignore_pipe: true
  end

  # Stops the server.
  def self.stop : Nil
    abort "#{Sabo::Tabby.config.emoji ? EMOJIS[:sad].sample : nil} [#{APP_NAME}] has already gone to bed. #{Sabo::Tabby.config.emoji ? EMOJIS[:sleepy].sample : nil}".colorize(:red) unless config.running
    if server = config.server
      server.close unless server.closed?
      config.running = false
    else
      abort abort_log("Sabo::Tabby.config.server is not set. Please use Sabo::Tabby.run to set the server.")
    end
  end

  private def self.setup_trap_signal : Nil
    Signal::INT.trap do
      log(
        "[#{APP_NAME}] is going to bed... #{Sabo::Tabby.config.emoji ? EMOJIS[:sleepy].sample : nil}".colorize(:light_magenta),
        newline: true,
        ignore_pipe: true
      )
      Sabo::Tabby.stop
      exit
    end
  end
end

# Ignore if running in spec.
{% unless @top_level.has_constant? "Spec" %}
  Sabo::Tabby.run
{% end %}
