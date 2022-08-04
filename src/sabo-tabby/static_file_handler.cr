module Sabo::Tabby
  create_theme_index "directory_listing", ["gradient", "flat", "material"]

  class StaticFileHandler < HTTP::StaticFileHandler
    record DirectoryListing, request_path : String, path : String, children : Array(String), theme : String do
      getter logo : String = Sabo::Tabby::LOGO

      def each_entry
        children.each do |entry|
          next if !Sabo::Tabby.config.serve_hidden && entry.starts_with?('.')
          yield entry, File.file?(Path[path, entry])
        end
      end

      def css : Tuple
        {Sabo::Tabby::RESET_CSS, Sabo::Tabby::DIRECTORY_LISTING_INDEX[theme.downcase]}
      end

      ECR.def_to_s "#{__DIR__}/ecr/directory_listing.ecr"
    end

    private def directory_listing(io, request_path, path)
      theme = Sabo::Tabby.config.theme["dir_listing"]
      # Sort dir items alphabetically.
      sorted_files = Dir.children(path).sort
      request_path_string = request_path.to_s
      # If it's a Mustache file, create a model and render it, else render the ecr theme.
      if theme.is_a?(Crustache::Syntax::Template)
        entries = [] of Hash(String, String | Bool)
        request_path_encoded = URI.encode_path(request_path_string)

        sorted_files.each do |entry|
          next if !Sabo::Tabby.config.serve_hidden && entry.starts_with?('.')
          entries << {"path" => entry, "file" => File.file?(Path[path, entry]), "href" => "#{request_path_encoded}#{URI.encode_path(entry)}"}
        end

        model = {
          "request_path" => request_path_string,
          "entries"      => entries,
        }

        Crustache.render theme, model, Crustache::HashFileSystem.new, io
      else
        DirectoryListing.new(request_path_string, path.to_s, sorted_files, theme.to_s).to_s(io)
      end
    end

    def call(context : HTTP::Server::Context)
      # Only accept "GET" & "HEAD" requests.
      unless {"GET", "HEAD"}.includes?(context.request.method)
        context.response.status_code = 405
        context.response.headers.add("Allow", "GET, HEAD")
        return
      end

      original_path = context.request.path.not_nil!
      request_path = URI.decode(original_path)

      # If `Sabo::Tabby::Config#serve_hidden` is false and the request path includes "./" (hidden file or folder), 404.
      if !Sabo::Tabby.config.serve_hidden && request_path.includes?("/.")
        call_next(context)
        return
      end

      # File path cannot contains '\0' (NUL) because all filesystem I know
      # don't accept '\0' character as file name.
      if request_path.includes? '\0'
        context.response.status_code = 400
        return
      end

      expanded_path = File.expand_path(request_path, "/")
      is_dir_path = if original_path.ends_with?('/') && !expanded_path.ends_with? '/'
                      expanded_path = expanded_path + '/'
                      true
                    else
                      expanded_path.ends_with? '/'
                    end

      file_path = File.join(@public_dir, expanded_path)
      is_dir = Dir.exists?(file_path)

      if request_path != expanded_path
        redirect_to context, expanded_path
      elsif is_dir && !is_dir_path
        redirect_to context, expanded_path + '/'
      end

      if is_dir
        if Sabo::Tabby.config.dir_index && File.exists?(File.join(file_path, "index.html"))
          file_path = File.join(@public_dir, expanded_path, "index.html")

          last_modified = modification_time(file_path)
          add_cache_headers(context.response.headers, last_modified)

          if cache_request?(context, last_modified)
            context.response.status_code = 304
            return
          end
          send_file(context, file_path)
        elsif Sabo::Tabby.config.dir_listing
          context.response.content_type = "text/html; charset=UTF-8"
          directory_listing(context.response, request_path, file_path)
        else
          call_next(context)
        end
      elsif File.exists?(file_path)
        last_modified = modification_time(file_path)
        add_cache_headers(context.response.headers, last_modified)

        if cache_request?(context, last_modified)
          context.response.status_code = 304
          return
        end
        send_file(context, file_path)
      else
        call_next(context)
      end
    end

    private def modification_time(file_path)
      File.info(file_path).modification_time
    end
  end
end
