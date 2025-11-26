#!/bin/bash

set -x
set -e
set -o pipefail

export TOP_DIR=${GITHUB_WORKSPACE}
export CCACHE_DIR=${TOP_DIR}/.ccache
export WORKING_DIR=${TOP_DIR}/debian/output
export SRC_DIR_NAME=source_dir

#echo "deb http://deb.debian.org/debian testing main" > /etc/apt/sources.list

# # changes start
# apt-get update
# git config --global --add safe.directory /github/workspace/source_dir # TODO is this realy needed?
git config --global --add safe.directory /github/workspace/debian/output/source_dir
# # changes end

mkdir -p ${WORKING_DIR}
cp -ra ${TOP_DIR}/${SRC_DIR_NAME} ${WORKING_DIR}

# Enter source package dir
cd ${WORKING_DIR}/${SRC_DIR_NAME}

# Build orig-tar.
git archive HEAD | bzip2 > ../plxsdk_0.1.0.orig.tar.bz2

# Add deb-src entries
# # changes start
# if [ -f /etc/apt/sources.list ]; then
#     sed -n '/^deb\s/s//deb-src /p' /etc/apt/sources.list > /etc/apt/sources.list.d/deb-src.list
# elif [ -d /etc/apt/sources.list.d ]; then
#     if [ "$(ls -A /etc/apt/sources.list.d/*.list 2>/dev/null)" ]; then
#         for file in /etc/apt/sources.list.d/*.list; do
#             sed -n '/^deb\s/s//deb-src /p' "$file" >> /etc/apt/sources.list.d/deb-src.list
#         done
#     fi
#     if [ "$(ls -A /etc/apt/sources.list.d/*.sources 2>/dev/null)" ]; then
#         for file in /etc/apt/sources.list.d/*.sources; do
#             awk '/^Types:/ {if ($2 ~ /deb$/) print $0}' "$file" >> /etc/apt/sources.list.d/deb-src.list
#         done
#     fi
# fi
# # changes end
# sed -n '/^deb\s/s//deb-src /p' /etc/apt/sources.list > /etc/apt/sources.list.d/deb-src.list # new
# sed -n '/^deb\s/s//deb-src /p' /etc/apt/sources.list.d > /etc/apt/sources.list.d/deb-src.list # debug
> /etc/apt/sources.list.d/deb-src.list # empty the file first
for file in /etc/apt/sources.list.d/*.list; do
    sed -n '/^deb\s/s//deb-src /p' "$file" >> /etc/apt/sources.list.d/deb-src.list # >> appends instead of overwriting
done

# # added dh-kms, dkms, linux-libc-dev
# apt-get update && eatmydata apt-get install --no-install-recommends -y \
#      aptitude \
#      devscripts \
#      ccache \
#      equivs \
#      build-essential \
#      dh-dkms \
#      dkms \
#      linux-libc-dev

#new
apt-get update && eatmydata apt-get install --no-install-recommends -y \
     aptitude \
     devscripts \
     ccache \
     equivs \
     build-essential

# #changes start
# Install build dependencies directly
eatmydata mk-build-deps --install --remove --tool "apt-get -o Debug::pkgProblemResolver=yes -y" debian/control
# # changes end

# Generate ccache links
dpkg-reconfigure ccache
PATH="/usr/lib/ccache/:${PATH}"

# Reset ccache stats
ccache -z

 # Create build user and fix permissions
useradd buildci
chown -R buildci. ${WORKING_DIR} ${CCACHE_DIR}

# Define buildlog filename
BUILD_LOGFILE_SOURCE=$(dpkg-parsechangelog -S Source)
BUILD_LOGFILE_VERSION=$(dpkg-parsechangelog -S Version)
BUILD_LOGFILE_VERSION=${BUILD_LOGFILE_VERSION#*:}
BUILD_LOGFILE_ARCH=$(dpkg --print-architecture)
BUILD_LOGFILE="${WORKING_DIR}/${BUILD_LOGFILE_SOURCE}_${BUILD_LOGFILE_VERSION}_${BUILD_LOGFILE_ARCH}.build"

# Build package as user buildci
ls -la
ls -la ..
su buildci -c "eatmydata dpkg-buildpackage ${DB_BUILD_PARAM}" |& OUTPUT_FILENAME=${BUILD_LOGFILE} filter-output

ls -la
find

# Restore PWD to ${WORKING_DIR}
cd ${WORKING_DIR}
rm -rf ${WORKING_DIR}/${SRC_DIR_NAME}

# Revert ownership for CCACHE_DIR
chown -R $(id -nu). ${CCACHE_DIR}

# Print ccache stats on job log
ccache -s

ls -la
find