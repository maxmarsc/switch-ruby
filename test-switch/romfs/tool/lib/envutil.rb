# envutil.rb — Switch port (no subprocess support)
# frozen_string_literal: true
require "timeout"
require_relative "find_executable"
begin
  require 'rbconfig'
rescue LoadError
end
begin
  require "rbconfig/sizeof"
rescue LoadError
end

module EnvUtil
  def rubybin
    "ruby" # no executable on Switch
  end
  module_function :rubybin

  LANG_ENVS = %w"LANG LC_ALL LC_CTYPE"
  DEFAULT_SIGNALS = Signal.list rescue {}
  RUBYLIB = ENV["RUBYLIB"]

  class << self
    attr_accessor :timeout_scale
    attr_reader :original_internal_encoding, :original_external_encoding,
                :original_verbose, :original_warning

    def capture_global_values
      @original_internal_encoding = Encoding.default_internal
      @original_external_encoding = Encoding.default_external
      @original_verbose = $VERBOSE
      @original_warning = nil
    end
  end

  def apply_timeout_scale(t)
    if scale = EnvUtil.timeout_scale
      t * scale
    else
      t
    end
  end
  module_function :apply_timeout_scale

  def timeout(sec, klass = nil, message = nil, &blk)
    return yield(sec) if sec == nil or sec.zero?
    sec = apply_timeout_scale(sec)
    Timeout.timeout(sec, klass, message, &blk)
  end
  module_function :timeout

  def terminate(pid, signal = :TERM, pgroup = nil, reprieve = 1)
    raise NotImplementedError, "process management not available on this platform"
  end
  module_function :terminate

  def invoke_ruby(*, **)
    raise NotImplementedError, "subprocess execution not available on this platform"
  end
  module_function :invoke_ruby

  # --- safe methods kept as-is ---

  def verbose_warning
    class << (stderr = "".dup)
      alias write concat
      def flush; end
    end
    stderr, $stderr = $stderr, stderr
    $VERBOSE = true
    yield stderr
    return $stderr
  ensure
    stderr, $stderr = $stderr, stderr
    $VERBOSE = EnvUtil.original_verbose
  end
  module_function :verbose_warning

  def default_warning
    $VERBOSE = false
    yield
  ensure
    $VERBOSE = EnvUtil.original_verbose
  end
  module_function :default_warning

  def suppress_warning
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = EnvUtil.original_verbose
  end
  module_function :suppress_warning

  def under_gc_stress(stress = true)
    stress, GC.stress = GC.stress, stress
    yield
  ensure
    GC.stress = stress
  end
  module_function :under_gc_stress

  def under_gc_compact_stress(val = :empty, &block)
    under_gc_stress(&block)
  end
  module_function :under_gc_compact_stress

  def without_gc
    prev_disabled = GC.disable
    yield
  ensure
    GC.enable unless prev_disabled
  end
  module_function :without_gc

  def with_default_external(enc)
    suppress_warning { Encoding.default_external = enc }
    yield
  ensure
    suppress_warning { Encoding.default_external = EnvUtil.original_external_encoding }
  end
  module_function :with_default_external

  def with_default_internal(enc)
    suppress_warning { Encoding.default_internal = enc }
    yield
  ensure
    suppress_warning { Encoding.default_internal = EnvUtil.original_internal_encoding }
  end
  module_function :with_default_internal

  def labeled_module(name, &block)
    Module.new do
      singleton_class.class_eval { define_method(:to_s) {name}; alias inspect to_s; alias name to_s }
      class_eval(&block) if block
    end
  end
  module_function :labeled_module

  def labeled_class(name, superclass = Object, &block)
    Class.new(superclass) do
      singleton_class.class_eval { define_method(:to_s) {name}; alias inspect to_s; alias name to_s }
      class_eval(&block) if block
    end
  end
  module_function :labeled_class

  def self.diagnostic_reports(signame, pid, now) = nil

  def self.failure_description(status, now, message = "", out = "")
    message.to_s
  end

  def self.gc_stress_to_class?
    GC.respond_to?(:add_stress_to_class)
  end
end

EnvUtil.capture_global_values