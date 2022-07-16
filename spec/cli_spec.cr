require "./spec_helper"

describe Sabo::Tabby::CLI do
  r = Random.new

  after_each do
    Colorize.enabled = COLORS_ENABLED
  end

  describe "config file" do
    tempfile = File.tempfile("sabo.tabby.yaml") do |file|
      config = <<-YAML
        host: #{r.rand(255)}.#{r.rand(255)}.#{r.rand(255)}.#{r.rand(255)}
        port: #{r.rand(9999)}
        public_folder: ./
        serve_hidden: #{r.next_bool}

        logging: #{r.next_bool}
        emoji: #{r.next_bool}
        colors: #{r.next_bool}

        server_header: #{r.next_bool}
        gzip: #{r.next_bool}
        custom_error_page: #{r.next_bool}
        
        ssl:
          key: #{r.hex}
          cert: #{r.hex}
        
        directory:
          index: #{r.next_bool}
          listing: #{r.next_bool}
        
        theme:
          error: #{Sabo::Tabby::Config::ErrorPageTheme.names.sample}
          dir: #{Sabo::Tabby::Config::DirectoryListingTheme.names.sample}
          logger: #{Sabo::Tabby::Config::LoggerStyle.names.sample}
        YAML

      file.print(config)
    end

    before_each do
      Colorize.enabled = COLORS_ENABLED
    end

    after_all do
      tempfile.delete
    end

    it "should be parsed correctly" do
      config_raw = File.read(tempfile.path)
      config = Sabo::Tabby::CLI::Config.from_yaml(config_raw)
      config_yaml = YAML.parse(config_raw)

      Colorize.enabled = COLORS_ENABLED
      YAML.parse(config.to_yaml).should eq(config_yaml)
    end

    it "should set Sabo::Tabby::Config" do
      cli = Sabo::Tabby::CLI.new Array(String).new
      cli.clear_config
      cli.configure_config(Path[tempfile.path])
      config = cli.config

      config_should_be = File.open(tempfile.path) do |file|
        Sabo::Tabby::CLI::Config.from_yaml(file)
      end

      Colorize.enabled = COLORS_ENABLED
      config.host_binding.should eq(config_should_be.host)
      config.port.should eq(config_should_be.port)
      # its actually the file's path as the path is relative to the config
      config.public_folder.should eq(Path[tempfile.path].expand.parent.to_s.rchop('/') + '/')
      config.serve_hidden.should eq(config_should_be.serve_hidden)

      config.logging.should eq(config_should_be.logging)
      config.emoji.should eq(config_should_be.emoji)

      config.server_header.should eq(config_should_be.server_header)
      config.gzip.should eq(config_should_be.gzip)
      config.error_page.should eq(config_should_be.custom_error_page)

      config.dir_index.should eq(config_should_be.directory.try &.index)
      config.dir_listing.should eq(config_should_be.directory.try &.listing)

      config.theme["error_page"].to_s.should eq(config_should_be.theme.try &.error)
      config.theme["dir_listing"].to_s.should eq(config_should_be.theme.try &.dir)
      config.logger_style.to_s.should eq(config_should_be.theme.try &.logger)
    end
  end

  describe "logger style" do
    cli = Sabo::Tabby::CLI.new Array(String).new

    it "should return the Sabo::Tabby::Config::LoggerStyle from string" do
      style = Sabo::Tabby::Config::LoggerStyle.from_value(1) # not default

      cli.configure_logger_style(style.to_s).should eq(style)
    end

    it "should return the default if style is not part of Sabo::Tabby::Config::LoggerStyle" do
      style = r.hex

      cli.configure_logger_style(style).should eq(Sabo::Tabby::Config::LoggerStyle::Default)
    end
  end

  describe "public folder" do
    cli = Sabo::Tabby::CLI.new Array(String).new

    it "should set the Sabo::Tabby.config.public_folder if it exists" do
      cli.clear_config
      config = cli.config
      current_public_folder = config.public_folder

      folder = Path[Dir.tempdir, r.hex(5)]
      Dir.mkdir(folder)
      cli.configure_public_folder(folder.to_s)

      config.public_folder.should eq(folder.to_s)
      config.public_folder = current_public_folder
    end

    it "should abort if public_folder does not exist" do
      folder = Path[Dir.tempdir, r.hex(5)]

      abort_message = disable_colorize { abort_log("\"#{folder}\" doesn't exist.") }
      result = disable_colorize { cli.configure_public_folder(folder.to_s) }

      result.should eq(abort_message)
    end
  end

  describe "page themes" do
    cli = Sabo::Tabby::CLI.new Array(String).new
    page_themes = {
      Sabo::Tabby::Config::ErrorPageTheme,
      Sabo::Tabby::Config::DirectoryListingTheme,
    }

    it "should return the Sabo::Tabby::Config::*Theme from string" do
      page_themes.each do |theme_enum_class|
        style = theme_enum_class.from_value(1)

        cli.configure_theme(theme_enum_class, style.to_s).should eq(style)
      end
    end

    it "should return the default if style not in  Sabo::Tabby::Config::*Theme" do
      page_themes.each do |theme_enum_class|
        style = r.hex

        cli.configure_theme(theme_enum_class, style.to_s).should eq(theme_enum_class.from_value(0))
      end
    end

    it "should return a Crustache instance if a path to a moustache file is provided" do
      mst = File.tempfile("template.mst") do |file|
        config = <<-MST
          {{test}}
          MST

        file.print(config)
      end

      page_themes.each do |theme_enum_class|
        model = {"test" => r.hex}
        style = cli.configure_theme(theme_enum_class, mst.path, Path[Dir.tempdir])

        style.is_a?(Crustache::Syntax::Template).should be_true
        Crustache.render(style.as(Crustache::Syntax::Template), model).should eq(model["test"])
      end
      mst.delete
    end
  end

  describe "cli args" do
    results = {
      bind:          "#{r.rand(255)}.#{r.rand(255)}.#{r.rand(255)}.#{r.rand(255)}",
      port:          r.rand(9999),
      public_folder: Dir.tempdir,
      serve_hidden:  r.next_bool,

      ssl:           r.next_bool,
      ssl_key_file:  r.hex,
      ssl_cert_file: r.hex,

      error_page_theme:  Sabo::Tabby::Config::ErrorPageTheme.names.sample,
      dir_listing_theme: Sabo::Tabby::Config::DirectoryListingTheme.names.sample,
      logger_style:      Sabo::Tabby::Config::LoggerStyle.names.sample,

      no_logging: r.next_bool,
      no_emoji:   r.next_bool,
      no_colors:  r.next_bool,

      no_server_header: r.next_bool,
      no_gzip:          r.next_bool,
      no_dir_index:     r.next_bool,
      no_dir_listing:   r.next_bool,
      no_error_page:    r.next_bool,
    }
    args = {
      "--bind=#{results[:bind]}",
      "--port=#{results[:port]}",
      "--public-folder=#{results[:public_folder]}",
      "#{results[:serve_hidden] ? "--serve-hidden" : nil}",

      "#{results[:ssl] ? "--ssl" : nil}",
      "--ssl-key-file=#{results[:ssl_key_file]}",
      "--ssl-cert-file=#{results[:ssl_cert_file]}",

      "--error-page-theme=#{results[:error_page_theme]}",
      "--dir-listing-theme=#{results[:dir_listing_theme]}",
      "--logger-style=#{results[:logger_style]}",

      "#{results[:no_logging] ? "--no-logging" : nil}",
      "#{results[:no_emoji] ? "--no-emoji" : nil}",
      "#{results[:no_colors] ? "--no-colors" : nil}",

      "#{results[:no_server_header] ? "--no-server-header" : nil}",
      "#{results[:no_gzip] ? "--no-gzip" : nil}",
      "#{results[:no_dir_index] ? "--no-dir-index" : nil}",
      "#{results[:no_dir_listing] ? "--no-dir-listing" : nil}",
      "#{results[:no_error_page] ? "--no-error-page" : nil}",
    }

    it "should set config" do
      cli = Sabo::Tabby::CLI.new Array(String).new
      cli.clear_config
      cli.parse(args.to_a)
      config = cli.config

      Colorize.enabled = COLORS_ENABLED
      config.host_binding.should eq(results[:bind])
      config.port.should eq(results[:port])
      config.public_folder.should eq(Dir.tempdir)
      config.serve_hidden.should eq(results[:serve_hidden])

      config.theme["error_page"].to_s.should eq(results[:error_page_theme])
      config.theme["dir_listing"].to_s.should eq(results[:dir_listing_theme])
      config.logger_style.to_s.should eq(results[:logger_style])

      config.logging.should eq(!results[:no_logging])
      config.emoji.should eq(!results[:no_emoji])

      config.server_header.should eq(!results[:no_server_header])
      config.gzip.should eq(!results[:no_gzip])
      config.dir_index.should eq(!results[:no_dir_index])
      config.dir_listing.should eq(!results[:no_dir_listing])
      config.error_page.should eq(!results[:no_error_page])
    end
  end
end
