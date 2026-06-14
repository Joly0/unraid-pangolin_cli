#!/usr/bin/env bash
#
# smoke-test.sh - verify a Pangolin CLI binary still satisfies the assumptions
# this plugin depends on, so an automated CLI bump can't silently ship a build
# that breaks rc.pangolin or the settings page.
#
# Usage: tests/smoke-test.sh <path-to-pangolin-binary>
#
# Exit status 0 = all required checks passed, non-zero = something the plugin
# relies on is gone (the CLI likely changed in a breaking way).
#
set -uo pipefail

BIN="${1:?usage: smoke-test.sh <path-to-pangolin-binary>}"
[ -f "$BIN" ] || { echo "FAIL: binary not found at $BIN"; exit 1; }
chmod +x "$BIN" 2>/dev/null || true

fail=0
pass() { printf 'PASS: %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*"; fail=1; }
warn() { printf 'WARN: %s\n' "$*"; }

# 1. The binary runs and reports a version (settings page calls `pangolin version`).
if VER="$("$BIN" version 2>&1 | head -n1)" && [ -n "$VER" ]; then
  pass "'pangolin version' runs -> ${VER}"
else
  bad "'pangolin version' did not run"
fi

# 2. Subcommands the plugin invokes: up (rc start), down (rc stop), status (page).
for sub in up down status; do
  if "$BIN" "$sub" --help >/dev/null 2>&1; then
    pass "subcommand '${sub}' exists"
  else
    bad "subcommand '${sub}' missing"
  fi
done

# 3. Flags rc.pangolin passes to `pangolin up`. These are REQUIRED - if any is
#    gone the service script breaks.
UPHELP="$("$BIN" up --help 2>&1 || true)"
for flag in --endpoint --id --secret --attach --override-dns; do
  if grep -q -- "$flag" <<<"$UPHELP"; then
    pass "'up' flag '${flag}' present"
  else
    bad "'up' flag '${flag}' missing"
  fi
done

# 4. Optional flags the plugin can pass via extra args / DNS handling. Missing
#    ones only warn (they are not used by default).
for flag in --upstream-dns --interface-name --mtu; do
  if grep -q -- "$flag" <<<"$UPHELP"; then
    pass "'up' flag '${flag}' present"
  else
    warn "'up' flag '${flag}' missing (optional)"
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAILED - the CLI may have changed in a way that breaks the plugin."
  exit 1
fi
echo "RESULT: PASSED"
