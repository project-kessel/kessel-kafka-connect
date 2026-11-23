#!/usr/bin/env bash
# test-artifacts-lock.sh — Tests for the hermetic build inputs.
#
# 1. scripts/bump-debezium.sh, run against a local file:// Maven repository,
#    writes a lockfile with the requested version and the real checksums, and
#    leaves the existing lockfile untouched when a download fails.
# 2. The committed files agree with each other: the lockfile pins one Debezium
#    version, provides every file the Dockerfile reads, the Dockerfile makes
#    no network calls, and both Konflux PipelineRuns build hermetically with
#    the generic prefetch enabled.
#
# No network access or container runtime required.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
else
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

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

# lock_field LOCKFILE ARTIFACT_ID FIELD -> value of FIELD in that artifact's entry.
# Relies on the layout bump-debezium.sh writes: each entry starts with "  - "
# and ends with its checksum line.
lock_field() {
    awk -v id="$2" -v field="$3" '
        /^  - /                        { found = 0; val = "" }
        $1 == "artifact_id:" && $2 == id { found = 1 }
        $1 == field ":"                { val = $2 }
        $1 == "checksum:" && found     { print val; exit }
    ' "$1"
}

echo "=== bump-debezium.sh ==="

# Local Maven repository laid out like Maven Central.
REPO="$TMPDIR/maven"
V="9.9.9.Final"
mkdir -p "$REPO/io/debezium/debezium-connector-postgres/$V" "$REPO/io/debezium/debezium-scripting/$V"
echo "postgres plugin $V" > "$REPO/io/debezium/debezium-connector-postgres/$V/debezium-connector-postgres-$V-plugin.tar.gz"
echo "scripting $V" > "$REPO/io/debezium/debezium-scripting/$V/debezium-scripting-$V.tar.gz"
PG_SHA=$(sha256 "$REPO/io/debezium/debezium-connector-postgres/$V/debezium-connector-postgres-$V-plugin.tar.gz")
SC_SHA=$(sha256 "$REPO/io/debezium/debezium-scripting/$V/debezium-scripting-$V.tar.gz")

OUT="$TMPDIR/artifacts.lock.yaml"
cp "$ROOT/artifacts.lock.yaml" "$OUT"
MAVEN_REPO="file://$REPO" LOCKFILE="$OUT" bash "$ROOT/scripts/bump-debezium.sh" "$V" >/dev/null 2>&1
assert_eq "bump_exits_0" "0" "$?"
assert_eq "postgres_version" "$V" "$(lock_field "$OUT" debezium-connector-postgres version)"
assert_eq "scripting_version" "$V" "$(lock_field "$OUT" debezium-scripting version)"
assert_eq "postgres_checksum" "sha256:$PG_SHA" "$(lock_field "$OUT" debezium-connector-postgres checksum)"
assert_eq "scripting_checksum" "sha256:$SC_SHA" "$(lock_field "$OUT" debezium-scripting checksum)"
assert_eq "postgres_classifier" "plugin" "$(lock_field "$OUT" debezium-connector-postgres classifier)"

# A missing artifact must fail and keep the previous lockfile.
cp "$OUT" "$TMPDIR/before.yaml"
rm "$REPO/io/debezium/debezium-scripting/$V/debezium-scripting-$V.tar.gz"
MAVEN_REPO="file://$REPO" LOCKFILE="$OUT" bash "$ROOT/scripts/bump-debezium.sh" "$V" >/dev/null 2>&1
assert_eq "missing_artifact_exits_nonzero" "1" "$([ $? -ne 0 ] && echo 1 || echo 0)"
assert_eq "lockfile_unchanged_on_failure" "$(sha256 "$TMPDIR/before.yaml")" "$(sha256 "$OUT")"

echo ""
echo "=== committed build inputs ==="

LOCK="$ROOT/artifacts.lock.yaml"
PG_V=$(lock_field "$LOCK" debezium-connector-postgres version)
SC_V=$(lock_field "$LOCK" debezium-scripting version)
assert_eq "single_debezium_version" "$PG_V" "$SC_V"
for id in debezium-connector-postgres debezium-scripting; do
    if lock_field "$LOCK" "$id" checksum | grep -qE '^sha256:[0-9a-f]{64}$'; then
        assert_eq "${id}_checksum_is_sha256" "0" "0"
    else
        assert_eq "${id}_checksum_is_sha256" "sha256:<64 hex>" "$(lock_field "$LOCK" "$id" checksum)"
    fi
done

# Every prefetched file the Dockerfile reads must be produced by the lockfile.
WANTED=$(grep -oE '\$\{DEPS_DIR\}/[A-Za-z0-9._-]+' "$ROOT/Dockerfile" | sed 's#.*/##' | sort -u)
PROVIDED=$(awk '$1 == "filename:" { print $2 }' "$LOCK" | sort -u)
assert_eq "dockerfile_reads_lockfile_files" "$PROVIDED" "$WANTED"

if grep -qE '(^|[^A-Za-z])(curl|wget)([^A-Za-z]|$)' "$ROOT/Dockerfile"; then
    assert_eq "dockerfile_has_no_downloads" "none" "curl/wget found"
else
    assert_eq "dockerfile_has_no_downloads" "0" "0"
fi

for f in "$ROOT"/.tekton/*.yaml; do
    name=$(basename "$f" .yaml)
    hermetic=$(awk '/^  - name: hermetic$/ { getline; print $2 }' "$f" | tr -d '"')
    assert_eq "${name}_hermetic" "true" "$hermetic"
    if awk '/^  - name: prefetch-input$/ { getline; print }' "$f" | grep -q '"type": "generic"'; then
        assert_eq "${name}_prefetch_generic" "0" "0"
    else
        assert_eq "${name}_prefetch_generic" "generic" "missing"
    fi
done

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

[ "$FAIL" -eq 0 ]
