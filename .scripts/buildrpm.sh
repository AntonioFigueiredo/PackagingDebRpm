#!/bin/bash -x
set -e

rpmdev-setuptree

VERSION="0.1"

mv source_dir/src ${PROJECT_NAME}-${VERSION}
tar -cvjf ${PROJECT_NAME}-${VERSION}.tar.bz2 ${PROJECT_NAME}-${VERSION}
cp *.tar.bz2 ~/rpmbuild/SOURCES/
cp source_dir/*.spec .

dnf builddep -y ${PROJECT_NAME}.spec


rpmbuild -ba ${PROJECT_NAME}.spec

mkdir -p ${GITHUB_WORKSPACE}/rpm-artifacts
cp -r ~/rpmbuild/RPMS ${GITHUB_WORKSPACE}/rpm-artifacts/
cp -r ~/rpmbuild/SRPMS ${GITHUB_WORKSPACE}/rpm-artifacts/