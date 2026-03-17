# frozen_string_literal: true
require 'mkmf'

if RbConfig::CONFIG['arch'] =~ /aarch64-elf/ # Cross compiling for the switch
  $defs << "-DHAVE_RB_ENC_INTERNED_STR"
  $defs << "-DHAVE_RB_HASH_NEW_CAPA"
  $defs << "-DHAVE_RB_HASH_BULK_INSERT"
  $defs << "-DHAVE_RB_CATEGORY_WARN"
  $defs << "-DHAVE_STRNLEN"
else
  have_func("rb_enc_interned_str", "ruby/encoding.h") # RUBY_VERSION >= 3.0
  have_func("rb_hash_new_capa", "ruby.h") # RUBY_VERSION >= 3.2
  have_func("rb_hash_bulk_insert", "ruby.h") # Missing on TruffleRuby
  have_func("rb_category_warn", "ruby.h") # Missing on TruffleRuby
  have_func("strnlen", "string.h") # Missing on Solaris 10
end

append_cflags("-std=c99")

create_makefile 'json/ext/parser'
