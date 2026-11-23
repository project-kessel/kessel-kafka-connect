#!/usr/bin/env bash
# bump-debezium.sh — Pin a Debezium version in artifacts.lock.yaml.
#
# Downloads the Debezium artifacts the image installs, computes their SHA-256
# checksums, and rewrites artifacts.lock.yaml. Konflux (and `make prefetch`)
# then fetch exactly these files and verify them against the checksums.
#
# Usage:
#   ./scripts/bump-debezium.sh VERSION      e.g. 3.1.3.Final
#
# Environment:
#   MAVEN_REPO  Maven repository base URL (default: https://repo1.maven.org/maven2)
#   LOCKFILE    Lockfile to write (default: artifacts.lock.yaml at the repo root)
#
# Prerequisites: curl, sha256sum or shasum, network access to MAVEN_REPO

set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: $0 VERSION   (e.g. 3.1.3.Final)" >&2
    exit 1
fi
VERSION="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAVEN_REPO="${MAVEN_REPO:-https://repo1.maven.org/maven2}"
LOCKFILE="${LOCKFILE:-$SCRIPT_DIR/../artifacts.lock.yaml}"

if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# fetch_sha256 ARTIFACT_ID FILE_SUFFIX -> prints the SHA-256 of the downloaded file
fetch_sha256() {
    local artifact="$1" suffix="$2"
    local url="$MAVEN_REPO/io/debezium/$artifact/$VERSION/$artifact-$VERSION$suffix"
    local file="$WORKDIR/$artifact$suffix"
    echo "Downloading $url" >&2
    if ! curl -fsSL -o "$file" "$url"; then
        echo "ERROR: failed to download $url" >&2
        return 1
    fi
    sha256 "$file"
}

POSTGRES_SHA256=$(fetch_sha256 debezium-connector-postgres -plugin.tar.gz)
SCRIPTING_SHA256=$(fetch_sha256 debezium-scripting .tar.gz)

cat > "$WORKDIR/artifacts.lock.yaml" <<EOF
# Debezium artifacts installed into the image.
#
# Konflux prefetches these with Hermeto (generic package manager) before the
# network-isolated build, verifies each checksum, and records them in the SBOM.
# The Dockerfile reads them from /cachi2/output/deps/generic/<filename>.
#
# Do not edit by hand. To change the Debezium version run:
#   make bump-debezium DEBEZIUM_VERSION=<x.y.z.Final>
metadata:
  version: "1.0"
artifacts:
  - type: maven
    filename: debezium-connector-postgres-plugin.tar.gz
    attributes:
      repository_url: $MAVEN_REPO
      group_id: io.debezium
      artifact_id: debezium-connector-postgres
      version: $VERSION
      classifier: plugin
      type: tar.gz
    checksum: sha256:$POSTGRES_SHA256
  - type: maven
    filename: debezium-scripting.tar.gz
    attributes:
      repository_url: $MAVEN_REPO
      group_id: io.debezium
      artifact_id: debezium-scripting
      version: $VERSION
      type: tar.gz
    checksum: sha256:$SCRIPTING_SHA256
EOF

# Replace the lockfile only after both downloads succeeded.
mv "$WORKDIR/artifacts.lock.yaml" "$LOCKFILE"
echo "Pinned Debezium $VERSION in $LOCKFILE"
