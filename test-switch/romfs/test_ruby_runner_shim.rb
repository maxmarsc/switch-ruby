require 'test/unit'

# Load test files
%w[
  test/ruby/test_array
  test/ruby/test_comparable
  test/ruby/test_range
].each do |f|
  begin
    load "romfs:/#{f}.rb"
  rescue LoadError => e
    puts "SKIP #{f}: #{e.message}"
  end
end