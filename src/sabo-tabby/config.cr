module Sabo::Tabby
  # The CSS reset used in all ecr templates.
  RESET_CSS = {{read_file("#{__DIR__}/ecr/css/reset.css")}}

  # Macro that expands an array of *styles* into an enum based on *name* and loads their CSS files in memory under a `NamedTuple` based on *name*.
  macro create_theme_index(name, styles)
    {% styles.unshift("default") %}

    # Themes for {{name.id}}
    enum {{"Config::#{name.camelcase.id}Theme".id}}
      {% for style in styles %}
        {{style.capitalize.id}}
      {% end %}
    end

    # CSS files for {{name.id}}
    {{"#{name.upcase.id}_INDEX".id}} = {
      {% for style in styles %}
        {{style.downcase.id}}: {{read_file("#{__DIR__}/ecr/css/#{name.downcase.id}/#{style.downcase.id}.css")}},
      {% end %}
    }
  end

  # Stores all the configuration options for a Sabo::Tabby application.
  #
  # It's a singleton and you can access it like:
  # ```
  # Sabo::Tabby.config
  # ```
  class Config
    INSTANCE = Config.new

    property host_binding : String = "0.0.0.0"
    property port : Int32 = 1312
    property public_folder : String = "."
    # Whether to server hidden files and folders.
    property serve_hidden : Bool = false

    # Hash of themes.
    getter theme : Hash(String, ErrorPageTheme | DirectoryListingTheme | Crustache::Syntax::Template) = Hash(String, ErrorPageTheme | DirectoryListingTheme | Crustache::Syntax::Template).new
    property logger_style : LoggerStyle = :Default

    property logging : Bool = true
    property emoji : Bool = true

    property server_header : Bool = true
    property gzip : Bool = true
    # Whether to redirect / to /index.html.
    property dir_index : Bool = true
    # Whether to list directory files.
    property dir_listing : Bool = true
    # Whether to show an HTML error page or a basic text/plain one.
    property error_page : Bool = true

    getter handlers : Array(HTTP::Handler) = Array(HTTP::Handler).new
    getter logger : Sabo::Tabby::LogHandler = Sabo::Tabby::LogHandler.new
    property server : HTTP::Server?
    property running : Bool = true

    {% if flag?(:without_openssl) %}
      property ssl : Bool? = false
    {% else %}
      property ssl : OpenSSL::SSL::Context::Server?
    {% end %}

    # Only if running in spec.
    {% if @top_level.has_constant? "Spec" %}
      setter logger
    {% end %}

    def initialize
      setup_themes
    end

    def scheme : String
      ssl ? "https" : "http"
    end

    def setup
      setup_handlers
    end

    private def setup_handlers
      @handlers << Sabo::Tabby::InitHandler::INSTANCE
      @handlers << logger if logging
      @handlers << Sabo::Tabby::StaticFileHandler.new(public_folder)
    end

    private def setup_themes
      @theme["error_page"] = ErrorPageTheme::Default
      @theme["dir_listing"] = DirectoryListingTheme::Default
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
