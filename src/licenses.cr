require "colorize"
Colorize.enabled = true

APP_NAME      = {{read_file("#{__DIR__}/../shard.yml").split("name: ")[1].split("\n")[0]}}
LICENSE_FILES = {"LICENSE", "LICENSE.md", "UNLICENSE"}
OLD_LICENSE   = <<-KEMAL_LICENSE
#{"Kemal".capitalize.colorize.mode(:underline).mode(:bold)}
Copyright (c) 2016 Serdar Doğruyol

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE

KEMAL_LICENSE

licenses = [] of String
root = Path[__DIR__, ".."]
lib_folder = root / "lib"

LICENSE_FILES.each do |license_file|
  license_path = root / license_file
  if File.exists?(license_path)
    licenses << File.read(license_path)
    break
  end
end

licenses << OLD_LICENSE

Dir.each_child(lib_folder) do |shard|
  path = lib_folder / shard
  next if File.file?(path)

  license = nil
  LICENSE_FILES.each do |file|
    license_path = path / file
    if File.exists?(license_path)
      license = license_path
      break
    end
  end

  licenses << "#{shard.capitalize.colorize.mode(:underline).mode(:bold)}\n#{File.read(license)}" unless license.nil?
end

licenses.unshift("#{APP_NAME.capitalize.colorize.mode(:underline).mode(:bold)}")

puts licenses.join('\n')
