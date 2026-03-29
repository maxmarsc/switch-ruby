#!/bin/bash
# configure_switch.sh — Configure MRI Ruby 3.4.x for Nintendo Switch (Horizon OS)
# Run from the Ruby source root: ./configure_switch.sh
#
# Prerequisites:
#   - devkitPro + devkitA64 + libnx installed
#   - DEVKITPRO env var set (e.g., /opt/devkitpro)
#   - A host Ruby >= 2.2 in PATH (needed by Ruby's build system as "baseruby")
#   - autoconf 2.67+ (run ./autogen.sh first if configure doesn't exist)
#
# Ruby version: 3.4.x (has YJIT/RJIT, coroutine selection, modular GC, M:N threads)

set -euo pipefail

# =============================================================================
# Options
# =============================================================================
if [[ "${1:-}" == "--debug" ]]; then
    OPT_FLAGS="-g -O0"
else
    OPT_FLAGS="-O2 -DNDEBUG"
fi


# =============================================================================
# 1) Toolchain paths — derived from DevkitA64Libnx.cmake
# =============================================================================

if [ -z "${DEVKITPRO:-}" ]; then
    echo "ERROR: DEVKITPRO environment variable not set."
    echo "       export DEVKITPRO=/opt/devkitpro"
    exit 1
fi

DEVKITA64="${DEVKITPRO}/devkitA64"
LIBNX="${DEVKITPRO}/libnx"
PORTLIBS="${DEVKITPRO}/portlibs/switch"

TOOL_PREFIX="${DEVKITA64}/bin/aarch64-none-elf"

# Where the built Ruby will be installed
PREFIX="${PREFIX:-${PWD}/build-switch/install}"

# =============================================================================
# 1.B) Miniruby patching - make sure it knows how to find a miniruby native build
# =============================================================================
if [ -z "${NATIVE_BUILD:-}" ]; then
    echo "ERROR: NATIVE_BUILD environment variable not set."
    echo "       export NATIVE_BUILD=/path/to/native/build"
    exit 1
fi

NATIVE_MINIRUBY="${PWD}/miniruby -r${PWD}/../switch_cross_compiling_setup.rb -I${PWD} -I${NATIVE_BUILD} -I${PWD}/../lib -I${PWD}/.ext/common"

# =============================================================================
# 2) Compiler/linker flags — matching CMake toolchain
# =============================================================================

ARCH_FLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE"

SWITCH_CFLAGS="${ARCH_FLAGS} ${OPT_FLAGS} -ffunction-sections -fdata-sections"

# -D__SWITCH__ -DSWITCH: platform detection macros (from CMake toolchain)
# -DUSE_MN_THREADS=0:    Ruby 3.4 M:N threading scheduler requires epoll/kqueue/io_uring,
#                        none of which exist on Horizon OS. Must be disabled at compile time
#                        since configure.ac has no flag for it (only auto-disables on s390x).
SWITCH_CPPFLAGS="-D__SWITCH__ -DSWITCH -DUSE_MN_THREADS=0 -I${LIBNX}/include -I${PORTLIBS}/include"

# Library search paths
SWITCH_LDFLAGS="-L${LIBNX}/lib -L${PORTLIBS}/lib -fPIE -Wl,--gc-sections"

# =============================================================================
# 3) Pre-seeded autoconf cache variables for cross-compilation
# =============================================================================
# When cross-compiling, autoconf can't run test programs on the target.
# AC_CHECK_FUNCS does a link test against the cross-compiler's libc (newlib).
# The link may succeed even for stub functions that don't work at runtime on
# Horizon OS. We override the cache variables to force correct answers.
#
# Syntax:  ac_cv_func_<n>=yes|no
#          ac_cv_header_<name_with_underscores>=yes|no
#          ac_cv_lib_<lib>_<func>=yes|no
# =============================================================================

CACHE_OVERRIDES=(
    # ─── Signals: Horizon OS has NO POSIX signal delivery ───
    ac_cv_func_sigaction=no
    ac_cv_func_sigaltstack=no
    ac_cv_func_sigprocmask=no
    ac_cv_func_sigsetmask=no
    ac_cv_func_kill=no
    ac_cv_func_killpg=no
    ac_cv_func_pthread_sigmask=no

    # ─── Process management: no fork/exec/spawn on Horizon ───
    ac_cv_func_fork=no
    ac_cv_func_vfork=no
    ac_cv_func_fork_works=no        # AC_FUNC_FORK result
    ac_cv_func_vfork_works=no
    ac_cv_func_spawnv=no
    ac_cv_func_daemon=no
    ac_cv_func_chroot=no
    ac_cv_func_execl=no             # new in 3.4
    ac_cv_func_execle=no            # new in 3.4
    ac_cv_func_execv=no
    ac_cv_func_execve=no
    ac_cv_func_system=no
    ac_cv_func_popen=no
    ac_cv_func_pclose=no
    ac_cv_func_waitpid=no
    ac_cv_func_wait4=no

    # ─── Dynamic loading: Horizon is static-only ───
    ac_cv_func_dlopen=no
    ac_cv_func_dladdr=no
    ac_cv_func_dl_iterate_phdr=no
    ac_cv_lib_dl_dlopen=no          # don't try -ldl

    # ─── POSIX timers: force UBF_TIMER_PTHREAD path ───
    ac_cv_lib_rt_timer_create=no
    ac_cv_lib_rt_timer_settime=no
    ac_cv_lib_rt_clock_gettime=no

    # ─── Memory mapping: Horizon has no mmap ───
    ac_cv_func_mmap=no              # new explicit check in 3.4
    ac_cv_func_mremap=no            # new in 3.4
    ac_cv_func_posix_madvise=no     # new in 3.4
    ac_cv_func_posix_fadvise=no     # new in 3.4
    ac_cv_func_posix_memalign=no    # new in 3.4
    # ─── libnx provide memalign ───
    ac_cv_func_memalign=yes

    # ─── Pipe: critical for MRI's self-pipe trick (thread interrupts) ───
    # newlib may or may not provide working pipe().
    # START CONSERVATIVE: assume no. Test and flip if newlib has it.
    # If no: you'll need to patch thread_pthread.c → libnx Events.
    ac_cv_func_pipe=no              # new explicit check in 3.4
    ac_cv_func_pipe2=no

    # ─── I/O multiplexing ───
    ac_cv_func_poll=no
    ac_cv_func_ppoll=no             # new in 3.4
    ac_cv_func_select_large_fdset=no
    ac_cv_func_eventfd=no

    # ─── Coroutine/context: we force --with-coroutine=arm64 instead ───
    ac_cv_func_getcontext=no
    ac_cv_func_setcontext=no
    ac_cv_func_swapcontext=no       # new in 3.4 (coroutine probe)
    ac_cv_func_makecontext=no       # new in 3.4 (coroutine probe)

    # ─── Process/user/group: absent on Horizon ───
    ac_cv_func_setuid=no
    ac_cv_func_seteuid=no
    ac_cv_func_setreuid=no
    ac_cv_func_setresuid=no
    ac_cv_func_setgid=no
    ac_cv_func_setegid=no
    ac_cv_func_setregid=no
    ac_cv_func_setresgid=no
    ac_cv_func_setpgid=no
    ac_cv_func_getpgid=no
    ac_cv_func_setpgrp=no
    ac_cv_func_getpgrp=no
    ac_cv_func_setsid=no
    ac_cv_func_getsid=no
    ac_cv_func_getppid=no
    ac_cv_func_initgroups=no
    ac_cv_func_getgroups=no
    ac_cv_func_setgroups=no
    ac_cv_func_getlogin=no
    ac_cv_func_getlogin_r=no
    ac_cv_func_endgrent=no
    ac_cv_func_getpwnam=no
    ac_cv_func_getpwnam_r=no
    ac_cv_func_getpwuid=no
    ac_cv_func_getpwuid_r=no
    ac_cv_func_getgrnam=no
    ac_cv_func_getgrnam_r=no
    ac_cv_func_getresgid=no
    ac_cv_func_getresuid=no
    ac_cv_func_issetugid=no
    ac_cv_func_getuid=no
    ac_cv_func_geteuid=no
    ac_cv_func_getgid=no
    ac_cv_func_getegid=no
    ac_cv_func_getuidx=no
    ac_cv_func_getgidx=no

    # ─── File system: features Horizon/newlib doesn't have ───
    ac_cv_func_chown=no
    ac_cv_func_fchown=no
    ac_cv_func_lchown=no
    ac_cv_func_lchmod=no
    ac_cv_func_symlink=no
    ac_cv_func_readlink=no
    ac_cv_func_link=no
    ac_cv_func_mkfifo=no
    ac_cv_func_mknod=no
    ac_cv_func_flock=no
    ac_cv_func_lockf=no
    ac_cv_func_utimensat=no
    ac_cv_func_utimes=no
    ac_cv_func_lutimes=no
    ac_cv_func_sendfile=no
    ac_cv_func_copy_file_range=no
    ac_cv_func_fcopyfile=no
    ac_cv_func_fstatat=no           # set =yes if newlib provides it
    ac_cv_func_openat=no            # new in 3.4; set =yes if available
    ac_cv_func_fdopendir=no
    ac_cv_func_fchdir=no

    # ─── I/O: conservative defaults ───
    ac_cv_func_pread=no             # new in 3.4
    ac_cv_func_pwrite=no            # new in 3.4
    ac_cv_func_writev=no
    ac_cv_func_shutdown=no          # socket shutdown — socket ext handles this

    # ─── Resource limits / scheduling: absent ───
    ac_cv_func_getrlimit=no
    ac_cv_func_setrlimit=no
    ac_cv_func_getpriority=no
    ac_cv_func_setpriority=no
    ac_cv_func_sched_getaffinity=no # new in 3.4
    ac_cv_func_sysconf=no
    ac_cv_func_times=no

    # ─── Randomness ───
    # libnx has csrng service. If you wrap it as getrandom()/getentropy(), set =yes.
    ac_cv_func_getrandom=no         # new in 3.4
    ac_cv_func_getentropy=no        # new in 3.4
    ac_cv_func_arc4random_buf=no

    # ─── Misc: absent or not useful ───
    ac_cv_func_dup3=no
    ac_cv_func_crypt_r=no
    ac_cv_func_ioctl=yes             # set =yes if libnx provides ioctl for sockets
    ac_cv_func_syscall=no
    ac_cv_func_statx=no
    ac_cv_func_backtrace=no
    ac_cv_func_malloc_usable_size=no
    ac_cv_func_malloc_size=no
    ac_cv_func_malloc_trim=no

    # ─── Headers: NOT available on Horizon/newlib ───
    ac_cv_header_sys_eventfd_h=no
    ac_cv_header_sys_epoll_h=no     # new in 3.4 — no epoll
    ac_cv_header_sys_event_h=no     # new in 3.4 — no kqueue
    ac_cv_header_sys_resource_h=no
    ac_cv_header_sys_select_h=no    # newlib: select() via sys/time.h
    ac_cv_header_sys_sendfile_h=no
    ac_cv_header_sys_random_h=no    # new in 3.4
    ac_cv_header_sys_prctl_h=no
    ac_cv_header_sys_uio_h=no
    ac_cv_header_sys_times_h=no
    ac_cv_header_ucontext_h=no      # new explicit check in 3.4
    ac_cv_header_grp_h=no
    ac_cv_header_pwd_h=no
    ac_cv_header_langinfo_h=no
    ac_cv_header_syscall_h=no
    ac_cv_header_sys_syscall_h=no

    # ─── Headers: newlib DOES have these ───
    ac_cv_header_fcntl_h=yes
    ac_cv_header_float_h=yes
    ac_cv_header_limits_h=yes
    ac_cv_header_locale_h=yes
    ac_cv_header_malloc_h=yes
    ac_cv_header_stdio_h=yes
    ac_cv_header_sys_file_h=yes
    ac_cv_header_sys_param_h=yes
    ac_cv_header_sys_time_h=yes

    # ─── Socket headers: libnx has BSD sockets ───
    ac_cv_header_sys_socket_h=yes
    ac_cv_header_sys_ioctl_h=yes
    ac_cv_lib_socket_shutdown=no    # not a separate lib

    # ─── Functions newlib likely provides ───
    # If any cause "undefined reference" at link time, flip to =no.
    ac_cv_func_chmod=yes
    ac_cv_func_fchmod=yes
    ac_cv_func_getcwd=yes
    ac_cv_func_lstat=yes
    ac_cv_func_realpath=yes
    ac_cv_func_mktime=yes
    ac_cv_func_gmtime_r=yes
    ac_cv_func_gettimeofday=yes
    ac_cv_func_clock_gettime=yes
    ac_cv_func_snprintf=yes
    ac_cv_func_setenv=yes
    ac_cv_func_unsetenv=yes
    ac_cv_func_tzset=yes
    ac_cv_func_umask=yes
    ac_cv_func_ftruncate=yes
    ac_cv_func_truncate=yes
    ac_cv_func_fcntl=yes
    ac_cv_func_fmod=yes
    ac_cv_func_log2=yes
    ac_cv_func_round=yes
    ac_cv_func_cosh=yes
    ac_cv_func_sinh=yes
    ac_cv_func_tanh=yes
    ac_cv_func_llabs=yes
    ac_cv_func_dirfd=no
    ac_cv_func_seekdir=yes
    ac_cv_func_telldir=yes
    ac_cv_func_fsync=yes
    ac_cv_func_fdatasync=no
    ac_cv_func_timegm=no
    ac_cv_func_isfinite=yes
    ac_cv_func_mblen=yes
    ac_cv_func_mkstemp=yes
    ac_cv_func_memrchr=yes
    ac_cv_func_memmem=yes
    ac_cv_func__longjmp=yes
    ac_cv_func_qsort_r=no          # newlib doesn't have GNU qsort_r
    ac_cv_func_qsort_s=no
    ac_cv_func_eaccess=no
    ac_cv_func_explicit_memset=no
    ac_cv_func_memset_s=no

    # ─── pthreads: libnx provides these ───
    ac_cv_func_pthread_create=yes
    ac_cv_lib_pthread_pthread_create=no  # in libc, not -lpthread
    rb_cv_scalar_pthread_t=yes
    ac_cv_func_sched_yield=yes
    ac_cv_func_pthread_attr_setinheritsched=no
    ac_cv_func_pthread_attr_getstack=yes
    ac_cv_func_pthread_attr_getguardsize=no
    ac_cv_func_pthread_condattr_setclock=no
    ac_cv_func_pthread_setname_np=no
    ac_cv_func_pthread_set_name_np=no
    ac_cv_func_pthread_getattr_np=no

    # ─── Cross-compile: can't run test programs ───
    rb_cv_fork_with_pthread=no
    rb_cv_bsd_signal=no
    rb_cv_stack_grow_direction=-1   # AArch64 stacks grow down

    # ─── Make sure ruby doesn't try to use the missing SHORT2NUM macro for dev_t ───
    rb_cv_dev_t_convertible=INT
)

# =============================================================================
# 4) Run configure
# =============================================================================

echo "=== Configuring MRI Ruby 3.4.x for Nintendo Switch (aarch64-none-elf) ==="
echo "    DEVKITPRO = ${DEVKITPRO}"
echo "    PREFIX     = ${PREFIX}"
echo ""

cat > ../ext/Setup.switch <<'EOF'
option nodynamic
rbconfig/sizeof
strscan
continuation
date
stringio
objspace
etc
json
json/parser
json/generator
ripper
socket
io/nonblock
io/wait
EOF

../configure \
    --host=aarch64-none-elf \
    --prefix="${PREFIX}" \
    MINIRUBY="${NATIVE_MINIRUBY}" \
    \
    `# ── Toolchain ──` \
    CC="${TOOL_PREFIX}-gcc" \
    CXX="${TOOL_PREFIX}-g++" \
    AR="${TOOL_PREFIX}-gcc-ar" \
    RANLIB="${TOOL_PREFIX}-gcc-ranlib" \
    NM="${TOOL_PREFIX}-gcc-nm" \
    STRIP="${TOOL_PREFIX}-strip" \
    AS="${TOOL_PREFIX}-as" \
    LD="${TOOL_PREFIX}-gcc" \
    \
    `# ── Flags ──` \
    CFLAGS="${SWITCH_CFLAGS}" \
    CPPFLAGS="${SWITCH_CPPFLAGS}" \
    LDFLAGS="${SWITCH_LDFLAGS}" \
    XLDFLAGS="-specs=${LIBNX}/switch.specs" \
    LIBS="-lnx" \
    setup=Setup.switch \
    \
    `# ── Ruby build options ──` \
    --disable-shared \
    --enable-static \
    --disable-dln \
    --disable-install-doc \
    --disable-rubygems \
    --with-static-linked-ext \
    \
    `# ── Force standard setjmp to fix ARM64 GC ──` \
    --with-setjmp-type=setjmp \
    \
    `# ── JIT: YJIT needs Rust runtime, RJIT needs fork+exec for CC ──` \
    --disable-yjit \
    --disable-rjit \
    \
    `# ── Coroutine: force ARM64 native assembly for Fibers ──` \
    `# Without this, aarch64-none-elf won't match any case in configure.ac,` \
    `# falling through to getcontext probe (fails) → pthread coroutines` \
    `# (one real pthread per Fiber = terrible perf & resource usage).` \
    --with-coroutine=arm64 \
    \
    `# ── Extensions to include (comma-separated) ──` \
    `# --with-ext=json,stringio,pathname,digest,socket,zlib` \
    --with-ext='rbconfig/sizeof,strscan,continuation,date,stringio,objspace,etc,json,json/parser,json/generator,ripper,socket,io/nonblock,io/wait' \
    \
    `# ── Extensions to exclude (comma-separated) ──` \
    `# --with-out-ext='-test-,gdbm,dbm,readline,pty,syslog,fiddle,nkf,openssl,psych,json,stringio,pathname,digest,socket,zlib'` \
    \
    `# ── Pre-seeded cache variables (section 3) ──` \
    "${CACHE_OVERRIDES[@]}"

# =============================================================================
# 5) Post-configure fixups for cross-compilation
# =============================================================================

# Ruby's build system disables builtin .rb precompilation during cross-builds
# because it assumes MINIRUBY can't run on the host. We have a native MINIRUBY,
# so we force it back on. Without this, symbol.rb, kernel.rb, io.rb, etc.
# are not compiled into the binary, and core methods like Symbol#to_s are missing.
sed -i 's/^BUILTIN_BINARY = no/BUILTIN_BINARY = yes/' Makefile
# Replace the cross-compiled miniruby target with a symlink to native.
sed -i "/^miniruby\\\$(EXEEXT):/,/^[^\t]/{
    /^miniruby/c\\miniruby: ; ln -sf ${NATIVE_BUILD}/miniruby miniruby
    /^\t/d
}" Makefile

echo ""
echo "=== Configure complete ==="
echo ""
