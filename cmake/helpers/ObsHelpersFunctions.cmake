# OBS CMake Linux helper functions module

include_guard(GLOBAL)

include(helpers_common)

# set_target_properties_obs: Set target properties for use in obs-studio
function(set_target_properties_obs target)
  set(options "")
  set(oneValueArgs "")
  set(multiValueArgs PROPERTIES)
  cmake_parse_arguments(PARSE_ARGV 0 _STPO "${options}" "${oneValueArgs}" "${multiValueArgs}")

  message(DEBUG "Setting additional properties for target ${target}...")

  while(_STPO_PROPERTIES)
    list(POP_FRONT _STPO_PROPERTIES key value)
    set_property(TARGET ${target} PROPERTY ${key} "${value}")
  endwhile()

  get_target_property(target_type ${target} TYPE)
  set(OBS_SOVERSION 30)

  if(target_type STREQUAL EXECUTABLE)
    install(TARGETS ${target} RUNTIME DESTINATION "${OBS_EXECUTABLE_DESTINATION}" COMPONENT Runtime)

    add_custom_command(
      TARGET ${target}
      POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_EXECUTABLE_DESTINATION}"
      COMMAND
        "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:${target}>"
        "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_EXECUTABLE_DESTINATION}"
      COMMENT "Copy ${target} to binary directory"
      VERBATIM
    )

    if(target STREQUAL browser-helper)
      set_property(GLOBAL APPEND PROPERTY _OBS_EXECUTABLES ${target})
      return()
    endif()

    set_target_properties(
      ${target}
      PROPERTIES
        BUILD_RPATH "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_LIBRARY_DESTINATION}"
        INSTALL_RPATH "${OBS_EXECUTABLE_RPATH}"
    )
  elseif(target_type STREQUAL SHARED_LIBRARY)
    set_target_properties(
      ${target}
      PROPERTIES
        VERSION ${OBS_SOVERSION}
        SOVERSION ${OBS_SOVERSION}
        BUILD_RPATH "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_LIBRARY_DESTINATION}"
        INSTALL_RPATH "${OBS_LIBRARY_RPATH}"
    )

    install(
      TARGETS ${target}
      LIBRARY DESTINATION "${OBS_LIBRARY_DESTINATION}" COMPONENT Runtime
      PUBLIC_HEADER DESTINATION "${OBS_INCLUDE_DESTINATION}" COMPONENT Development EXCLUDE_FROM_ALL
    )

    add_custom_command(
      TARGET ${target}
      POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_LIBRARY_DESTINATION}"
      COMMAND
        "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:${target}>"
        "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_LIBRARY_DESTINATION}/"
      COMMAND
        "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_SONAME_FILE:${target}>"
        "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_LIBRARY_DESTINATION}/"
      COMMENT "Copy ${target} to library directory (${OBS_LIBRARY_DESTINATION})"
      VERBATIM
    )

    if(${target} STREQUAL obs-browser)
      message(DEBUG "Add Chromium Embedded Framework to project for obs-browser plugin...")
      if(TARGET CEF::Library)
        get_target_property(imported_location CEF::Library IMPORTED_LOCATION_RELEASE)

        if(imported_location)
          cmake_path(GET imported_location PARENT_PATH cef_location)
          cmake_path(GET cef_location PARENT_PATH cef_root_location)
          add_custom_command(
            TARGET ${target}
            POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_PLUGIN_DESTINATION}/"
            COMMAND
              "${CMAKE_COMMAND}" -E copy_if_different "${imported_location}" "${cef_location}/chrome-sandbox"
              "${cef_location}/libEGL.so" "${cef_location}/libGLESv2.so" "${cef_location}/libvk_swiftshader.so"
              "${cef_location}/libvulkan.so.1" "${cef_location}/v8_context_snapshot.bin"
              "${cef_location}/vk_swiftshader_icd.json" "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_PLUGIN_DESTINATION}/"
            COMMAND
              "${CMAKE_COMMAND}" -E copy_if_different "${cef_root_location}/Resources/chrome_100_percent.pak"
              "${cef_root_location}/Resources/chrome_200_percent.pak" "${cef_root_location}/Resources/icudtl.dat"
              "${cef_root_location}/Resources/resources.pak" "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_PLUGIN_DESTINATION}/"
            COMMAND
              "${CMAKE_COMMAND}" -E copy_directory "${cef_root_location}/Resources/locales"
              "${OBS_OUTPUT_DIR}/$<CONFIG>/${OBS_PLUGIN_DESTINATION}/locales"
            COMMENT "Add Chromium Embedded Framwork to library directory"
          )

          install(
            FILES
              "${imported_location}"
              "${cef_location}/chrome-sandbox"
              "${cef_location}/libEGL.so"
              "${cef_location}/libGLESv2.so"
              "${cef_location}/libvk_swiftshader.so"
              "${cef_location}/libvulkan.so.1"
              "${cef_location}/v8_context_snapshot.bin"
              "${cef_location}/vk_swiftshader_icd.json"
              "${cef_root_location}/Resources/chrome_100_percent.pak"
              "${cef_root_location}/Resources/chrome_200_percent.pak"
              "${cef_root_location}/Resources/icudtl.dat"
              "${cef_root_location}/Resources/resources.pak"
            DESTINATION "${OBS_PLUGIN_DESTINATION}"
            COMPONENT Runtime
          )

          install(
            DIRECTORY "${cef_root_location}/Resources/locales"
            DESTINATION "${OBS_PLUGIN_DESTINATION}"
            USE_SOURCE_PERMISSIONS
            COMPONENT Runtime
          )
        endif()
      endif()
    endif()
  endif()

  target_install_resources(${target})
endfunction()

# Helper function to add resources into bundle
function(target_install_resources target)
  message(DEBUG "Installing resources for target ${target}...")
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data")
    file(GLOB_RECURSE data_files "${CMAKE_CURRENT_SOURCE_DIR}/data/*")
    foreach(data_file IN LISTS data_files)
      cmake_path(
        RELATIVE_PATH
        data_file
        BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/data/"
        OUTPUT_VARIABLE relative_path
      )
      cmake_path(GET relative_path PARENT_PATH relative_path)
      target_sources(${target} PRIVATE "${data_file}")
      source_group("Resources/${relative_path}" FILES "${data_file}")
    endforeach()

    get_property(obs_module_list GLOBAL PROPERTY OBS_MODULES_ENABLED)
    if(target IN_LIST obs_module_list)
      set(target_destination "${OBS_DATA_DESTINATION}/obs-plugins/${target}")
    elseif(target STREQUAL obs)
      set(target_destination "${OBS_DATA_DESTINATION}/obs-studio")
    else()
      set(target_destination "${OBS_DATA_DESTINATION}/${target}")
    endif()

    install(
      DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/data/"
      DESTINATION "${target_destination}"
      USE_SOURCE_PERMISSIONS
      COMPONENT Runtime
    )

    add_custom_command(
      TARGET ${target}
      POST_BUILD
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${OBS_OUTPUT_DIR}/$<CONFIG>/${target_destination}"
      COMMAND
        "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/data"
        "${OBS_OUTPUT_DIR}/$<CONFIG>/${target_destination}"
      COMMENT "Copy ${target} resources to data directory (${target_destination})"
      VERBATIM
    )
  endif()
endfunction()

# Helper function to add a specific resource to a bundle
function(target_add_resource target resource)
  get_property(obs_module_list GLOBAL PROPERTY OBS_MODULES_ENABLED)
  if(ARGN)
    set(target_destination "${ARGN}")
  elseif(${target} IN_LIST obs_module_list)
    set(target_destination "${OBS_DATA_DESTINATION}/obs-plugins/${target}")
  elseif(target STREQUAL obs)
    set(target_destination "${OBS_DATA_DESTINATION}/obs-studio")
  else()
    set(target_destination "${OBS_DATA_DESTINATION}/${target}")
  endif()

  message(DEBUG "Add resource ${resource} to target ${target} at destination ${target_destination}...")

  install(FILES "${resource}" DESTINATION "${target_destination}" COMPONENT Runtime)

  add_custom_command(
    TARGET ${target}
    POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OBS_OUTPUT_DIR}/$<CONFIG>/${target_destination}/"
    COMMAND "${CMAKE_COMMAND}" -E copy "${resource}" "${OBS_OUTPUT_DIR}/$<CONFIG>/${target_destination}/"
    COMMENT "Copy ${target} resource ${resource} to library directory (${target_destination})"
    VERBATIM
  )
endfunction()

