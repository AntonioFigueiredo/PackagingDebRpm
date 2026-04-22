#!/bin/bash -x
set -e

rpmdev-setuptree

VERSION="0.1"

# Import GPG key
if [ -n "$GPG_PRIVATE_KEY" ]; then
    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/ {print $5; exit}')

    cat > ~/.rpmmacros <<EOF
%_signature gpg
%_gpg_name $KEYID
%_gpgbin /usr/bin/gpg
%_gpg_path ~/.gnupg
EOF
fi

mv source_dir/src ${PROJECT_NAME}-${VERSION}
tar -cvjf ${PROJECT_NAME}-${VERSION}.tar.bz2 ${PROJECT_NAME}-${VERSION}
cp *.tar.bz2 ~/rpmbuild/SOURCES/
cp source_dir/*.spec .

dnf builddep -y ${PROJECT_NAME}.spec


rpmbuild -ba ${PROJECT_NAME}.spec

if [ -n "$GPG_PRIVATE_KEY" ]; then
    find . -name "*.rpm" -exec rpmsign --addsign {} \;
fi
echo "=== Verify RPM signatures ==="
rpm -Kv ~/rpmbuild/RPMS/*/*.rpm

mkdir -p ${GITHUB_WORKSPACE}/rpm-artifacts
cp -r ~/rpmbuild/RPMS ${GITHUB_WORKSPACE}/rpm-artifacts/
cp -r ~/rpmbuild/SRPMS ${GITHUB_WORKSPACE}/rpm-artifacts/

mkdir -p ${GITHUB_WORKSPACE}/rpm-artifacts/packages
find ~/rpmbuild/RPMS -type f -name "*.rpm" -exec cp {} ${GITHUB_WORKSPACE}/rpm-artifacts/packages/ \;
find ~/rpmbuild/SRPMS -type f -name "*.rpm" -exec cp {} ${GITHUB_WORKSPACE}/rpm-artifacts/packages/ \;

createrepo_c ${GITHUB_WORKSPACE}/rpm-artifacts/packages

if [ -n "$GPG_PUBLIC_KEY" ]; then
    echo "${GPG_PUBLIC_KEY}" > ${GITHUB_WORKSPACE}/rpm-artifacts/RPM-GPG-KEY-${PROJECT_NAME}
fi

cat > ${GITHUB_WORKSPACE}/rpm-artifacts/${PROJECT_NAME}.repo <<EOF
[${PROJECT_NAME}]
name=${PROJECT_NAME} RPM Repository
baseurl=https://${GITHUB_REPOSITORY_OWNER}.github.io/${GITHUB_REPOSITORY#*/}/rpm/${RPM_REPO_ID}/packages/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://${GITHUB_REPOSITORY_OWNER}.github.io/${GITHUB_REPOSITORY#*/}/rpm/${RPM_REPO_ID}/RPM-GPG-KEY-${PROJECT_NAME}
EOF
