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

cat > ~/.aptly/public/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${PROJECT_NAME} APT Repository</title>
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
        <h1>${PROJECT_NAME} APT Repository</h1>
        <p>This repository hosts Debian packages for <strong>${PROJECT_NAME}</strong>.</p>

        <h2>Repository Files</h2>
        <ul>
          <li><a href="./repo-public-key.asc">Public signing key</a></li>
          <li><a href="./dists/${RELEASE}/Release">Release metadata</a></li>
          <li><a href="./dists/${RELEASE}/InRelease">InRelease metadata</a></li>
        </ul>

        <h2>Install</h2>
        <pre><code>curl -fsSL https://antoniofigueiredo.github.io/PlxSdk/apt/repo-public-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/${PROJECT_NAME}-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/${PROJECT_NAME}-archive-keyring.gpg] https://antoniofigueiredo.github.io/PlxSdk/apt ${RELEASE} main" | sudo tee /etc/apt/sources.list.d/${PROJECT_NAME}.list > /dev/null

sudo apt update
sudo apt install ${PROJECT_NAME}-dkms</code></pre>
      </div>
    </main>
  </body>
</html>
EOF


find ~/.aptly

tar czf debrepo.tar.gz -C ~/.aptly/public .