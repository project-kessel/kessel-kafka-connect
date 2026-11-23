#!/usr/bin/env bash
# generate-checksums.sh — Compute SHA-256 checksums for Debezium artifacts.
#
# Run this when bumping Debezium: set the new version on both entries in
# artifacts.lock.yaml, then paste the checksum lines printed here into the
# matching entries.
#
# Usage:
#   ./scripts/generate-checksums.sh VERSION      e.g. 3.1.3.Final
#
# Prerequisites: curl, sha256sum or shasum, network access to repo1.maven.org

set -euo pipefail

MAVEN_REPO="https://repo1.maven.org/maven2"

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: $0 VERSION   (e.g. 3.1.3.Final)" >&2
    exit 1
fi
VERSION="$1"

echo "Computing SHA-256 checksums for Debezium $VERSION"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

compute_sha256() {
    local artifact="$1" url="$2"
    local file="$TMPDIR/$(basename "$url")"

    echo "Downloading: $(basename "$url")"
    if ! curl -fsSL -o "$file" "$url"; then
        echo "ERROR: Failed to download $url"
        return 1
    fi

    local sha256
    if command -v sha256sum >/dev/null 2>&1; then
        sha256=$(sha256sum "$file" | cut -d' ' -f1)
    else
        sha256=$(shasum -a 256 "$file" | cut -d' ' -f1)
    fi
    printf '    %-28s checksum: sha256:%s\n' "$artifact" "$sha256"
}

compute_sha256 "debezium-connector-postgres" \
    "$MAVEN_REPO/io/debezium/debezium-connector-postgres/$VERSION/debezium-connector-postgres-$VERSION-plugin.tar.gz"

compute_sha256 "debezium-scripting" \
    "$MAVEN_REPO/io/debezium/debezium-scripting/$VERSION/debezium-scripting-$VERSION.tar.gz"

echo ""
echo "Update the version and checksum of each entry in artifacts.lock.yaml with the values above."
