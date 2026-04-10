cmake_minimum_required(VERSION 3.28)
project(switch-ruby-example-fetch-content LANGUAGES C CXX ASM)

# ##############################################################################
# C/C++ setup
# ##############################################################################
set(CMAKE_C_STANDARD 23)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)


# ##############################################################################
# Dependency setup
# ##############################################################################
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/common)
include(SwitchTools)
find_package(Libnx REQUIRED)

# find zlib
set(ENV{PKG_CONFIG_PATH} "${PORTLIBS}/lib/pkgconfig")
find_package(PkgConfig REQUIRED)
pkg_check_modules(ZLIB REQUIRED IMPORTED_TARGET zlib)

# ##############################################################################
# find_package setup for switch-ruby
# ##############################################################################
find_package(Ruby CONFIG REQUIRED)

# ##############################################################################
# Executable
# ##############################################################################
add_executable(
  ruby_app
  ${CMAKE_CURRENT_SOURCE_DIR}/common/main.cpp
)

set_target_properties(
  ruby_app
  PROPERTIES APP_TITLE "Ruby Application"
             APP_AUTHOR "maxmarsc"
             APP_VERSION "0.1.0"
             ROMFS "${CMAKE_CURRENT_BINARY_DIR}/romfs"
)

target_link_libraries(
  ruby_app
  PRIVATE Ruby::ruby
)

target_compile_definitions(
  ruby_app
  PRIVATE
    RUBY_TMP_DIR="sdmc:/switch/.tmp_ruby"
    RUBY_STDLIB_DIR="romfs:/ruby/3.4.0"
    RUBY_MAIN_APP="romfs:/ruby/app/main.rb"
)

# ##############################################################################
# ROMFS setup
# ##############################################################################
# First copy the source ROMFS to the build dir
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/common/romfs
    DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
)

# Then add the ruby stdlib to the ROMFS
ruby_switch_setup_romfs(ruby_app ${CMAKE_CURRENT_BINARY_DIR}/romfs)

# ##############################################################################
# Final setup
# ##############################################################################
add_nro_target(ruby_app)