#!/bin/bash
set -e
set -o pipefail

mkdir -p pkgs

#mv *-debpkg/*.deb pkgs/
find . -type f -name "*.deb" -exec mv {} pkgs/ \;
if [ -z "$(ls -A pkgs/*.deb 2>/dev/null)" ]; then
  echo "ERROR: No .deb files found in artifacts!"
  exit 1
fi

apt -y update
#ERRCODE=0
apt -y install dkms

ERRCODE=0
for deb in pkgs/*.deb; do
  echo "Installing $deb"
  apt -y install "./$deb" || ERRCODE=$?
done

dkms status

find /var/lib/dkms/ -iname "make.log" -exec grep -H . {} \;
exit ${ERRCODE}