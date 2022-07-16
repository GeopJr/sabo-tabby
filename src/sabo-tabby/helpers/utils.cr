module Sabo::Tabby
  module Utils
    ZIP_TYPES = {".htm", ".html", ".txt", ".css", ".js", ".svg", ".json", ".xml", ".otf", ".ttf", ".woff", ".woff2"}

    # Returns whether a file should be compressed
    def self.zip_types(path : String | Path) # https://github.com/h5bp/server-configs-nginx/blob/main/nginx.conf
      ZIP_TYPES.includes? File.extname(path)
    end
  end
end
