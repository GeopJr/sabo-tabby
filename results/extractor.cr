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
  puts "#{i + 1}. #{k}: #{v.to_i} requests/sec"
end

if ARGV.size > 0 && ARGV[0] == "--svg"
  puts
  puts sorted_results.keys.join("\n")
  puts sorted_results.values.map { |x| x.to_i }.join(", ")
end
