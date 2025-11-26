#!/bin/bash -x
set -e

rpmdev-setuptree

VERSION="0.1"

mv source_dir/src plxsdk-${VERSION}
tar -cvjf plxsdk-${VERSION}.tar.bz2 plxsdk-${VERSION}
cp *.tar.bz2 ~/rpmbuild/SOURCES/
cp source_dir/*.spec .

dnf builddep -y plxsdk.spec


rpmbuild -ba plxsdk.spec

mkdir -p ${GITHUB_WORKSPACE}/rpm-artifacts
cp -r ~/rpmbuild/RPMS ${GITHUB_WORKSPACE}/rpm-artifacts/
cp -r ~/rpmbuild/SRPMS ${GITHUB_WORKSPACE}/rpm-artifacts/