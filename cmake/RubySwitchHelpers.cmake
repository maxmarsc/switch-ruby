# ruby_switch_setup_romfs(<target> <romfs_build_dir>)
#
# Copies the Ruby stdlib into <romfs_build_dir>/ruby/<version>/ as a
# build-time step that depends on the ruby cross build completing.
#
# The caller is responsible for pointing their NRO target at <romfs_build_dir>.
#
function(ruby_switch_setup_romfs target romfs_build_dir)
    if(DEFINED Ruby_RUBYLIBDIR AND Ruby_RUBYLIBDIR)
        # find_package path: use variables baked into RubyConfig.cmake
        set(_stdlib "${Ruby_RUBYLIBDIR}")
        set(_version "${Ruby_VERSION}")
    else()
        # FetchContent path: query the live target property
        get_target_property(_stdlib  Ruby::ruby RUBY_STDLIB_DIR)
        get_target_property(_version Ruby::ruby RUBY_VERSION)
    endif()

    if(NOT _stdlib OR _stdlib STREQUAL "_stdlib-NOTFOUND")
        message(FATAL_ERROR "ruby_switch_setup_romfs: Ruby::ruby has no RUBY_STDLIB_DIR property. "
                            "Is switch-ruby correctly configured?")
    endif()

    set(_dest "${romfs_build_dir}/ruby/${_version}")
    if(TARGET switch_ruby_cross)
        set(_depends DEPENDS switch_ruby_cross)
    else()
        set(_depends "")
    endif()

    # The actual copy — runs at build time after switch_ruby_cross completes
    add_custom_command(
        OUTPUT  "${_dest}/.stdlib_copied"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${_dest}"
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${_stdlib}" "${_dest}"
        COMMAND ${CMAKE_COMMAND} -E touch "${_dest}/.stdlib_copied"
        ${_depends}
        COMMENT "Copying Ruby ${_version} stdlib into romfs"
    )

    add_custom_target(ruby_stdlib_romfs
        DEPENDS "${_dest}/.stdlib_copied"
    )

    # Make the NRO target depend on the copy being done
    add_dependencies(${target} ruby_stdlib_romfs)
endfunction()