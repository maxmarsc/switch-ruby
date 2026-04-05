# Known Limitations

This document describes the known limitations of the Ruby 3.4.x port to Nintendo Switch (Horizon OS / libnx).

## Process Management

- `fork`, `exec`, `spawn`, `system`, and `popen` are not available. Horizon OS does not support process creation from userland.
- `Process.kill` and signal delivery (`trap`, `Signal.trap`) do not function. Horizon OS has no POSIX signal mechanism.
- `Process.pid` returns `-1`.
- Backtick command execution (`` `echo foo` ``, `%x(...)`) is not supported.

## File Descriptors

- `dup`, `dup2`, and `fcntl(F_DUPFD)` do not work on filesystem file descriptors (romfs, sdmc). They are only functional for socket file descriptors. `IO#dup`, `IO#clone`, and `IO#reopen` on file-backed IO objects will raise `Errno::ENOSYS`.
- A file cannot be opened through multiple file descriptors simultaneously on sdmc (FAT32). Calling `File.read(f.path)` or `File.exist?(f.path)` while `f` is still open will fail with `Errno::EIO`. Close the first handle before opening a second.
- Files written to sdmc are not visible to `stat`/`File.exist?` until the writing file descriptor is closed. This is a FAT32 devoptab limitation.
- `IO::NULL` (`/dev/null`) does not exist. A workaround must be provided by the application if needed.
- `IO.pipe` is not available.

## File System

- File permissions are not tracked. `stat` returns `0777` for all files. `chmod` is accepted but has no effect. `File.executable?`, `File.writable?`, and related predicates always return `true`.
- `File.symlink`, `File.readlink`, and `File.link` are not available.
- `File.chown`, `File.lchown`, and `File.lchmod` are not available.
- `Dir.entries` and `Dir.each` synthetically inject `.` and `..` entries at the Ruby level. The underlying `readdir` implementation in devkitPro's newlib does not return them.
- Devoptab paths (`romfs:/`, `sdmc:/`) are supported throughout Ruby's path resolution, file loading, and `require`/`load` mechanisms.

## JIT Compilation

- YJIT is disabled. It requires a Rust runtime and OS-level memory mapping (`mmap` with `PROT_EXEC`) not available on Horizon OS.
- RJIT is disabled. It requires `fork` and `exec` to invoke a C compiler at runtime.
- All Ruby code is interpreted.

## Threading

- POSIX threads are supported through libnx's pthread implementation.
- M:N thread scheduling is disabled (`USE_MN_THREADS=0`). Horizon OS lacks `epoll`, `kqueue`, and `io_uring`.
- `pthread_getattr_np` is not available. Thread stack detection uses libnx's `threadGetSelf()` API instead.
- Native threads must be joined via `pthread_join` to reclaim their stack memory. libnx maps thread stacks with `svcMapMemory`, which marks the source heap pages as inaccessible. If a thread is not joined, subsequent `malloc`/`memalign` calls may return addresses in these inaccessible regions, causing crashes. Ruby's GC handles this for most threads, but applications creating threads that outlive `ruby_cleanup` must join them explicitly.

## Fiber Stacks

- Fiber stack guard pages are disabled. `svcSetMemoryPermission` cannot reliably operate on sub-regions of heap memory allocated with `memalign`. Stack overflows in fibers will silently corrupt memory rather than raising a signal.
- Fiber stacks are allocated with `memalign` and zero-initialized manually. The `mmap`/`munmap` path used on other platforms is not available.

## Networking

- BSD sockets are available through libnx's socket implementation.
- `shutdown(2)` may not be available depending on the libnx version.
- Close-on-exec (`FD_CLOEXEC`) is a no-op. `exec` does not exist on Horizon OS, so the flag has no meaning.

## Memory

- `mmap`, `mprotect`, `munmap`, and related virtual memory operations are not available from userland in the standard POSIX sense. Memory allocation uses `malloc`/`memalign` exclusively.
- `getrlimit` and `setrlimit` are not available. The main thread stack size is determined by the homebrew loader environment.
- GC compaction is disabled. It requires `mprotect`-based read barriers which are not available.

## Users and Groups

- User and group functions (`getpwuid`, `getgrnam`, `getlogin`, etc.) are not available. The `etc` extension compiles but returns empty results for user/group queries.

## Ractor

- Ractor is functional for basic message passing and parallel execution.
- Ractor tests that depend on signals (`Process.kill`, `trap`) or subprocess execution will not work.
- Thread stack cleanup for Ractor worker threads depends on GC collection. Applications should call `GC.start` after Ractor-heavy workloads to ensure timely cleanup of native thread resources.

## Randomness

- Cryptographically secure random numbers are provided by `svcGenerateRandomBytes` (via libnx's `randomGet`). No initialization is required.
- `getrandom`, `getentropy`, and `/dev/urandom` are not available.

## Encoding

- All encoding and transcoding tables are compiled statically into the binary.
- Filesystem encoding defaults to ASCII-8BIT.

## Extensions

- Dynamic extension loading (`dlopen`, `require` of `.so` files) is not supported. All extensions must be statically linked at build time.
- Extensions requiring external libraries (OpenSSL, libffi, libyaml) are not included by default and require those libraries to be cross-compiled for the Switch.

## Embedding

- `rb_free_at_exit` must be set to `true` before `ruby_cleanup()` to ensure all native thread resources are properly released. Without this, hbmenu will reuse the address space on the next NRO launch with stale memory mappings.