#!/bin/sh
# Dumb script for fetchin all the required CMake modules from the main project.

CMAKE_HELPER_MODULES=(
    ObsDefaults_Linux.cmake
    ObsDefaults_macOS.cmake
    ObsDefaults_Windows.cmake
    ObsHelpers.cmake
    ObsHelpers_Linux.cmake
    ObsHelpers_macOS.cmake
    ObsHelpers_Windows.cmake
)

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname "$THIS_FILE")

for cmake_module in ${CMAKE_HELPER_MODULES[@]}
do
    echo "# Fetching module $cmake_module"
    curl -L "https://github.com/obsproject/obs-studio/raw/master/cmake/Modules/$cmake_module" -o "$THIS_DIR/$cmake_module"
done