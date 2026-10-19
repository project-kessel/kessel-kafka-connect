#!/usr/bin/env bash
# test-verify-checksum.sh — Tests for the SHA-256 verification logic used in
# the Dockerfile to validate Debezium plugin downloads.
#
# These tests exercise the same "echo <hash> <file> | sha256sum -c -" pattern
# used in the Dockerfile RUN instruction. No network access required.

set -uo pipefail

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

# Wrapper: run a sha256sum verification and capture exit code without
# triggering pipefail at the top level.
verify() {
    local hash="$1" file="$2"
    ( echo "${hash}  ${file}" | sha256sum -c - ) > /dev/null 2>&1
    return $?
}

# --- Create test fixtures ---
echo "simulated debezium connector plugin content" > "$TMPDIR/connector.tar.gz"
CORRECT_SHA256=$(sha256sum "$TMPDIR/connector.tar.gz" | cut -d' ' -f1)
WRONG_SHA256="0000000000000000000000000000000000000000000000000000000000000000"

echo "=== Test Suite: SHA-256 Verification (Dockerfile pattern) ==="

# Test 1: Correct checksum passes with sha256sum -c
echo ""
echo "Test 1: Correct SHA-256 checksum passes"
if verify "$CORRECT_SHA256" "$TMPDIR/connector.tar.gz"; then
    rc=0
else
    rc=1
fi
assert_eq "correct_checksum_exits_0" "0" "$rc"

# Test 2: Wrong checksum fails with sha256sum -c
echo ""
echo "Test 2: Wrong SHA-256 checksum fails"
if verify "$WRONG_SHA256" "$TMPDIR/connector.tar.gz"; then
    rc=0
else
    rc=1
fi
assert_eq "wrong_checksum_exits_nonzero" "1" "$rc"

# Test 3: Tampered file is detected
echo ""
echo "Test 3: Tampered file content is detected"
echo "tampered content" > "$TMPDIR/tampered.tar.gz"
if verify "$CORRECT_SHA256" "$TMPDIR/tampered.tar.gz"; then
    rc=0
else
    rc=1
fi
assert_eq "tampered_file_exits_nonzero" "1" "$rc"

# Test 4: SHA-256 is exactly 64 hex characters
echo ""
echo "Test 4: SHA-256 format is 64 hex characters"
if echo "$CORRECT_SHA256" | grep -qE '^[0-9a-f]{64}$'; then
    assert_eq "sha256_format_valid" "0" "0"
else
    assert_eq "sha256_format_valid" "0" "1"
fi

# Test 5: Two different files produce different hashes
echo ""
echo "Test 5: Different files produce different hashes"
echo "different plugin content" > "$TMPDIR/other.tar.gz"
OTHER_SHA256=$(sha256sum "$TMPDIR/other.tar.gz" | cut -d' ' -f1)
if [ "$CORRECT_SHA256" != "$OTHER_SHA256" ]; then
    assert_eq "different_files_different_hashes" "0" "0"
else
    assert_eq "different_files_different_hashes" "0" "1"
fi

# Test 6: Tarball extraction after verification
echo ""
echo "Test 6: Extraction succeeds after verification"
mkdir -p "$TMPDIR/plugin-src"
echo "plugin.jar" > "$TMPDIR/plugin-src/debezium-connector.jar"
echo "config" > "$TMPDIR/plugin-src/connector.properties"
tar -czf "$TMPDIR/valid-plugin.tar.gz" -C "$TMPDIR/plugin-src" .
PLUGIN_SHA256=$(sha256sum "$TMPDIR/valid-plugin.tar.gz" | cut -d' ' -f1)

EXTRACT_DIR="$TMPDIR/extracted"
mkdir -p "$EXTRACT_DIR"
if verify "$PLUGIN_SHA256" "$TMPDIR/valid-plugin.tar.gz"; then
    tar -xzf "$TMPDIR/valid-plugin.tar.gz" -C "$EXTRACT_DIR"
    rc=0
else
    rc=1
fi
assert_eq "verify_then_extract_succeeds" "0" "$rc"
assert_eq "extracted_jar_exists" "plugin.jar" "$(cat "$EXTRACT_DIR/debezium-connector.jar")"
assert_eq "extracted_config_exists" "config" "$(cat "$EXTRACT_DIR/connector.properties")"

# Test 7: Failed verification blocks extraction (&&-chaining)
echo ""
echo "Test 7: Failed verification blocks extraction"
BLOCK_DIR="$TMPDIR/should-not-extract"
mkdir -p "$BLOCK_DIR"
if verify "$WRONG_SHA256" "$TMPDIR/valid-plugin.tar.gz"; then
    tar -xzf "$TMPDIR/valid-plugin.tar.gz" -C "$BLOCK_DIR"
fi
FILE_COUNT=$(find "$BLOCK_DIR" -type f 2>/dev/null | wc -l)
assert_eq "no_files_extracted" "0" "$FILE_COUNT"

# Test 8: ENV-style pinning works (simulate Dockerfile ENV lookup)
echo ""
echo "Test 8: ENV-style variable pinning"
DEBEZIUM_CONNECTOR_POSTGRES_SHA256="$PLUGIN_SHA256"
if verify "$DEBEZIUM_CONNECTOR_POSTGRES_SHA256" "$TMPDIR/valid-plugin.tar.gz"; then
    rc=0
else
    rc=1
fi
assert_eq "env_var_pinning_works" "0" "$rc"

# --- Summary ---
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
