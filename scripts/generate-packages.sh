#!/usr/bin/env bash
# =============================================================================
# generate-packages.sh
# Generates Packages, Packages.gz, Packages.bz2, and Packages.xz from the
# .deb files in docs/debs/. Also updates the Release file with checksums.
# Run this any time you add or update a .deb.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
DEBS_DIR="$DOCS_DIR/debs"

cd "$DOCS_DIR"

echo "  Scanning $DEBS_DIR for .deb files..."

# ── Build Packages file manually (no apt-ftparchive needed) ──────────────────
PACKAGES_FILE="$DOCS_DIR/Packages"
> "$PACKAGES_FILE"

for deb in "$DEBS_DIR"/*.deb; do
    [ -f "$deb" ] || continue
    echo "  Processing: $(basename "$deb")"

    # Extract control file from .deb
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    ar x "$deb" --output="$tmp_dir" 2>/dev/null || \
        (cd "$tmp_dir" && ar x "$deb")

    # control.tar.gz or control.tar.xz or control.tar.zst
    for ctrl_tar in "$tmp_dir"/control.tar.*; do
        [ -f "$ctrl_tar" ] && tar -xf "$ctrl_tar" -C "$tmp_dir" ./control 2>/dev/null && break
    done

    if [ -f "$tmp_dir/control" ]; then
        cat "$tmp_dir/control" >> "$PACKAGES_FILE"
    fi

    # Compute size and checksums
    size=$(wc -c < "$deb")
    md5=$(md5sum "$deb" | awk '{print $1}')
    sha1=$(sha1sum "$deb" | awk '{print $1}')
    sha256=$(sha256sum "$deb" | awk '{print $1}')
    rel_path="debs/$(basename "$deb")"

    cat >> "$PACKAGES_FILE" << EOF
Filename: $rel_path
Size: $size
MD5sum: $md5
SHA1: $sha1
SHA256: $sha256

EOF
    rm -rf "$tmp_dir"
    trap - EXIT
done

echo "  Compressing..."
rm -f "${PACKAGES_FILE}.gz" "${PACKAGES_FILE}.bz2" "${PACKAGES_FILE}.xz"
# Compress in Linux tmpfs to avoid NTFS utime errors, then copy to destination
TMP_PKG=$(mktemp /tmp/Packages_XXXXXX)
cp "$PACKAGES_FILE" "$TMP_PKG"
gzip  -9 -k "$TMP_PKG"
bzip2 -9 -k "$TMP_PKG"
xz    -9 -k "$TMP_PKG"
cp "${TMP_PKG}.gz"  "${PACKAGES_FILE}.gz"
cp "${TMP_PKG}.bz2" "${PACKAGES_FILE}.bz2"
cp "${TMP_PKG}.xz"  "${PACKAGES_FILE}.xz"
rm -f "$TMP_PKG" "${TMP_PKG}.gz" "${TMP_PKG}.bz2" "${TMP_PKG}.xz"

# ── Update Release with checksums ────────────────────────────────────────────
RELEASE_FILE="$DOCS_DIR/Release"
{
    grep -v "^MD5Sum:\|^ \|^SHA1:\|^SHA256:" "$RELEASE_FILE" || cat "$RELEASE_FILE"
    echo "MD5Sum:"
    for f in Packages Packages.gz Packages.bz2 Packages.xz; do
        [ -f "$DOCS_DIR/$f" ] && echo " $(md5sum "$DOCS_DIR/$f" | awk '{print $1}') $(wc -c < "$DOCS_DIR/$f") $f"
    done
    echo "SHA1:"
    for f in Packages Packages.gz Packages.bz2 Packages.xz; do
        [ -f "$DOCS_DIR/$f" ] && echo " $(sha1sum "$DOCS_DIR/$f" | awk '{print $1}') $(wc -c < "$DOCS_DIR/$f") $f"
    done
    echo "SHA256:"
    for f in Packages Packages.gz Packages.bz2 Packages.xz; do
        [ -f "$DOCS_DIR/$f" ] && echo " $(sha256sum "$DOCS_DIR/$f" | awk '{print $1}') $(wc -c < "$DOCS_DIR/$f") $f"
    done
} > "${RELEASE_FILE}.new"
mv "${RELEASE_FILE}.new" "$RELEASE_FILE"

echo "  Packages index generated."
echo "  To sign the Release file (recommended), run:"
echo "    gpg --clearsign -o docs/InRelease docs/Release"
echo "    gpg -abs -o docs/Release.gpg docs/Release"
