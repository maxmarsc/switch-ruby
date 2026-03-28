CROSS_COMPILING = true
SWITCH_TARGET = true

# orig_require = method(:require)
# define_method(:require) do |name|
#   result = orig_require.call(name)
#   if name == 'mkmf'
#     specs = "-specs=#{ENV.fetch('DEVKITPRO', '/opt/devkitpro')}/libnx/switch.specs"
#     $LDFLAGS = "#{$LDFLAGS} #{specs}".strip

#     # Remove specs from $LDFLAGS before extension Makefile is written,
#     # so it doesn't leak into EXTLDFLAGS and duplicate with XLDFLAGS.
#     MakeMakefile.module_eval do
#       orig_cm = instance_method(:create_makefile)
#       define_method(:create_makefile) do |*args, **kwargs|
#         saved = $LDFLAGS.dup
#         $LDFLAGS = $LDFLAGS.gsub(/-specs=\S+/, '').strip
#         result = orig_cm.bind(self).call(*args, **kwargs)
#         $LDFLAGS = saved
#         result
#       end
#     end
#   end
#   result
# end

# After mkmf is required, it initializes $LDFLAGS from CONFIG["LDFLAGS"].
# We need -specs= for try_link tests, but NOT in CONFIG["DLDFLAGS"]
# (which gets baked into extension Makefiles and causes duplication).
# specs = "-specs=#{ENV.fetch('DEVKITPRO', '/opt/devkitpro')}/libnx/switch.specs"

# orig_require = method(:require)
# define_method(:require) do |name|
#   result = orig_require.call(name)
#   if name == 'mkmf' && !$LDFLAGS.include?(specs)
#     $LDFLAGS = "#{$LDFLAGS} #{specs}".strip
#   end
#   result
# end