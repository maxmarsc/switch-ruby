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

# find zlib
set(ENV{PKG_CONFIG_PATH} "${PORTLIBS}/lib/pkgconfig")
find_package(PkgConfig REQUIRED)
pkg_check_modules(ZLIB REQUIRED IMPORTED_TARGET zlib)

# This is not the actual ruby version (3.4.X), but it serves to set correct include/install paths
set(RUBY_VERSION "3.4.0")
set(RUBY_TARGET_ARCH "aarch64-elf")
set(RUBY_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(RUBY_CROSS_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/ruby-cross)
set(RUBY_NATIVE_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/ruby-native)

ProcessorCount(NCPUS)

# ##############################################################################
# Helper setup
# ##############################################################################
# Include helper script for ROMFS
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/RubySwitchHelpers.cmake)

define_property(TARGET PROPERTY RUBY_STDLIB_DIR
    BRIEF_DOCS "Path to the Ruby ${RUBY_VERSION} standard library directory"
    FULL_DOCS  "Use this with ruby_switch_setup_romfs() to populate a romfs build tree"
)
define_property(TARGET PROPERTY RUBY_VERSION
    BRIEF_DOCS "Ruby version string"
    FULL_DOCS  "e.g. 3.4.0"
)


# ##############################################################################
# Native RUBY build - required for cross-compilation and install phase
# ##############################################################################
ExternalProject_Add(switch_ruby_native
    SOURCE_DIR ${RUBY_SOURCE_DIR}
    BINARY_DIR ${RUBY_NATIVE_BUILD_DIR}
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_UPDATE ON
    LOG_INSTALL ON
    LOG_OUTPUT_ON_FAILURE ON
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
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_UPDATE ON
    LOG_INSTALL ON
    LOG_OUTPUT_ON_FAILURE ON
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
add_library(ruby INTERFACE)
add_library(Ruby::ruby ALIAS ruby)
add_dependencies(ruby switch_ruby_cross)

target_include_directories(ruby INTERFACE
    # Generic headers
    $<BUILD_INTERFACE:${RUBY_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0>
    # Target-specific headers
    $<BUILD_INTERFACE:${RUBY_CROSS_BUILD_DIR}/.ext/include/aarch64-elf>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/ruby-3.4.0/aarch64-elf>
)

target_link_libraries(ruby INTERFACE
    # ruby core lib
    ${RUBY_STATIC_LIB}
    # ruby core extensions - link with whole-archive to preserve Init_* symbols
    $<BUILD_INTERFACE:
        -Wl,--whole-archive
        ${RUBY_EXT_LIBS_BUILD}
        -Wl,--no-whole-archive
    >
    $<INSTALL_INTERFACE:
        -Wl,--whole-archive
        ${RUBY_EXT_LIBS_INSTALL}
        -Wl,--no-whole-archive
    >
    # system libs
    switch::libnx # see https://github.com/vbe0201/switch-cmake
    PkgConfig::ZLIB
    m
)

set_target_properties(ruby PROPERTIES
    RUBY_STDLIB_DIR ${RUBY_CROSS_INSTALL_DIR}/lib/ruby/${RUBY_VERSION}
    RUBY_VERSION    ${RUBY_VERSION}
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

# ##############################################################################
# find_package support
# ##############################################################################
include(CMakePackageConfigHelpers)

# Generate RubyConfig.cmake from the template
configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RubyConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/RubyConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Ruby
    # These tell configure_package_config_file which variables to make relocatable
    PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
)

# Generate RubyConfigVersion.cmake
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/RubyConfigVersion.cmake
    VERSION ${RUBY_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Install both generated files and the helper functions
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/RubyConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/RubyConfigVersion.cmake
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RubySwitchHelpers.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Ruby
)

# Attach the target to an export set called "RubyTargets"
install(TARGETS ruby
    EXPORT RubyTargets
)

# Write RubyTargets.cmake into the install tree
install(EXPORT RubyTargets
    NAMESPACE Ruby::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/Ruby
)

# ##############################################################################
# pkg-config support
# ##############################################################################
set(_pc_libs "-lruby-static -Wl,--whole-archive")

# Walk the relative path list to generate the correct -L and -l flags for the pkg-config file
foreach(rel IN LISTS RUBY_EXT_LIBS_REL)
    get_filename_component(_dir  "${rel}" DIRECTORY)
    get_filename_component(_name "${rel}" NAME_WE)
    string(REGEX REPLACE "^lib" "" _libname "${_name}")
    if(_dir STREQUAL "")
        string(APPEND _pc_libs " -l${_libname}")
    else()
        string(APPEND _pc_libs " -L\${libdir}/${_dir} -l${_libname}")
    endif()
endforeach()

# system libs
string(APPEND _pc_libs " -Wl,--no-whole-archive -lz -lm -lnx")

set(RUBY_PC_LIBS "${_pc_libs}")


# GNUInstallDirs gives absolute paths — pkg-config needs relative-to-prefix
# CMAKE_INSTALL_LIBDIR is already relative (e.g. "lib"), but guard against an absolute override
cmake_path(RELATIVE_PATH CMAKE_INSTALL_LIBDIR
    BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}"
    OUTPUT_VARIABLE CMAKE_INSTALL_LIBDIR_REL)
cmake_path(RELATIVE_PATH CMAKE_INSTALL_INCLUDEDIR
    BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}"
    OUTPUT_VARIABLE CMAKE_INSTALL_INCLUDEDIR_REL)

configure_file(
    cmake/ruby.pc.in
    ${CMAKE_CURRENT_BINARY_DIR}/ruby.pc
    @ONLY
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ruby.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)