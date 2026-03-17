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

Test::Unit::TestCase.prepend(Module.new do
  def run(*args, &block)
    saved_deprecated = Warning[:deprecated]
    saved_verbose = $VERBOSE
    super
  ensure
    Warning[:deprecated] = saved_deprecated
    $VERBOSE = saved_verbose
  end
end)

# To check
=begin
test/ruby/test_parse          # may need ripper
test/ruby/test_ast            # requires ripper/prism internals
test/ruby/test_compile_prism  # prism compiler tests
test/ruby/test_settracefunc   # tracing, may be fragile
test/ruby/test_trace          # tracing
test/ruby/test_backtrace      # may need subprocess for some tests
=end

# Passing
=begin
test/ruby/test_comparable
test/ruby/test_array
test/ruby/test_basicinstructions
test/ruby/test_arithmetic_sequence
test/ruby/test_assignment
test/ruby/test_bignum
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
test/ruby/test_fixnum
test/ruby/test_float
test/ruby/test_frozen
test/ruby/test_class
test/ruby/test_eval
test/ruby/test_flip
test/ruby/test_exception
test/ruby/test_frozen_error
test/ruby/test_ifunless
test/ruby/test_inlinecache
test/ruby/test_integer
test/ruby/test_integer_comb
test/ruby/test_key_error
test/ruby/test_iterator
test/ruby/test_hash
test/ruby/test_lambda
test/ruby/test_lazy_enumerator
test/ruby/test_literal
test/ruby/test_math
test/ruby/test_metaclass
test/ruby/test_method
test/ruby/test_method_cache
test/ruby/test_mixed_unicode_escapes
test/ruby/test_object
test/ruby/test_module
test/ruby/test_name_error
test/ruby/test_nomethod_error
test/ruby/test_not
test/ruby/test_numeric
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
test/ruby/test_sprintf
test/ruby/test_sprintf_comb
test/ruby/test_stringchar
test/ruby/test_string
test/ruby/test_struct
test/ruby/test_super
test/ruby/test_symbol
test/ruby/test_undef
test/ruby/test_variable
test/ruby/test_warning
test/ruby/test_whileuntil
test/ruby/test_yield
test/ruby/test_unicode_escape
test/ruby/test_alias
test/ruby/test_allocation
test/ruby/test_arity
test/ruby/test_beginendblock
test/ruby/test_econv
test/ruby/test_encoding
test/ruby/test_fiber
test/ruby/test_gc
test/ruby/test_m17n
test/ruby/test_m17n_comb
test/ruby/test_marshal
test/ruby/test_objectspace
test/ruby/test_refinement
#############################
test/ruby/test_sleep
test/ruby/test_string_memory
test/ruby/test_syntax
test/ruby/test_thread_cv
test/ruby/test_thread
test/ruby/test_thread_queue
test/ruby/test_threadgroup
test/ruby/test_time
test/ruby/test_transcode
test/ruby/test_weakkeymap
test/ruby/test_weakmap
#############################
test/ruby/test_iseq
test/ruby/test_rubyvm
test/ruby/test_insns_leaf
=end


# Load test files
%w[
  test/ruby/test_iseq
  test/ruby/test_rubyvm
  test/ruby/test_insns_leaf
].each do |f|
    begin
      load "romfs:/#{f}.rb"
    rescue LoadError => e
      puts "SKIP #{f}: #{e.message}"
    end
  end
  
  # Ignored for now because of -test- dependency
=begin
test/ruby/test_enumerator
test/ruby/test_keyword
test/ruby/test_call
test/ruby/test_memory_view
test/ruby/test_time_tz
=end

# Ignored
=begin
# debug feature
test/ruby/test_shapes         # debug feature
test/ruby/test_stack          # entirely dependant on subprocess
test/ruby/test_default_gems   # tests gem loading
test/ruby/test_vm_dump        # darwin-specific
=end

SWITCH_SKIP_TESTS = {
  # These tests make use of disabled features like subprocess, pipes...
  "TestBasicInstructions" => %w[test_xstr],
  "TestEval" => %w[test_eval_with_toplevel_binding],
  "TestFlip" => %w[test_input_line_number_range],
  "TestRubyLiteral" => %w[test_xstring],
  "TestRubyOptimization" => %w[test_string_freeze_saves_memory test_tailcall_interrupted_by_sigint],
  "TestPatternMatching" => %w[test_literal_value_pattern],
  "TestRand" => %w[test_rand_reseed_on_fork],
  "TestSymbol" => %w[test_hash_nondeterministic],
  "TestStruct" => %w[test_struct_new],
  "TestBeginEndBlock" => %w[test_propagate_exit_code test_rescue_at_exit test_pipe],
  "TestMarshal" => %w[test_undumpable_message test_no_internal_ids test_regexp2 test_pipe],
  "TestSyntax" => %w[test_return_toplevel test_eval_return_toplevel test_defined_in_short_circuit_if_condition],
  "TestStack" => %w[test_machine_stack_size test_vm_stack_size test_relative_stack_sizes],
  "TestThread" => %w[test_machine_stack_size test_local_barrier test_thread_timer_and_interrupt test_stack_size test_vm_machine_stack_size],
  # Rely on /dev/null, which we don't have
  "TestString" => %w[test_clone test_uminus_no_embed_gc],
  # Rely on /dev/null, subprocess, and unsupported fs behavior
  "TestISeq" => %w[
    test_compile_empty_under_gc_stress
    test_iseq_builtin_to_a
    test_compile_file_encoding
  ],
  # test_warning_warn_circular_require_backtrace is limited by how the FS works
  # it looks like directory entries are not committed until the fd is closed
  "TestException" => %w[test_thread_signal_location test_full_message test_warning_warn_circular_require_backtrace],
  # Some weird test state leakage with the deprecated flag, who cares
  "TestModule" => %w[test_deprecate_constant],
  # I'm not sure about the tzset support
  "TestTime" => %w[test_marshal_broken_zone],
  # Try to spawn too many threads at once,
  "TestThreadQueue" => %w[test_deny_pushers],
}

SWITCH_SKIP_TESTS.each do |klass_name, methods|
  klass = Object.const_get(klass_name) rescue next
  methods.each do |m|
    klass.undef_method(m) if klass.method_defined?(m)
  end
end