require "compress/deflate"
require "compress/gzip"
require "mime"

# Logs the output via `logger`.
# This is the built-in `Sabo::Tabby::LogHandler` by default which uses STDOUT.
#
# If *newline* is `true` then the log will start with a newline.
#
# If *ignore_pipe* is `true` then it won't be logged if it's not a TTY.
#
# If *emoji* is `false` then it won't prefix the log with a `Sabo::Tabby::EMOJIS[:base]`.
def log(message : String | Colorize::Object(String), newline : Bool = false, ignore_pipe : Bool = false, emoji : Bool = Sabo::Tabby.config.emoji)
  Sabo::Tabby.config.logger.write(
    String.build do |io|
      io << '\n' if newline
      if emoji
        io << Sabo::Tabby::EMOJIS[:base].sample
        io << ' '
      end
      io << message
      io << '\n'
    end,
    ignore_pipe
  )
end

# Returns an error formatted string
def abort_log(message : String) : Colorize::Object(String)
  "[ERROR][#{Sabo::Tabby::APP_NAME}]: #{message}".colorize(:red)
end

# Send a file with given path and base the mime-type on the file extension
# or default `application/octet-stream` mime_type.
#
# ```
# send_file env, "./path/to/file"
# ```
#
# Optionally you can override the mime_type
#
# ```
# send_file env, "./path/to/file", "image/jpeg"
# ```
#
# Also you can set the filename and the disposition
#
# ```
# send_file env, "./path/to/file", filename: "image.jpg", disposition: "attachment"
# ```
def send_file(env : HTTP::Server::Context, path : String, mime_type : String? = nil, *, filename : String? = nil, disposition : String? = nil)
  file_path = File.expand_path(path, Dir.current)
  mime_type ||= MIME.from_filename(file_path, "application/octet-stream")
  mime_type = "#{mime_type}; charset=UTF-8" if mime_type.downcase.starts_with?("text")
  env.response.content_type = mime_type
  env.response.headers["Accept-Ranges"] = "bytes"
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  minsize = 860 # http://webmasters.stackexchange.com/questions/31750/what-is-recommended-minimum-object-size-for-gzip-performance-benefits
  request_headers = env.request.headers
  filesize = File.size(file_path)
  attachment(env, filename, disposition)

  File.open(file_path) do |file|
    if env.request.method == "GET" && env.request.headers.has_key?("Range")
      next multipart(file, env)
    end

    condition = Sabo::Tabby.config.gzip && filesize > minsize && Sabo::Tabby::Utils.zip_types(file_path)
    if condition && request_headers.includes_word?("Accept-Encoding", "gzip")
      env.response.headers["Content-Encoding"] = "gzip"
      Compress::Gzip::Writer.open(env.response) do |deflate|
        IO.copy(file, deflate)
      end
    elsif condition && request_headers.includes_word?("Accept-Encoding", "deflate")
      env.response.headers["Content-Encoding"] = "deflate"
      Compress::Deflate::Writer.open(env.response) do |deflate|
        IO.copy(file, deflate)
      end
    else
      env.response.content_length = filesize
      IO.copy(file, env.response)
    end
  end
  return
end

# Send a file with given data and default `application/octet-stream` mime_type.
#
# ```
# send_file env, data_slice
# ```
#
# Optionally you can override the mime_type
#
# ```
# send_file env, data_slice, "image/jpeg"
# ```
#
# Also you can set the filename and the disposition
#
# ```
# send_file env, data_slice, filename: "image.jpg", disposition: "attachment"
# ```
def send_file(env : HTTP::Server::Context, data : Slice(UInt8), mime_type : String? = nil, *, filename : String? = nil, disposition : String? = nil)
  mime_type ||= "application/octet-stream"
  env.response.content_type = mime_type
  env.response.content_length = data.bytesize
  attachment(env, filename, disposition)
  env.response.write data
end

private def multipart(file, env : HTTP::Server::Context)
  # See https://httpwg.org/specs/rfc7233.html
  fileb = file.size
  startb = endb = 0_i64

  if match = env.request.headers["Range"].match /bytes=(\d{1,})-(\d{0,})/
    startb = match[1].to_i64 { 0_i64 } if match.size >= 2
    endb = match[2].to_i64 { 0_i64 } if match.size >= 3
  end

  endb = fileb - 1 if endb == 0

  if startb < endb < fileb
    content_length = 1_i64 + endb - startb
    env.response.status_code = 206
    env.response.content_length = content_length
    env.response.headers["Accept-Ranges"] = "bytes"
    env.response.headers["Content-Range"] = "bytes #{startb}-#{endb}/#{fileb}" # MUST

    file.seek(startb)
    IO.copy(file, env.response, content_length)
  else
    env.response.content_length = fileb
    env.response.status_code = 200 # Range not satisfable, see 4.4 Note
    IO.copy(file, env.response)
  end
end

# Set the Content-Disposition to "attachment" with the specified filename,
# instructing the user agents to prompt to save.
private def attachment(env : HTTP::Server::Context, filename : String? = nil, disposition : String? = nil)
  disposition = "attachment" if disposition.nil? && filename
  if disposition && filename
    env.response.headers["Content-Disposition"] = "#{disposition}; filename=\"#{File.basename(filename)}\""
  end
end
