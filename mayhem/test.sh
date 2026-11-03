#!/usr/bin/env bash
#
# mayhem/test.sh — RUN filament's own gtest suites (built by mayhem/build.sh with normal flags) and
# report CTRF. Covers the material packer/builder (filamat), the material-definition parser (matp),
# the compiled-package chunk reader (filaflat) and the uberz archive reader.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SRC:=/mayhem}"
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

T="$SRC/out-test/libs"
SUITES=(
  "$T/filaflat/test_filaflat"
  "$T/filamat/test_filamat"
  "$T/filament-matp/test_matp"
  "$T/uberz/test_uberzlib"
)

passed=0; failed=0; skipped=0
for bin in "${SUITES[@]}"; do
  if [ ! -x "$bin" ]; then
    echo "missing test runner $bin (mayhem/build.sh should have built it)" >&2
    failed=$((failed + 1)); continue
  fi
  log="$(mktemp)"
  "$bin" >"$log" 2>&1
  rc=$?
  # gtest summary lines: "[  PASSED  ] N tests.", "[  FAILED  ] N tests, listed below:", "[  SKIPPED ] N tests, listed below:"
  p="$(sed -n 's/^\[  PASSED  \] \([0-9]*\) test.*/\1/p' "$log" | tail -1)"
  f="$(sed -n 's/^\[  FAILED  \] \([0-9]*\) test.*/\1/p' "$log" | tail -1)"
  s="$(sed -n 's/^\[  SKIPPED \] \([0-9]*\) test.*/\1/p' "$log" | tail -1)"
  ran="$(sed -n 's/^\[==========\] \([0-9]*\) tests\? from .* ran\..*/\1/p' "$log" | tail -1)"
  if [ -z "$ran" ] || [ "${ran:-0}" -eq 0 ]; then
    echo "no gtest summary from $bin (rc=$rc)" >&2; tail -5 "$log" >&2
    failed=$((failed + 1)); rm -f "$log"; continue
  fi
  [ "$rc" -eq 0 ] || [ -n "$f" ] || f=1
  echo "$(basename "$bin"): ran=$ran passed=${p:-0} failed=${f:-0} skipped=${s:-0}"
  passed=$((passed + ${p:-0})); failed=$((failed + ${f:-0})); skipped=$((skipped + ${s:-0}))
  rm -f "$log"
done

emit_ctrf "gtest" "$passed" "$failed" "$skipped"
