#!/bin/bash

set -x
set -e
set -o pipefail

export TOP_DIR=${GITHUB_WORKSPACE}
export CCACHE_DIR=${TOP_DIR}/.ccache
export WORKING_DIR=${TOP_DIR}/debian/output
export SRC_DIR_NAME=source_dir

git config --global --add safe.directory /github/workspace/debian/output/source_dir

mkdir -p ${WORKING_DIR}
cp -ra ${TOP_DIR}/${SRC_DIR_NAME} ${WORKING_DIR}

# Import GPG key if provided
if [ -n "$GPG_PRIVATE_KEY" ]; then
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
fi

# Enter source package dir
cd ${WORKING_DIR}/${SRC_DIR_NAME}

# Build orig-tar.
git archive HEAD | bzip2 > ../${PROJECT_NAME}_0.1.0.orig.tar.bz2

# Add deb-src entries
> /etc/apt/sources.list.d/deb-src.list # empty the file first
for file in /etc/apt/sources.list.d/*.list; do
    sed -n '/^deb\s/s//deb-src /p' "$file" >> /etc/apt/sources.list.d/deb-src.list # >> appends instead of overwriting
done

# Update package lists and install build dependencies
apt-get update && eatmydata apt-get install --no-install-recommends -y \
     aptitude \
     devscripts \
     ccache \
     equivs \
     build-essential

# Install build dependencies directly
eatmydata mk-build-deps --install --remove --tool "apt-get -o Debug::pkgProblemResolver=yes -y" debian/control

# Generate ccache links
dpkg-reconfigure ccache
PATH="/usr/lib/ccache/:${PATH}"

# Reset ccache stats
ccache -z

 # Create build user and fix permissions
useradd buildci

# Copy GPG keyring to buildci user
mkdir -p /home/buildci/.gnupg
chown -R buildci:buildci /home/buildci/.gnupg
chmod 700 /home/buildci/.gnupg
if [ -n "$GPG_PRIVATE_KEY" ]; then
    su buildci -c "echo \"$GPG_PRIVATE_KEY\" | gpg --batch --import"
fi

chown -R buildci:buildci ${WORKING_DIR} ${CCACHE_DIR}

# Define buildlog filename
BUILD_LOGFILE_SOURCE=$(dpkg-parsechangelog -S Source)
BUILD_LOGFILE_VERSION=$(dpkg-parsechangelog -S Version)
BUILD_LOGFILE_VERSION=${BUILD_LOGFILE_VERSION#*:}
BUILD_LOGFILE_ARCH=$(dpkg --print-architecture)
BUILD_LOGFILE="${WORKING_DIR}/${BUILD_LOGFILE_SOURCE}_${BUILD_LOGFILE_VERSION}_${BUILD_LOGFILE_ARCH}.build"

# Build package as user buildci
ls -la
ls -la ..
su buildci -c "eatmydata dpkg-buildpackage -kBD78A430515E1D36 ${DB_BUILD_PARAM}" |& OUTPUT_FILENAME=${BUILD_LOGFILE} filter-output

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