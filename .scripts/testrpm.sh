#!/bin/bash
set -e
set -o pipefail

mkdir -p rpmPkgs

find . -type f -name "*.rpm" -exec mv {} rpmPkgs/ \;
if [ -z "$(ls -A rpmPkgs/*.rpm 2>/dev/null)" ]; then
  echo "ERROR: No .rpm files found in artifacts!"
  exit 1
fi

ERRCODE=0
for rpm in rpmPkgs/*.rpm; do
  if [[ "$rpm" == *.src.rpm ]]; then
    echo "Skipping source RPM: $rpm"
    continue
  fi
  echo "Installing $rpm"
  dnf -y install "$rpm" || ERRCODE=$?
done

if [ $ERRCODE -ne 0 ]; then
  echo "ERROR: Failed to install one or more RPMs!"
  exit $ERRCODE
fi

dkms status

find /var/lib/dkms/ -iname "make.log" -exec grep -H . {} \;
exit ${ERRCODE}

if dkms status | grep -q cros3; then
  echo "SUCCESS: cros3 DKMS module is installed."
  exit 0  # Force success if module exists
else
  echo "ERROR: cros3 DKMS module not found!"
  exit 1
fi