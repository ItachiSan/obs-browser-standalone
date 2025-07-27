#!/bin/sh
# Dumb script for fetching all the required CMake modules from the main project.
# Don't use for now!

OBS_VERSION="31.1.1"

_myself=$(readlink -f $0)
_mydir=$(dirname "$_myself")

echo "Working in: $_mydir"

echo "# Preparing work directory..."
#workdir="$(mktemp -d)"
workdir="${_mydir}/unpack"
mkdir -p $workdir
cd $workdir

if [ ! -f "$OBS_VERSION.tar.gz" ]
then
    echo "# Retrieving latest OBS sources..."
    curl -LO "https://github.com/obsproject/obs-studio/archive/refs/tags/$OBS_VERSION.tar.gz"
    tar xf "$OBS_VERSION.tar.gz"
fi

echo "# Merge CMake files..."
cd "obs-studio-$OBS_VERSION"
cp -r cmake "${_mydir}"

echo "# Clean up..."
rm -r $workdir