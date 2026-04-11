# switch-ruby

This repository is a Homebrew Switch port of MRI Ruby, the reference implementation of Ruby, using devkitpro. It
is currently based on Ruby 3.4.8. If you wish to find the official README please scroll down.

**BEWARE: This port is still in an experimental stage: all tests are passing but use with care**

## The scope
This repository is meant to be used as a static library for Nintendo Switch homebrew development. It is not meant to be used as a standalone Ruby interpreter. 

As imposed by Horizon OS available features, this port of Ruby comes with limitations which are listed in the [`LIMITATIONS.md`](LIMITATIONS.md) file. Most of these limitations are inherent to the platform and will not be fixed.

Supported features include:
- Multithreading
- Fibers
- Ractors (experimental)
- Filesystem access (romfs and sdmc)
- Sockets
- Most of the standard library (with some limitations)

The current builtins native extensions are included:
 - `rbconfig/sizeof`
 - `strscan`
 - `continuation`
 - `date`
 - `stringio`
 - `objspace`
 - `etc`
 - `json`
 - `json/parser`
 - `json/generator`
 - `ripper`
 - `socket`
 - `io/nonblock`
 - `io/wait`
 - `pathname`
 - `monitor`
 - `digest`
 - `zlib`
 - `fcntl`

The non-native (pure Ruby) builtin extensions are provided and should work out of the box, with regards to the port limitations.

## How to build
Because the build steps required for this port are a bit complex, it is recommended to use the provided CMake configuration.

### Requirements
- A devkitPro toolchain with the latest libnx and newlib versions. The `DEVKITPRO` environment variable must be set.
- CMake 3.28 or later.

### System installation with cmake
These instructions will install the library and headers as a portlib library in `$DEVKITPRO/portlibs/switch`.
```bash
git clone https://github.com/maxmarsc/switch-ruby.git
cd switch-ruby
cmake -B build
cmake --build build
cmake --install build
```

Alternatively you can use the library without installing as part of your build tree
by using CMake's `FetchContent` / `add_subdirectory` features (see examples).


## How to use
This repository provides an example of a C++ application using the library in the `examples` directory. 
You can use it as a reference for your own application.

The same example can be built in three different fashions:
- Using CMake's `FetchContent` (see [examples/cmake_fetch_content](examples/cmake_fetch_content/README.md))
- Using installed library and CMake's `find_package` (see [examples/cmake_find_package](examples/cmake_find_package/README.md))
- Using installed library, make and `pkg-config` (see [examples/make](examples/make/README.md))

### The ruby app
[`main.rb`](examples/common/romfs/ruby/app/main.rb) is a simple Ruby application 
tries to include most supported features of the port.

### The C++ app
[`main.cpp`](examples/common/main.cpp) is a simple C++ application that initializes the Ruby VM, 
runs the Ruby app and then cleans up the VM.


## Testing
This implementation was tested with the full MRI Ruby test suite. You can find the tests performed in these folder, from most basic to most complex:
- [bootstraptest-switch](./bootstraptest-switch/)
- [basictest-switch](./basictest-switch/)
- [test-switch](./test-switch/)


--------------------------------------------------------------------------------
**BELOW THIS LINE IS THE OFFICIAL README OF MRI RUBY.**
--------------------------------------------------------------------------------


## Features of Ruby

* Simple Syntax
* **Normal** Object-oriented Features (e.g. class, method calls)
* **Advanced** Object-oriented Features (e.g. mix-in, singleton-method)
* Operator Overloading
* Exception Handling
* Iterators and Closures
* Garbage Collection
* Dynamic Loading of Object Files (on some architectures)
* Highly Portable (works on many Unix-like/POSIX compatible platforms as
  well as Windows, macOS, etc.) cf.
    https://docs.ruby-lang.org/en/master/maintainers_md.html#label-Platform+Maintainers

## How to get Ruby

For a complete list of ways to install Ruby, including using third-party tools
like rvm, see:

https://www.ruby-lang.org/en/downloads/

You can download release packages and the snapshot of the repository. If you want to
download whole versions of Ruby, please visit https://www.ruby-lang.org/en/downloads/releases/.

### Download with Git

The mirror of the Ruby source tree can be checked out with the following command:

    $ git clone https://github.com/ruby/ruby.git

There are some other branches under development. Try the following command
to see the list of branches:

    $ git ls-remote https://github.com/ruby/ruby.git

You may also want to use https://git.ruby-lang.org/ruby.git (actual master of Ruby source)
if you are a committer.

## How to build

See [Building Ruby](https://docs.ruby-lang.org/en/master/contributing/building_ruby_md.html)

## Ruby home page

https://www.ruby-lang.org/

## Documentation

- [English](https://docs.ruby-lang.org/en/master/index.html)
- [Japanese](https://docs.ruby-lang.org/ja/master/index.html)

## Mailing list

There is a mailing list to discuss Ruby. To subscribe to this list, please
send the following phrase:

    join

in the mail subject (not body) to the address [ruby-talk-request@ml.ruby-lang.org].

[ruby-talk-request@ml.ruby-lang.org]: mailto:ruby-talk-request@ml.ruby-lang.org?subject=join

## Copying

See the file [COPYING](rdoc-ref:COPYING).

## Feedback

Questions about the Ruby language can be asked on the [Ruby-Talk](https://www.ruby-lang.org/en/community/mailing-lists) mailing list
or on websites like https://stackoverflow.com.

Bugs should be reported at https://bugs.ruby-lang.org. Read ["Reporting Issues"](https://docs.ruby-lang.org/en/master/contributing/reporting_issues_md.html) for more information.

## Contributing

See ["Contributing to Ruby"](https://docs.ruby-lang.org/en/master/contributing_md.html), which includes setup and build instructions.

## The Author

Ruby was originally designed and developed by Yukihiro Matsumoto (Matz) in 1995.

<matz@ruby-lang.org>
