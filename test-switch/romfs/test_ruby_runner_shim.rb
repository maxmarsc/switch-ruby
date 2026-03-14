require 'test/unit'
require 'tmpdir'
require 'fileutils'
require 'tempfile'

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

Test::Unit::Runner.prepend(Module.new do
  def _run_suite(suite, type)
    return super if suite.test_methods.empty?
    puts "START #{suite.name}"
    $stdout.flush
    result = super
    puts "DONE  #{suite.name} (#{result[0]} tests, #{result[1]} assertions)"
    $stdout.flush
    result
  end
end)

# To check
=begin
  test/ruby/test_frozen_error
  test/ruby/test_hash
  test/ruby/test_ifunless
  test/ruby/test_inlinecache
  test/ruby/test_integer
  test/ruby/test_integer_comb
  test/ruby/test_iterator
  test/ruby/test_key_error
  test/ruby/test_keyword
  test/ruby/test_lambda
  test/ruby/test_lazy_enumerator
  test/ruby/test_literal
  test/ruby/test_math
  test/ruby/test_metaclass
  test/ruby/test_method
  test/ruby/test_method_cache
  test/ruby/test_mixed_unicode_escapes
  test/ruby/test_module
  test/ruby/test_name_error
  test/ruby/test_nomethod_error
  test/ruby/test_not
  test/ruby/test_numeric
  test/ruby/test_object
  test/ruby/test_optimization
  test/ruby/test_pack
  test/ruby/test_pattern_matching
  test/ruby/test_primitive
  test/ruby/test_proc
  test/ruby/test_rand
  test/ruby/test_random_formatter
  test/ruby/test_range
  test/ruby/test_rational
  test/ruby/test_rational2
  test/ruby/test_regexp
  test/ruby/test_shapes
  test/ruby/test_sprintf
  test/ruby/test_sprintf_comb
  test/ruby/test_string
  test/ruby/test_stringchar
  test/ruby/test_struct
  test/ruby/test_super
  test/ruby/test_symbol
  test/ruby/test_undef
  test/ruby/test_unicode_escape
  test/ruby/test_variable
  test/ruby/test_warning
  test/ruby/test_whileuntil
  test/ruby/test_yield
=end

# Passing
=begin
test/ruby/test_range
test/ruby/test_comparable
test/ruby/test_array
test/ruby/test_basicinstructions
test/ruby/test_arithmetic_sequence
test/ruby/test_assignment
test/ruby/test_bignum
test/ruby/test_call
test/ruby/test_case
test/ruby/test_clone
test/ruby/test_complex
test/ruby/test_complex2
test/ruby/test_complexrational
test/ruby/test_condition
test/ruby/test_const
test/ruby/test_data
test/ruby/test_defined
test/ruby/test_dup
test/ruby/test_enum
test/ruby/test_exception
test/ruby/test_fixnum
test/ruby/test_float
test/ruby/test_frozen
test/ruby/test_class
test/ruby/test_enumerator
=end

# Load test files
%w[
  test/ruby/test_eval
  test/ruby/test_flip
].each do |f|
  begin
    load "romfs:/#{f}.rb"
  rescue LoadError => e
    puts "SKIP #{f}: #{e.message}"
  end
end

SWITCH_SKIP_TESTS = {
  "TestBasicInstructions" => %w[test_xstr],
  "TestEval" => %w[test_eval_with_toplevel_binding],
  "TestFlip" => %w[test_input_line_number_range],
}

SWITCH_SKIP_TESTS.each do |klass_name, methods|
  klass = Object.const_get(klass_name) rescue next
  methods.each do |m|
    klass.undef_method(m) if klass.method_defined?(m)
  end
end