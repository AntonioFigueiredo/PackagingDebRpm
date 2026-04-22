#!/bin/bash
set -e
set -o pipefail

rpmdev-setuptree

VERSION="0.1"
REPO_ROOT="${GITHUB_WORKSPACE}/rpm-artifacts"
PACKAGES_DIR="${REPO_ROOT}/packages"
REPO_OWNER_LC=$(printf '%s' "${GITHUB_REPOSITORY_OWNER}" | tr '[:upper:]' '[:lower:]')
REPO_NAME_LC=$(printf '%s' "${GITHUB_REPOSITORY#*/}" | tr '[:upper:]' '[:lower:]')
REPO_BASE_URL="https://${REPO_OWNER_LC}.github.io/${REPO_NAME_LC}/rpm/${RPM_REPO_ID}"

# Import GPG key
if [ -n "$GPG_PRIVATE_KEY" ]; then
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg

    echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')
    FINGERPRINT=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')


    if [ -z "$KEYID" ]; then
        echo "ERROR: Could not determine GPG key ID for RPM signing"
        exit 1
    fi

    if [ -z "$FINGERPRINT" ]; then
        echo "ERROR: Could not determine GPG fingerprint for RPM signing"
        exit 1
    fi

    cat > ~/.rpmmacros <<EOF
%_signature gpg
%_gpg_name $FINGERPRINT
%_gpgbin /usr/bin/gpg
%_gpg_path ~/.gnupg
EOF
fi

if [ -z "${RPM_REPO_ID}" ]; then
    echo "ERROR: RPM_REPO_ID is not set"
    exit 1
fi

mv source_dir/src ${PROJECT_NAME}-${VERSION}
tar -cvjf ${PROJECT_NAME}-${VERSION}.tar.bz2 ${PROJECT_NAME}-${VERSION}
cp *.tar.bz2 ~/rpmbuild/SOURCES/
cp source_dir/*.spec .

dnf builddep -y ${PROJECT_NAME}.spec


rpmbuild -ba ${PROJECT_NAME}.spec

if [ -n "$GPG_PRIVATE_KEY" ]; then
    command -v rpmsign
    find ~/rpmbuild/RPMS -type f -name "*.rpm" -exec rpmsign --addsign {} \;
    find ~/rpmbuild/SRPMS -type f -name "*.rpm" -exec rpmsign --addsign {} \;
fi

if [ -n "$GPG_PUBLIC_KEY" ]; then
    echo "${GPG_PUBLIC_KEY}" > /tmp/RPM-GPG-KEY-${PROJECT_NAME}
    rpm --import /tmp/RPM-GPG-KEY-${PROJECT_NAME}
fi

echo "=== Verify binary RPM signatures ==="
rpm -Kv ~/rpmbuild/RPMS/*/*.rpm

echo "=== Verify source RPM signatures ==="
rpm -Kv ~/rpmbuild/SRPMS/*.rpm

mkdir -p "${REPO_ROOT}"
cp -r ~/rpmbuild/RPMS "${REPO_ROOT}/"
cp -r ~/rpmbuild/SRPMS "${REPO_ROOT}/"

mkdir -p "${PACKAGES_DIR}"
find ~/rpmbuild/RPMS -type f -name "*.rpm" -exec cp {} "${PACKAGES_DIR}/" \;
find ~/rpmbuild/SRPMS -type f -name "*.rpm" -exec cp {} "${PACKAGES_DIR}/" \;

createrepo_c "${PACKAGES_DIR}"

if [ -n "$GPG_PUBLIC_KEY" ]; then
    echo "${GPG_PUBLIC_KEY}" > "${REPO_ROOT}/RPM-GPG-KEY-${PROJECT_NAME}"
fi

cat > "${REPO_ROOT}/${PROJECT_NAME}.repo" <<EOF
[${PROJECT_NAME}]
name=${PROJECT_NAME} RPM Repository
baseurl=${REPO_BASE_URL}/packages/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=${REPO_BASE_URL}/RPM-GPG-KEY-${PROJECT_NAME}
EOF

cat > "${REPO_ROOT}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${PROJECT_NAME} RPM Repository</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f6f7f4;
        --card: #ffffff;
        --text: #1f2933;
        --muted: #52606d;
        --accent: #0b6e4f;
        --border: #d9e2ec;
        --code: #f0f4f8;
      }
      body {
        margin: 0;
        font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: linear-gradient(180deg, #eef6f1 0%, var(--bg) 100%);
        color: var(--text);
      }
      main {
        max-width: 860px;
        margin: 48px auto;
        padding: 0 20px;
      }
      .card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 28px;
        box-shadow: 0 10px 30px rgba(15, 23, 42, 0.06);
      }
      h1, h2 {
        margin-top: 0;
      }
      p, li {
        line-height: 1.6;
      }
      a {
        color: var(--accent);
      }
      pre {
        background: var(--code);
        border-radius: 12px;
        padding: 16px;
        overflow-x: auto;
        white-space: pre-wrap;
      }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <h1>${PROJECT_NAME} RPM Repository</h1>
        <p>This repository hosts RPM packages for <strong>${PROJECT_NAME}</strong>.</p>

        <h2>Repository Files</h2>
        <ul>
          <li><a href="./RPM-GPG-KEY-${PROJECT_NAME}">Public signing key</a></li>
          <li><a href="./${PROJECT_NAME}.repo">Repository configuration</a></li>
          <li><a href="./packages/repodata/repomd.xml">Repository metadata</a></li>
        </ul>

        <h2>Install</h2>
        <pre><code>sudo curl -fsSL ${REPO_BASE_URL}/${PROJECT_NAME}.repo -o /etc/yum.repos.d/${PROJECT_NAME}.repo

sudo dnf makecache
sudo dnf install ${PROJECT_NAME}</code></pre>
      </div>
    </main>
  </body>
</html>
EOF
