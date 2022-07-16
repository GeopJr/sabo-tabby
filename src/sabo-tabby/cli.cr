require "option_parser"
require "yaml"

module Sabo::Tabby
  # Handles all the initialization from the command line & config files.
  class CLI
    TEMPLATE_EXTENSIONS = {".mst", ".html", ".mustache"}
    CONFIG_EXTENSIONS   = {".yaml", ".yml"}
    CONFIG_NAMES        = {"sabo-tabby", "sabotabby", "sabo.tabby"}

    # A config file.
    class Config
      include YAML::Serializable

      getter host : String?
      getter port : Int32?
      getter public_folder : String?
      getter serve_hidden : Bool?

      getter ssl : ConfigSSL?
      getter theme : ConfigTheme?

      getter logging : Bool?
      getter emoji : Bool?
      getter colors : Bool?

      getter server_header : Bool?
      getter gzip : Bool?
      getter directory : ConfigDirectory?
      getter custom_error_page : Bool?
    end

    # The directory options part of the config.
    class ConfigDirectory
      include YAML::Serializable

      getter index : Bool?
      getter listing : Bool?
    end

    # The SSL part of the config.
    class ConfigSSL
      include YAML::Serializable

      getter key : String
      getter cert : String
    end

    # The theming options part of the config.
    class ConfigTheme
      include YAML::Serializable

      getter error : String?
      getter dir : String?
      getter logger : String?
    end

    # Creates a `Sabo::Tabby::CLI` with the specified CLI *args*.
    def initialize(args : Array(String)?)
      @ssl_enabled = false
      @key_file = ""
      @cert_file = ""
      @config = Sabo::Tabby.config

      # Ignore if running in spec.
      {% unless @top_level.has_constant? "Spec" %}
        # If *args* were provided, call `OptionParser`, else try to load config from current dir.
        if args.size > 0
          parse args
        else
          Dir.each_child(".") do |item|
            ext = File.extname(item)
            next unless CONFIG_EXTENSIONS.includes?(ext.downcase) && CONFIG_NAMES.includes?(File.basename(item, ext).downcase)
            configure_config(Path[item])
          end
        end
      {% end %}

      configure_ssl
    end

    # Parses args from CLI.
    private def parse(args : Array(String))
      OptionParser.parse args do |opts|
        opts.banner = <<-BANNER
        #{APP_NAME.colorize(:light_magenta)} #{('v' + VERSION).colorize(:light_magenta)}

        #{"Usage:".colorize(:light_magenta)} #{APP_NAME} [arguments]

        #{"Examples:".colorize(:light_magenta)}
            #{APP_NAME}
            #{APP_NAME} -f ./my_site/
            #{APP_NAME} -b 0.0.0.0 -p 8080 -e flat -d ./dir_listing.mst -l ncsa
            #{APP_NAME} -c ./config.yaml

        #{"Arguments:".colorize(:light_magenta)}
        BANNER
        opts.separator("    Basic".colorize(:light_magenta))
        opts.on("-b HOST", "--bind HOST", "Host to bind [default: #{@config.host_binding}]") do |host_binding|
          @config.host_binding = host_binding
        end
        opts.on("-p PORT", "--port PORT", "Port to listen for connections [default: #{@config.port}]") do |opt_port|
          @config.port = opt_port.to_i
        end
        opts.on("-f DIR", "--public-folder DIR", "Set which folder to server [default: ./]") do |folder|
          configure_public_folder(folder)
        end
        opts.on("-c FILE", "--config FILE", "Load config from file") do |config|
          path = Path[config]
          abort abort_log("\"#{path}\" doesn't exist or is not a YAML file.") unless File.exists?(path) && CONFIG_EXTENSIONS.includes?(File.extname(path).downcase)
          configure_config(path)
        end
        opts.on("--serve-hidden", "Enable serving hidden folders and files") do
          @config.serve_hidden = true
        end
        opts.on("--licenses", "Shows the licenses of the app and its dependencies") do
          puts LICENSE
          exit 0
        end
        opts.on("-h", "--help", "Shows this help") do
          puts opts
          exit 0
        end

        opts.separator
        opts.separator("    SSL".colorize(:light_magenta))
        opts.on("-s", "--ssl", "Enables SSL") do
          @ssl_enabled = true
        end
        opts.on("--ssl-key-file FILE", "SSL key file") do |key_file|
          @key_file = key_file
        end
        opts.on("--ssl-cert-file FILE", "SSL certificate file") do |cert_file|
          @cert_file = cert_file
        end

        opts.separator
        opts.separator("    Theming".colorize(:light_magenta))
        opts.on("-e THEME", "--error-page-theme THEME", "Either error page theme or path to custom mustache file [available: #{Sabo::Tabby::Config::ErrorPageTheme.names.sort.join(", ")}] [default: #{Sabo::Tabby::Config::ErrorPageTheme.from_value(0)}]") do |theme|
          @config.theme["error_page"] = configure_theme(Sabo::Tabby::Config::ErrorPageTheme, theme)
        end
        opts.on("-d THEME", "--dir-listing-theme THEME", "Either dir listing theme or path to custom mustache file [available: #{Sabo::Tabby::Config::DirectoryListingTheme.names.sort.join(", ")}] [default: #{Sabo::Tabby::Config::DirectoryListingTheme.from_value(0)}]") do |theme|
          @config.theme["dir_listing"] = configure_theme(Sabo::Tabby::Config::DirectoryListingTheme, theme)
        end
        opts.on("-l STYLE", "--logger-style STYLE", "Log style [available: #{Sabo::Tabby::Config::LoggerStyle.names.sort.join(", ")}] [default: #{Sabo::Tabby::Config::LoggerStyle.from_value(0)}]") do |style|
          @config.logger_style = configure_logger_style(style)
        end

        opts.separator
        opts.separator("    Logging".colorize(:light_magenta))
        opts.on("--no-logging", "Disable logging") do
          @config.logging = false
        end
        opts.on("--no-emoji", "Disable emojis in log") do
          @config.emoji = false
        end
        opts.on("--no-colors", "Disable colored output (already disabled in non-tty)") do
          Colorize.enabled = false
        end

        opts.separator
        opts.separator("    Options".colorize(:light_magenta))
        opts.on("--no-server-header", "Disable the 'Server' header") do
          @config.server_header = false
        end
        opts.on("--no-gzip", "Disable gzip") do
          @config.gzip = false
        end
        opts.on("--no-dir-index", "Disable serving /index.html on /") do
          @config.dir_index = false
        end
        opts.on("--no-dir-listing", "Disable directory listing") do
          @config.dir_listing = false
        end
        opts.on("--no-error-page", "Disable custom error page") do
          @config.error_page = false
        end

        opts.invalid_option do |flag|
          message = "#{flag} is not a valid option."

          # Only if running in spec.
          {% if @top_level.has_constant? "Spec" %}
            next raise message
          {% end %}

          STDERR.puts abort_log(message)
          STDERR.puts opts
          exit(1)
        end
      end
    end

    # Configues `Sabo::Tabby::Config` from config file.
    private def configure_config(config_path : Path)
      config = File.open(config_path) do |file|
        Config.from_yaml(file)
      end

      unless (config_host = config.host).nil?
        @config.host_binding = config_host
      end
      unless (config_port = config.port).nil?
        @config.port = config_port
      end
      unless (config_public_folder = config.public_folder).nil?
        configure_public_folder(config_public_folder, config_path.parent)
      end
      unless (config_serve_hidden = config.serve_hidden).nil?
        @config.serve_hidden = config_serve_hidden
      end

      unless (config_ssl = config.ssl).nil?
        unless config_ssl.key == "" || config_ssl.cert == ""
          @ssl_enabled = true
          @key_file = Path[config_ssl.key].expand(config_path.parent).to_s
          @cert_file = Path[config_ssl.cert].expand(config_path.parent).to_s
        end
      end
      unless (config_theme = config.theme).nil?
        unless (config_theme_error = config_theme.error).nil?
          @config.theme["error_page"] = configure_theme(Sabo::Tabby::Config::ErrorPageTheme, config_theme_error, config_path.parent)
        end

        unless (config_theme_dir = config_theme.dir).nil?
          @config.theme["dir_listing"] = configure_theme(Sabo::Tabby::Config::DirectoryListingTheme, config_theme_dir, config_path.parent)
        end

        unless (config_logger_style = config_theme.logger).nil?
          @config.logger_style = configure_logger_style(config_logger_style)
        end
      end

      unless (config_logging = config.logging).nil?
        @config.logging = config_logging
      end
      unless (config_emoji = config.emoji).nil?
        @config.emoji = config_emoji
      end
      unless (config_colors = config.colors).nil?
        Colorize.enabled = config_colors
      end

      unless (config_server_header = config.server_header).nil?
        @config.server_header = config_server_header
      end
      unless (config_gzip = config.gzip).nil?
        @config.gzip = config_gzip
      end
      unless (config_dir = config.directory).nil?
        unless (config_dir_listing = config_dir.listing).nil?
          @config.dir_listing = config_dir_listing
        end
        unless (config_dir_index = config_dir.index).nil?
          @config.dir_index = config_dir_index
        end
      end
      unless (config_custom_error_page = config.custom_error_page).nil?
        @config.error_page = config_custom_error_page
      end
    end

    # Returns the `Sabo::Tabby::Config::LoggerStyle` based on the *style* provided.
    #
    # If *style* not in `Sabo::Tabby::Config::LoggerStyle`, it returns `Sabo::Tabby::Config::LoggerStyle::Default`.
    private def configure_logger_style(style : String) : Sabo::Tabby::Config::LoggerStyle
      result = Sabo::Tabby::Config::LoggerStyle::Default
      unless (logger_style = Sabo::Tabby::Config::LoggerStyle.parse?(style)).nil?
        result = logger_style
      end
      result
    end

    # Configures the `Sabo::Tabby::Config#public_folder`.
    #
    # *parent* is being used in case the folder is relative to the config file that might not be in the current dir.
    private def configure_public_folder(folder : String, parent : Path = Path[Dir.current])
      path = Path[folder].expand(parent)

      if Dir.exists?(path)
        @config.public_folder = path.to_s
      else
        abort abort_log("\"#{path}\" doesn't exist.")
      end
    end

    # Returns either the *themes*'s item or a `Crustache::Syntax::Template` instance based on *theme*.
    #
    # If *theme* is part of the *themes* enum, it returns it.
    #
    # Else if it's a file path (relative to *parent*, in case it's relative to the config file that might not be in the current dir) and it's a mustache file, it parses and returns it.
    #
    # Else it returns the *theme*'s first item.
    private def configure_theme(themes : Enum.class, theme : String, parent : Path = Path[Dir.current])
      result = themes.parse?(theme)
      if result.nil?
        path = Path[theme].expand(parent)
        result = themes.from_value(0)

        if File.exists?(path) && TEMPLATE_EXTENSIONS.includes?(File.extname(path).downcase)
          result = File.open(path) do |file|
            Crustache.parse(file)
          end
        end
      end
      result
    end

    # Configures SSL
    private def configure_ssl
      {% unless flag?(:without_openssl) %}
        if @ssl_enabled
          abort abort_log("SSL Key \"#{@key_file}\" doesn't exist.") unless @key_file && File.exists?(@key_file)
          abort abort_log("SSL Certificate \"#{@key_file}\" doesn't exist.") unless @cert_file && File.exists?(@cert_file)
          ssl = Sabo::Tabby::SSL.new
          ssl.key_file = @key_file.not_nil!
          ssl.cert_file = @cert_file.not_nil!
          Sabo::Tabby.config.ssl = ssl.context
        end
      {% end %}
    end

    # Only if running in spec.
    {% if @top_level.has_constant? "Spec" %}
      def clear_config
        @config = Sabo::Tabby::Config.new
      end

      def config : Sabo::Tabby::Config
        @config
      end

      def parse(args : Array(String))
        previous_def
      end

      def configure_config(config_path : Path)
        previous_def
      end

      def configure_logger_style(style : String)
        previous_def
      end

      def configure_public_folder(folder : String, parent : Path = Path[Dir.current])
        previous_def
      end

      def configure_theme(themes : Enum.class, theme : String, parent : Path = Path[Dir.current])
        previous_def
      end

      def configure_ssl
        previous_def
      end
    {% end %}
  end
end
