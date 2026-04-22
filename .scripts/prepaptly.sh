#!/bin/bash
set -e
set -o pipefail

PKGDIR=pkgs

mkdir -p ${PKGDIR}
mv *-debpkg/*.deb ${PKGDIR}

mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

echo "${GPG_PRIVATE_KEY}" | gpg --batch --import

KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')
if [ -z "${KEYID}" ]; then
    echo "ERROR: Could not determine GPG key ID"
    exit 1
fi

aptly repo create -distribution "${RELEASE}" -component main "${PROJECT_NAME}"
aptly repo add "${PROJECT_NAME}" "${PKGDIR}"
# aptly repo show -with-packages "${PROJECT_NAME}"

ARCHITECTURES=$(
	aptly repo show -with-packages "${PROJECT_NAME}" | \
		awk 'BEGIN {FS="_"} /^Packages:/ {x=NR} (x && NR>x) {print $3}' | \
		egrep -v '^$' | sort -u | tr '\n' ','); \

echo "$ARCHITECTURES"

aptly publish repo \
		-gpg-key="${KEYID}" \
		${ARCHITECTURES:+ -architectures="${ARCHITECTURES}"} \
		"${PROJECT_NAME}"

mkdir -p ~/.aptly/public
echo "${GPG_PUBLIC_KEY}" > ~/.aptly/public/repo-public-key.asc

find ~/.aptly

tar czf debrepo.tar.gz -C ~/.aptly/public .