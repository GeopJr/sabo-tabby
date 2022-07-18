require "colorize"
colors = {
  sabotabby: Colorize::ColorRGB.new(0, 0, 0),
  express:   Colorize::ColorRGB.new(241, 224, 90),
  httpd:     Colorize::ColorRGB.new(170, 0, 0),
  jaguar:    Colorize::ColorRGB.new(0, 180, 171),
  jester:    Colorize::ColorRGB.new(255, 194, 0),
  nginx:     Colorize::ColorRGB.new(0, 150, 57),
  polka:     Colorize::ColorRGB.new(241, 224, 90),
  sinatra:   Colorize::ColorRGB.new(112, 21, 22),
  warp:      Colorize::ColorRGB.new(222, 165, 132),
  else:      Colorize::ColorRGB.new(255, 255, 255),
}
result = Hash(String, Float64).new

Dir.each_child(__DIR__) do |child|
  ext = File.extname(child)
  next unless ext.downcase == ".txt"
  value = /Requests\/sec: (.+)/.match(File.read(Path[__DIR__, child])).try &.[1]
  next if value.nil?
  result[File.basename(child, ext)] = value.to_f
end

sorted_results = result.to_a.sort_by { |k, v| v }.reverse.to_h

sorted_results.each_with_index do |o, i|
  k, v = o
  text = "#{i + 1}. #{k}: #{v.to_i} requests/sec"
  clean_name = k.gsub("-", "").downcase
  puts text.colorize.back(colors[colors.has_key?(clean_name) ? clean_name : "else"])
end

exit unless ARGV.size > 0

puts

case ARGV[0]
when "--svg"
  puts sorted_results.keys.join("\n")
  puts sorted_results.values.map { |x| x.to_i }.join(", ")
when "--chart"
  puts sorted_results.keys
  puts sorted_results.values

  puts '['
  sorted_results.keys.each do |x|
    clean_name = x.gsub("-", "").downcase
    color = colors[colors.has_key?(clean_name) ? clean_name : "else"]

    puts "'rgba(#{color.red}, #{color.green}, #{color.blue}, 1)',"
  end
  puts ']'
end
