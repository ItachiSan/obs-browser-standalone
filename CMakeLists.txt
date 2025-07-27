cmake_minimum_required(VERSION 3.16...3.25)

project(obs-browser-standalone)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/helpers")

option(ENABLE_BROWSER "Enable browser source plugin (required Chromium Embedded Framework)" ON)

if(NOT ENABLE_BROWSER)
  target_disable(obs-browser)
  target_disable_feature(obs-browser "Browser sources are not enabled by default (set CEF_ROOT_DIR and ENABLE_BROWSER)")
  return()
endif()

# Retrieve their blob CEF. FetchContent does some weird stuff so do things by hand.
# Source for URL and hash: https://github.com/obsproject/obs-studio/blob/master/build-aux/modules/99-cef.json
if(NOT CEF_ROOT_DIR)
  message("-- [cef] CEF_ROOT_DIR not defined. Retrieving CEF blob...")
  file(DOWNLOAD
      "https://cdn-fastly.obsproject.com/downloads/cef_binary_6533_linux_x86_64_v5.tar.xz"
      "${CMAKE_BINARY_DIR}/cef_binary.tar.xz"
      SHOW_PROGRESS
      EXPECTED_HASH SHA256=df38ef6d8078895953d224a58dd811b83110b4f8644c5cd2b6246d04b0023ee6)
  message("-- [cef] Extracting CEF tarball...")
  file(ARCHIVE_EXTRACT
       INPUT "${CMAKE_BINARY_DIR}/cef_binary.tar.xz")
  set(CEF_ROOT_DIR "${CMAKE_BINARY_DIR}/cef_binary_6533_linux_x86_64")
  message("-- [cef] New CEF_ROOT_DIR: ${CEF_ROOT_DIR}")
endif()

find_package(CEF 95 REQUIRED)
find_package(nlohmann_json 3.11 REQUIRED)

# Find the required OBS libraries that normally are within the project
find_package(libobs REQUIRED)
find_package(obs-frontend-api REQUIRED)
find_package(obs-websocket-api REQUIRED)

# Add source and build directory to include path for proper header detection
set(CMAKE_INCLUDE_CURRENT_DIR TRUE)

add_library(obs-browser SHARED)
add_library(OBS::browser ALIAS obs-browser)

option(ENABLE_BROWSER_PANELS "Enable Qt web browser panel support" ON)
mark_as_advanced(ENABLE_BROWSER_PANELS)

target_sources(
  obs-browser
  PRIVATE # cmake-format: sortable
          browser-app.cpp
          browser-app.hpp
          browser-client.cpp
          browser-client.hpp
          browser-scheme.cpp
          browser-scheme.hpp
          browser-version.h
          cef-headers.hpp
          deps/base64/base64.cpp
          deps/base64/base64.hpp
          deps/signal-restore.cpp
          deps/signal-restore.hpp
          deps/wide-string.cpp
          deps/wide-string.hpp
          obs-browser-plugin.cpp
          obs-browser-source-audio.cpp
          obs-browser-source.cpp
          obs-browser-source.hpp)

target_include_directories(obs-browser PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/deps")

target_compile_features(obs-browser PRIVATE cxx_std_17)
target_link_libraries(obs-browser PRIVATE OBS::libobs OBS::obs-frontend-api OBS::obs-websocket-api nlohmann_json::nlohmann_json)

include(ObsHelpers)

if(OS_WINDOWS)
  include(cmake/os-windows.cmake)
elseif(OS_MACOS)
  include(cmake/os-macos.cmake)
elseif(OS_LINUX)
  include(cmake/os-linux.cmake)
endif()

if(ENABLE_BROWSER_PANELS)
  include(cmake/feature-panels.cmake)
endif()

set_target_properties_obs(obs-browser PROPERTIES FOLDER plugins/obs-browser PREFIX "")
