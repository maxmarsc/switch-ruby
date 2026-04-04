cmake_minimum_required(VERSION 3.28)
project(switch-ruby LANGUAGES C ASM)

include(ExternalProject)
include(GNUInstallDirs)
include(ProcessorCount)

# ##############################################################################
# Options
# ##############################################################################
option(SWITCH_RUBY_DEBUG "Build with debug flags" OFF)


# ##############################################################################
# Setup
# ##############################################################################
if(NOT DEFINED ENV{DEVKITPRO})
    message(FATAL_ERROR "DEVKITPRO environment variable not set")
endif()

set(DEVKITPRO $ENV{DEVKITPRO})

# Default install prefix to devkitpro portlibs
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${DEVKITPRO}/portlibs/switch" CACHE PATH "" FORCE)
endif()

set(RUBY_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(RUBY_CROSS_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/ruby-cross)
set(RUBY_NATIVE_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/ruby-native)

ProcessorCount(NCPUS)


# ##############################################################################
# Native RUBY build - required for cross-compilation and install phase
# ##############################################################################
ExternalProject_Add(switch_ruby_native
    SOURCE_DIR ${RUBY_SOURCE_DIR}
    BINARY_DIR ${RUBY_NATIVE_BUILD_DIR}
    CONFIGURE_COMMAND ${RUBY_SOURCE_DIR}/configure
        --disable-install-doc --disable-rubygems
    BUILD_COMMAND make -j${NCPUS}
    INSTALL_COMMAND ""
    BUILD_BYPRODUCTS ${RUBY_NATIVE_BUILD_DIR}/miniruby
)

# ##############################################################################
# Cross compiled RUBY build
# ##############################################################################
if(SWITCH_RUBY_DEBUG)
    set(RUBY_CROSS_CONFIGURE_FLAGS "--debug")
endif()

set(RUBY_CROSS_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/ruby-cross-install)
set(RUBY_CROSS_LIBS 
    ${RUBY_CROSS_INSTALL_DIR}/lib/libruby-static.a
    ${RUBY_CROSS_BUILD_DIR}/enc/libenc.a
    ${RUBY_CROSS_BUILD_DIR}/enc/libtrans.a
)
set(RUBY_CROSS_EXT_LIBS
    ${RUBY_CROSS_BUILD_DIR}/ext/continuation/continuation.a
    ${RUBY_CROSS_BUILD_DIR}/ext/date/date_core.a
    ${RUBY_CROSS_BUILD_DIR}/ext/digest/digest.a
    ${RUBY_CROSS_BUILD_DIR}/ext/etc/etc.a
    ${RUBY_CROSS_BUILD_DIR}/ext/fcntl/fcntl.a
    ${RUBY_CROSS_BUILD_DIR}/ext/io/nonblock/nonblock.a
    ${RUBY_CROSS_BUILD_DIR}/ext/io/wait/wait.a
    ${RUBY_CROSS_BUILD_DIR}/ext/json/generator/generator.a
    ${RUBY_CROSS_BUILD_DIR}/ext/json/parser/parser.a
    ${RUBY_CROSS_BUILD_DIR}/ext/monitor/monitor.a
    ${RUBY_CROSS_BUILD_DIR}/ext/objspace/objspace.a
    ${RUBY_CROSS_BUILD_DIR}/ext/pathname/pathname.a
    ${RUBY_CROSS_BUILD_DIR}/ext/rbconfig/sizeof/sizeof.a
    ${RUBY_CROSS_BUILD_DIR}/ext/ripper/ripper.a
    ${RUBY_CROSS_BUILD_DIR}/ext/socket/socket.a
    ${RUBY_CROSS_BUILD_DIR}/ext/stringio/stringio.a
    ${RUBY_CROSS_BUILD_DIR}/ext/strscan/strscan.a
    ${RUBY_CROSS_BUILD_DIR}/ext/zlib/zlib.a
)
set(RUBY_LIB_DIR ${RUBY_CROSS_INSTALL_DIR}/lib/ruby/3.4.0)

ExternalProject_Add(switch_ruby_cross
    SOURCE_DIR ${RUBY_SOURCE_DIR}
    BINARY_DIR ${RUBY_CROSS_BUILD_DIR}
    CONFIGURE_COMMAND env
        NATIVE_BUILD=${RUBY_NATIVE_BUILD_DIR}
        PREFIX=${RUBY_CROSS_INSTALL_DIR}
        ${RUBY_SOURCE_DIR}/configure_switch.sh ${RUBY_CROSS_CONFIGURE_FLAGS}
    BUILD_COMMAND make -j${NCPUS} miniruby && make -j${NCPUS}
    # INSTALL_COMMAND ""
    BUILD_BYPRODUCTS
        ${RUBY_CROSS_LIBS}
        ${RUBY_CROSS_EXT_LIBS}
)

add_dependencies(switch_ruby_cross switch_ruby_native)

set(RUBY_CROSS_LIBS ${RUBY_CROSS_BUILD_DIR}/libruby-static.a)


# ##############################################################################
# Interface library
# ##############################################################################
add_library(ruby_switch INTERFACE)
add_library(Ruby::Switch ALIAS ruby_switch)
add_dependencies(ruby_switch ruby_cross)

target_include_directories(ruby_switch INTERFACE
    # Generic headers
    $<BUILD_INTERFACE:${RUBY_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0>
    # Target-specific headers
    $<BUILD_INTERFACE:${RUBY_BUILD_DIR}/.ext/include/aarch64-elf>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0/aarch64-elf>
)

# Link everything with --whole-archive to preserve Init_* symbols
target_link_options(ruby_switch INTERFACE
    -Wl,--whole-archive
)
target_link_libraries(ruby_switch INTERFACE
    # ruby core lib
    $<BUILD_INTERFACE:${RUBY_CROSS_LIBS}>
    $<BUILD_INTERFACE:${RUBY_CROSS_EXT_LIBS}>
    # ruby core extensions
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/libruby-static.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/libenc.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/libtrans.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/continuation/continuation.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/date/date_core.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/digest/digest.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/etc/etc.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/fcntl/fcntl.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/io/nonblock/nonblock.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/io/wait/wait.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/json/generator/generator.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/json/parser/parser.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/monitor/monitor.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/objspace/objspace.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/pathname/pathname.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/rbconfig/sizeof/sizeof.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/ripper/ripper.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/socket/socket.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/stringio/stringio.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/strscan/strscan.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext/zlib/zlib.a>
)
target_link_options(ruby_switch INTERFACE
    -Wl,--no-whole-archive
)
target_link_libraries(ruby_switch INTERFACE z m nx)

# ##############################################################################
# Install rules
# ##############################################################################
install(
    FILES ${RUBY_CROSS_BUILD_DIR}/libruby-static.a
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(
    FILES 
        ${RUBY_CROSS_BUILD_DIR}/enc/libenc.a 
        ${RUBY_CROSS_BUILD_DIR}/enc/libtrans.a
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0
)
install(
    DIRECTORY ${RUBY_CROSS_INSTALL_DIR}/include/ruby-3.4.0
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Install extension archives
install(
    FILES ${RUBY_CROSS_EXT_LIBS}
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/ruby-3.4.0/ext
)

# Install Ruby standard library
install(DIRECTORY ${RUBY_CROSS_INSTALL_DIR}/lib/ruby
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)