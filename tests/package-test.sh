#!/usr/bin/env bash
#
# package-test.sh - verify a built plugin .txz installs the way the plugin
# expects, catching packaging mistakes that are invisible in the source tree.
#
# In particular: /update.php runs the webGui wrapper script directly, so if it
# is packed without its execute bit the Connect/Apply buttons fail silently
# (this happens when building from a working copy that drops exec bits, e.g.
# an SMB share). tar records whatever mode the source tree had, so the built
# archive - not the source tree - is what has to be checked.
#
# Usage: tests/package-test.sh <path-to-txz> [path-to-plg]
#
# Exit status 0 = all checks passed, non-zero = the package is broken.
#
set -uo pipefail

TXZ="${1:?usage: package-test.sh <path-to-txz> [path-to-plg]}"
PLG="${2:-$(dirname "$0")/../pangolin_cli.plg}"

[ -f "$TXZ" ] || { echo "FAIL: package not found at $TXZ"; exit 1; }

fail=0
pass() { printf 'PASS: %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*"; fail=1; }

LISTING="$(tar -tvf "$TXZ" 2>/dev/null)"
[ -n "$LISTING" ] || { echo "FAIL: cannot list archive contents of $TXZ"; exit 1; }

# 1. Files the plugin cannot work without.
for req in \
  ./etc/rc.d/rc.pangolin \
  ./usr/local/emhttp/plugins/pangolin_cli/scripts/rc.pangolin \
  ./usr/local/emhttp/plugins/pangolin_cli/PangolinCLI.page
do
  if grep -q " ${req}$" <<<"$LISTING"; then
    pass "present: ${req}"
  else
    bad "missing from package: ${req}"
  fi
done

# 2. Every shipped script must be executable. Anything under etc/rc.d/ or a
#    scripts/ directory counts as a script; the webGui wrapper is the critical
#    one (see header), rc.pangolin the runner-up.
while IFS= read -r line; do
  mode="${line%% *}"
  path="${line##* }"
  case "$path" in
    */etc/rc.d/*|*/scripts/*) ;;
    *) continue ;;
  esac
  [ "${mode:0:1}" = "-" ] || continue   # regular files only
  if [ "${mode:3:1}" = "x" ]; then
    pass "executable: ${path} (${mode})"
  else
    bad "missing exec bit: ${path} (${mode}) - /update.php and rc.d need 0755"
  fi
done <<<"$LISTING"

# 3. Slackware packages must be owned by root (build.sh passes --owner/--group,
#    but guard against a manual tar invocation leaking share users like smb_user).
NONROOT="$(awk '$2 != "root/root"' <<<"$LISTING")"
if [ -z "$NONROOT" ]; then
  pass "all files owned by root/root"
else
  bad "files not owned by root/root:"
  printf '%s\n' "$NONROOT"
fi

# 4. The MD5 entity in the .plg must match the package, or installs abort at
#    the checksum. Only meaningful for the package the .plg currently points
#    at, so skip the check for older archives kept in packages/.
if [ -f "$PLG" ]; then
  PLGVER="$(grep -oP '<!ENTITY version\s+"\K[^"]+' "$PLG")"
  case "$(basename "$TXZ")" in
    *"${PLGVER}"*)
      WANT="$(grep -oP '<!ENTITY md5\s+"\K[^"]+' "$PLG")"
      HAVE="$(md5sum "$TXZ" | cut -d' ' -f1)"
      if [ "$WANT" = "$HAVE" ]; then
        pass "package MD5 matches the .plg (${HAVE})"
      else
        bad "MD5 mismatch: .plg has ${WANT}, package is ${HAVE} - rerun build.sh"
      fi
      ;;
    *)
      pass "MD5 check skipped (package version differs from .plg ${PLGVER})"
      ;;
  esac
else
  bad "plg not found at ${PLG} - cannot verify MD5"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAILED - do not ship this package."
  exit 1
fi
echo "RESULT: PASSED"
