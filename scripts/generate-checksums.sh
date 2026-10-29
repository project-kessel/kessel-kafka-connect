#!/usr/bin/env bash
# generate-checksums.sh — Compute SHA-256 checksums for Debezium artifacts.
#
# Run this after updating DEBEZIUM_MAVEN_VERSION in the Dockerfile to obtain
# the new SHA-256 values for pinning.
#
# Usage:
#   ./scripts/generate-checksums.sh [VERSION]
#
# If VERSION is omitted, it is read from the Dockerfile.
#
# Prerequisites: curl, sha256sum, network access to repo1.maven.org

set -euo pipefail

MAVEN_REPO="https://repo1.maven.org/maven2"

if [ $# -ge 1 ]; then
    VERSION="$1"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOCKERFILE="$SCRIPT_DIR/../Dockerfile"
    if [ ! -f "$DOCKERFILE" ]; then
        echo "ERROR: Cannot find Dockerfile to read version. Pass VERSION as argument."
        exit 1
    fi
    VERSION=$(grep -oP 'DEBEZIUM_MAVEN_VERSION=\K[^\s\\]+' "$DOCKERFILE" | head -1)
    if [ -z "$VERSION" ]; then
        echo "ERROR: Cannot parse DEBEZIUM_MAVEN_VERSION from Dockerfile."
        exit 1
    fi
fi

echo "Computing SHA-256 checksums for Debezium $VERSION"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

compute_sha256() {
    local env_name="$1" url="$2"
    local file="$TMPDIR/$(basename "$url")"

    echo "Downloading: $(basename "$url")"
    if ! curl -fsSL -o "$file" "$url"; then
        echo "ERROR: Failed to download $url"
        return 1
    fi

    local sha256
    sha256=$(sha256sum "$file" | cut -d' ' -f1)
    printf '    %s=%s\n' "$env_name" "$sha256"
}

compute_sha256 "DEBEZIUM_CONNECTOR_POSTGRES_SHA256" \
    "$MAVEN_REPO/io/debezium/debezium-connector-postgres/$VERSION/debezium-connector-postgres-$VERSION-plugin.tar.gz"

compute_sha256 "DEBEZIUM_SCRIPTING_SHA256" \
    "$MAVEN_REPO/io/debezium/debezium-scripting/$VERSION/debezium-scripting-$VERSION.tar.gz"

echo ""
echo "Update the Dockerfile ENV block with the values above."
