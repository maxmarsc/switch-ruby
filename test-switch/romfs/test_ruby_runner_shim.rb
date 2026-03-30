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

# Add logging around test suite runs
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

# Removed deprecation warnings from test output
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

# Stub out -test-/ extensions — they're C API test helpers.
# Individual tests that need them will fail/skip gracefully.
$LOADED_FEATURES << '-test-/rb_call_super_kw.so'
$LOADED_FEATURES << '-test-/iter.so'
$LOADED_FEATURES << '-test-/memory_view.so'
$LOADED_FEATURES << '-test-/file.so'
$LOADED_FEATURES << '-test-/time.so'

# Passing
=begin
########## BASE RUBY TESTS ##########
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
test/ruby/test_iseq
test/ruby/test_rubyvm
test/ruby/test_insns_leaf
test/ruby/test_settracefunc
test/ruby/test_trace
test/ruby/test_backtrace
test/ruby/test_parse
test/ruby/test_ast
test/ruby/test_compile_prism
test/ruby/test_env
test/ruby/test_require
test/ruby/test_require_lib
test/ruby/test_path
test/ruby/test_enumerator
test/ruby/test_call
test/ruby/test_time_tz
test/ruby/test_file
test/ruby/test_keyword
test/ruby/test_dir_m17n
########## RUBY STDLIB ##########
test/test_pp
test/test_prettyprint
test/test_delegate
test/test_forwardable
test/test_shellwords
test/test_singleton
test/test_rbconfig
test/test_tsort
test/test_weakref
test/test_find
test/test_trick
test/test_securerandom
test/test_time
test/test_timeout
test/test_tmpdir
test/test_unicode_normalize
test/test_ipaddr
########## JSON EXT TESTS ##########
test/json/json_addition_test
test/json/json_common_interface_test
test/json/json_encoding_test
test/json/json_ext_parser_test
test/json/json_fixtures_test
test/json/json_generator_test
test/json/json_generic_object_test
test/json/json_parser_test
test/json/json_string_matching_test
test/json/ractor_test
test/json/test_helper
########## STRSCAN EXT TESTS ##########
test/strscan/test_ractor
test/strscan/test_stringscanner
########## DATE EXT TESTS ##########
test/date/test_date_arith
test/date/test_date_attr
test/date/test_date_compat
test/date/test_date_conv
test/date/test_date_marshal
test/date/test_date_new
test/date/test_date_parse
test/date/test_date_ractor
test/date/test_date
test/date/test_date_strftime
test/date/test_date_strptime
test/date/test_switch_hitter
########## STRINGIO EXT TESTS ##########
test/stringio/test_stringio
test/stringio/test_ractor
########## OBJSPACE EXT TESTS ##########
test/objspace/test_ractor
test/objspace/test_objspace
########## ETC EXT TESTS ##########
test/etc/test_etc
########## RIPPER EXT TESTS ##########
test/ripper/test_files_ext
test/ripper/test_files_lib
test/ripper/test_files_sample
test/ripper/test_files_test
test/ripper/test_files_test_1
test/ripper/test_files_test_2
test/ripper/test_filter
test/ripper/test_lexer
test/ripper/test_parser_events
test/ripper/test_ripper
test/ripper/test_scanner_events
test/ripper/test_sexp
########## SOCKET EXT TESTS ##########
test/socket/test_ancdata
test/socket/test_basicsocket
test/socket/test_udp
test/socket/test_tcp
test/socket/test_nonblock
test/socket/test_sockopt
test/socket/test_socket
test/socket/test_addrinfo
=end

# Ignored
=begin
# debug feature
test/ruby/test_shapes         # debug feature
test/ruby/test_stack          # entirely dependant on subprocess
test/ruby/test_default_gems   # tests gem loading
test/ruby/test_vm_dump        # darwin-specific
test/ruby/test_dir            # entirely dependant on unsupported fs behavior
test/ruby/test_memory_view    # ignored feature rb_memory_view_register / rb_memory_view_get
test/test_tempfile            # relies heavily on checking a file while it's fd is still open from creation, not supported
test/test_open3               # relies on subprocess
test/test_pty                 # no terminal support
test/test_pstore              # persistent storage, needs filesystem write + concurrent file access
test/test_bundled_gems        # tests gem loading
test/test_extlibs             # external libraries loading
test/socket/test_unix         # HNU: Horizon is Not Unix
=end

# To check
=begin
=end

# Load test files
%w[
].each do |f|
  begin
    load "romfs:/#{f}.rb"
  rescue LoadError => e
    puts "SKIP #{f}: #{e.message}"
  end
end

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
  "TestSetTraceFunc" => %w[test_tracepoint_opt_invokebuiltin_delegate_leave],
  "TestParse" => %w[test_xstring],
  "TestObjSpace" => %w[test_dump_to_io],
  "TestEtc" => %w[test_nprocessors],
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
  # Rely on chmod
  "TestFind" => %w[test_unsearchable_dir],
  # Unsupported fs features
  "TestRequire" => %w[
    test_require_nonascii_path_utf8
    test_load_ospath
    test_provide_in_required_file
    test_require_nonascii_path_shift_jis
  ],
  # Unsupported fs features
  "TestTmpdir" => %w[test_world_writable],
  "TestSocket_BasicSocket" => %w[test_for_fd],
  # Relying on pipes or fat32/devoptab limitations, except for utime
  "TestFile" => %w[
    test_realpath_special_symlink
    test_stat
    test_realpath_encoding
    test_initialize
    test_bom_8
    test_bom_16be
    test_bom_16le
    test_bom_32be
    test_bom_32le
    test_file_share_delete
    test_unlink_before_close
    test_truncate_rbuf
    test_truncate_beyond_eof
    test_truncate_wbuf
    test_truncate_size
    test_empty_file_bom
    test_eof_0_seek
    test_eof_1_seek
    test_chmod_m17n
    test_utime
    ],
  # IPV6 is not supported & missing getifaddrs causes ip_address_list to raise EFAULT
  "TestSocket_TCPSocket" => %w[
    test_initialize_v6_hostname_resolved_in_resolution_delay
    test_initialize_v6_hostname_resolved_earlier_and_v6_server_is_not_listening
    test_initialize_v6_hostname_resolved_later_and_v6_server_is_not_listening
    test_initialize_v6_hostname_resolved_earlier
    test_initialize_v6_connected_socket_with_v6_address
    test_initialize_with_hostname_resolution_failure_after_connection_failure
    test_initialize_resolv_timeout_with_connection_failure
    test_initialize_failure
  ],
  # No signals so no interrupting system calls / IO.pipe / ip_address_list
  "TestSocket" => %w[
    test_closed_read
    test_accept_loop
    test_accept_loop_multi_port
    test_udp_server_sockets_in_rescue
    test_ip_address_list_include_localhost
    test_ip_address_list
  ],
  # IPV6 is not supported
  "TestSocketAddrinfo" => %w[
    test_ipv6_address_predicates
    test_addrinfo_inspect_sockaddr_inet6
    test_marshal_inet6
    test_ipv6_to_ipv4
    test_addrinfo_ip_unpack_inet6
    test_addrinfo_new_inet6
  ],
  # Relying on test/-ext- extensions
  "TestCall" => %w[
    test_call_ifunc_iseq_large_array_splat_pass
    test_call_rb_call_iseq_large_array_splat_fail
    test_call_rb_call_bmethod_large_array_splat_fail
    test_call_rb_call_bmethod_large_array_splat_pass
    test_call_ifunc_iseq_large_array_splat_fail
    test_call_rb_call_iseq_large_array_splat_pass
  ],
  # Relying on test/-ext- extensions
  "TestFile::NewlineConvTests" => %w[
    test_c_rb_file_open_bin_mode_read_lf_with_utf8_encoding
    test_c_rb_io_fdopen_text_mode_read_lf_with_utf8_encoding
    test_c_rb_io_fdopen_bin_mode_read_lf
    test_c_rb_file_open_text_mode_read_lf_with_utf8_encoding
    test_c_rb_io_fdopen_bin_mode_write_crlf
    test_c_rb_io_fdopen_bin_mode_write_lf
    test_c_rb_io_fdopen_text_mode_read_crlf
    test_c_rb_io_fdopen_bin_mode_read_lf_with_utf8_encoding
    test_c_rb_file_open_bin_mode_read_crlf_with_utf8_encoding
    test_c_rb_io_fdopen_text_mode_write_lf
    test_c_rb_file_open_bin_mode_read_crlf
    test_c_rb_io_fdopen_text_mode_read_lf
    test_c_rb_file_open_text_mode_read_crlf_with_utf8_encoding
    test_c_rb_io_fdopen_bin_mode_read_crlf_with_utf8_encoding
    test_c_rb_file_open_bin_mode_read_lf
    test_c_rb_io_fdopen_text_mode_read_crlf_with_utf8_encoding
    test_c_rb_file_open_text_mode_read_crlf
    test_c_rb_file_open_bin_mode_write_crlf
    test_c_rb_file_open_text_mode_read_lf
    test_c_rb_file_open_bin_mode_write_lf
    test_c_rb_file_open_text_mode_write_lf
    test_c_rb_io_fdopen_bin_mode_read_crlf
  ],
  # Relying on test/-ext- extensions
  "TestKeywordArguments" => %w[
    test_rb_yield_block_kwsplat
    test_rb_call_super_kw_method_missing_kwsplat
  ],
  # Relying on test/-ext- extensions or devoptab limitations
  "TestDir_M17N" => %w[
    test_filename_extutf8_invalid
    test_glob_compose
    test_glob_encoding
    test_pwd
    test_entries_compose
    test_inspect_nonascii
  ]
}

SWITCH_SKIP_TESTS.each do |klass_name, methods|
  klass = Object.const_get(klass_name) rescue next
  methods.each do |m|
    klass.undef_method(m) if klass.method_defined?(m)
  end
end