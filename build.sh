#!/bin/bash
#
# build.sh - package the source/ tree into an Unraid .txz and update the .plg MD5.
#
# Produces packages/pangolin_cli-<version>.txz where <version> is read from the
# .plg, then writes the package MD5 back into the .plg so the two stay in sync.
#
# Refuses to overwrite an existing .txz with different content (a same-version
# package with a new MD5 would break installs of the already-published release);
# pass --force to overwrite anyway.
#
set -euo pipefail

FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; fi

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="pangolin_cli"
PLG="${HERE}/${NAME}.plg"
SRC="${HERE}/source"
OUT="${HERE}/packages"

VERSION="$(grep -oP '<!ENTITY version\s+"\K[^"]+' "$PLG")"
TXZ="${OUT}/${NAME}-${VERSION}.txz"

mkdir -p "$OUT"

# Executable bits for shipped scripts. tar packs whatever mode the source
# tree has (an SMB/FAT working copy drops exec bits), and /update.php runs the
# webGui wrapper directly - packed as 0644 it makes the Connect button fail
# silently. So assert the modes here, right before packing.
chmod 0755 "${SRC}/etc/rc.d/rc.pangolin" \
           "${SRC}/usr/local/emhttp/plugins/${NAME}/scripts/rc.pangolin"

# Build the package. Slackware packages are xz tarballs rooted at /.
# Pack to a temp file first so an existing (possibly published) .txz is never
# clobbered before the overwrite guard below has compared it.
echo "Building ${TXZ} ..."
( cd "$SRC" && tar --owner=0 --group=0 -cJf "${TXZ}.tmp" . )

if [ -e "$TXZ" ] && [ "$FORCE" = "0" ]; then
  OLD_MD5="$(md5sum "$TXZ" | cut -d' ' -f1)"
  NEW_MD5="$(md5sum "${TXZ}.tmp" | cut -d' ' -f1)"
  if [ "$OLD_MD5" != "$NEW_MD5" ]; then
    rm -f "${TXZ}.tmp"
    echo "ERROR: ${TXZ} already exists with different content (${OLD_MD5})." >&2
    echo "Bump <!ENTITY version> in ${NAME}.plg (e.g. add an a/b suffix for a" >&2
    echo "same-day rebuild) or rerun with --force to overwrite it." >&2
    exit 1
  fi
fi
mv -f "${TXZ}.tmp" "$TXZ"

MD5="$(md5sum "$TXZ" | cut -d' ' -f1)"
echo "Package MD5: ${MD5}"

# Update the MD5 entity in the .plg.
sed -i -E "s#(<!ENTITY md5\s+\")[^\"]*(\">)#\1${MD5}\2#" "$PLG"
echo "Updated ${NAME}.plg with new MD5."
echo "Done."
