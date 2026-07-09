#!/bin/bash
#
# build.sh - package the source/ tree into an Unraid .txz and update the .plg MD5.
#
# Produces packages/pangolin_cli-<version>.txz where <version> is read from the
# .plg, then writes the package MD5 back into the .plg so the two stay in sync.
#
set -euo pipefail

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
echo "Building ${TXZ} ..."
( cd "$SRC" && tar --owner=0 --group=0 -cJf "$TXZ" . )

MD5="$(md5sum "$TXZ" | cut -d' ' -f1)"
echo "Package MD5: ${MD5}"

# Update the MD5 entity in the .plg.
sed -i -E "s#(<!ENTITY md5\s+\")[^\"]*(\">)#\1${MD5}\2#" "$PLG"
echo "Updated ${NAME}.plg with new MD5."
echo "Done."
