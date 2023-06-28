module Sabo::Tabby
  create_theme_index "error_page", ["tqila", "gradient", "boring"]

  class HTTP::Server::Response
    record ErrorPage, status_code : Int32, message : String, theme : String do
      getter logo : String = Sabo::Tabby::LOGO

      def css : Tuple
        {Sabo::Tabby::RESET_CSS, Sabo::Tabby::ERROR_PAGE_INDEX[theme.downcase]}
      end

      ECR.def_to_s "#{__DIR__}/ecr/error_page.ecr"
    end

    private def error_page(status_code : Int32, message : String)
      theme = Sabo::Tabby.config.theme["error_page"]
      # If it's a Mustache file, create a model and render it, else render the ecr theme.
      if theme.is_a?(Crustache::Syntax::Template)
        model = {
          "status_code" => status_code,
          "message"     => message,
        }

        Crustache.render theme, model
      else
        ErrorPage.new(status_code, message, theme.to_s).to_s
      end
    end

    def respond_with_status(status : HTTP::Status, message : String? = nil)
      check_headers
      reset
      @status = status
      @status_message = message ||= @status.description
      self.headers.add "Server", Sabo::Tabby::SERVER_HEADER if Sabo::Tabby.config.server_header

      # If there's a file with error_code.html, (eg 404.html) in the public dir, use that.
      if File.exists?("#{Sabo::Tabby.config.public_folder}/#{status_code}.html")
        self.content_type = "text/html; charset=UTF-8"
        self << File.read("#{Sabo::Tabby.config.public_folder}/#{status_code}.html")
      # If HTML pages are enabled, call `error_page` else return a basic text/plain one.
      elsif Sabo::Tabby.config.error_page
        self.content_type = "text/html; charset=UTF-8"
        self << error_page(@status.code, @status_message.to_s) << '\n'
      else
        self.content_type = "text/plain; charset=UTF-8"
        self << @status.code << ' ' << message << '\n'
      end
      close
    end
  end
end
