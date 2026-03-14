require 'test/unit'

# Override the subprocess-dependent methods
module Test::Unit::CoreAssertions
  def assert_normal_exit(*, **)
    omit "subprocess not available on this platform"
  end

  def assert_separately(*, **)
    omit "subprocess not available on this platform"
  end

  def assert_in_out_err(*, **)
    omit "subprocess not available on this platform"
  end

  def assert_no_memory_leak(*, **)
    omit "subprocess not available on this platform"
  end

  def assert_ruby_status(*, **)
    omit "subprocess not available on this platform"
  end
end

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