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

# This is not the actual ruby version (3.4.X), but it serves to set correct include/install paths
set(RUBY_VERSION "3.4.0")
set(RUBY_TARGET_ARCH "aarch64-elf")
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
    CONFIGURE_COMMAND ${RUBY_SOURCE_DIR}/autogen.sh
        COMMAND ${RUBY_SOURCE_DIR}/configure --disable-install-doc --disable-rubygems
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

set(RUBY_STATIC_LIB 
    $<BUILD_INTERFACE:${RUBY_CROSS_INSTALL_DIR}/lib/libruby-static.a>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/libruby-static.a>
)
# Listing of all relative paths for extensions
set(RUBY_EXT_LIBS_REL
    enc/libenc.a
    enc/libtrans.a
    ext/continuation/continuation.a
    ext/date/date_core.a
    ext/digest/digest.a
    ext/etc/etc.a
    ext/fcntl/fcntl.a
    ext/io/nonblock/nonblock.a
    ext/io/wait/wait.a
    ext/json/generator/generator.a
    ext/json/parser/parser.a
    ext/monitor/monitor.a
    ext/objspace/objspace.a
    ext/pathname/pathname.a
    ext/rbconfig/sizeof/sizeof.a
    ext/ripper/ripper.a
    ext/socket/socket.a
    ext/stringio/stringio.a
    ext/strscan/strscan.a
    ext/zlib/zlib.a
)

# Build concrete paths
foreach(rel IN LISTS RUBY_EXT_LIBS_REL)
    list(APPEND RUBY_EXT_LIBS_BUILD   "${RUBY_CROSS_BUILD_DIR}/${rel}")
    list(APPEND RUBY_EXT_LIBS_INSTALL "${CMAKE_INSTALL_LIBDIR}/${rel}")
endforeach()

ExternalProject_Add(switch_ruby_cross
    SOURCE_DIR ${RUBY_SOURCE_DIR}
    BINARY_DIR ${RUBY_CROSS_BUILD_DIR}
    CONFIGURE_COMMAND env
        NATIVE_BUILD=${RUBY_NATIVE_BUILD_DIR}
        PREFIX=${RUBY_CROSS_INSTALL_DIR}
        ${RUBY_SOURCE_DIR}/configure_switch.sh ${RUBY_CROSS_CONFIGURE_FLAGS}
    BUILD_COMMAND make -j${NCPUS} miniruby
        COMMAND make -j${NCPUS}
    BUILD_BYPRODUCTS
        ${RUBY_STATIC_LIB}
        ${RUBY_EXT_LIBS_BUILD}
)

add_dependencies(switch_ruby_cross switch_ruby_native)


# ##############################################################################
# Interface library
# ##############################################################################
add_library(ruby_switch INTERFACE)
add_library(Ruby::Switch ALIAS ruby_switch)
add_dependencies(ruby_switch switch_ruby_cross)

target_include_directories(ruby_switch INTERFACE
    # Generic headers
    $<BUILD_INTERFACE:${RUBY_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0>
    # Target-specific headers
    $<BUILD_INTERFACE:${RUBY_CROSS_BUILD_DIR}/.ext/include/aarch64-elf>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0/aarch64-elf>
)

target_link_libraries(ruby_switch INTERFACE
    # ruby core lib
    ${RUBY_STATIC_LIB}
    # ruby core extensions - link with whole-archive to preserve Init_* symbols
    $<LINK_LIBRARY:WHOLE_ARCHIVE,$<BUILD_INTERFACE:${RUBY_EXT_LIBS_BUILD}>>
    $<LINK_LIBRARY:WHOLE_ARCHIVE,$<INSTALL_INTERFACE:${RUBY_EXT_LIBS_INSTALL}>>
    # system libs
    z m nx
)

# ##############################################################################
# Install rules
# ##############################################################################
# install archives - base install is broken so we cannot use RUBY_CROSS_INSTALL_DIR
install(
    FILES ${RUBY_CROSS_BUILD_DIR}/libruby-static.a
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(
    FILES 
        ${RUBY_CROSS_BUILD_DIR}/enc/libenc.a 
        ${RUBY_CROSS_BUILD_DIR}/enc/libtrans.a
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/enc
)
install(
    DIRECTORY ${RUBY_CROSS_BUILD_DIR}/ext/
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/ext
    FILES_MATCHING PATTERN "*.a"
)

# Install headers
install(
    DIRECTORY ${RUBY_CROSS_INSTALL_DIR}/include/ruby-${RUBY_VERSION}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Install Ruby standard library
install(DIRECTORY ${RUBY_CROSS_INSTALL_DIR}/lib/ruby
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)