#!/usr/bin/env bash
# =============================================================================
# build-repo.sh
# Builds all .deb packages and regenerates apt repo metadata in docs/
# Requirements (Linux/macOS or WSL on Windows):
#   - dpkg-deb  (apt install dpkg  /  brew install dpkg)
#   - gzip, bzip2, xz
#   - apt-ftparchive  (apt install apt-utils)  — or run generate-packages.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
DEBS_DIR="$DOCS_DIR/debs"
PKGS_DIR="$REPO_ROOT/packages"

mkdir -p "$DEBS_DIR"

echo "==> Building .deb packages..."

for pkg_dir in "$PKGS_DIR"/*/; do
    pkg_name=$(basename "$pkg_dir")
    if [ ! -f "$pkg_dir/DEBIAN/control" ]; then continue; fi

    # Read version and arch from control file (strip \r for Windows line endings)
    version=$(grep "^Version:" "$pkg_dir/DEBIAN/control" | awk '{print $2}' | tr -d '\r')
    arch=$(grep "^Architecture:" "$pkg_dir/DEBIAN/control" | awk '{print $2}' | tr -d '\r')
    deb_file="$DEBS_DIR/${pkg_name}_${version}_${arch}.deb"

    # Build in Linux tmpfs to avoid NTFS chmod/utime failures
    linux_tmp=$(mktemp -d /tmp/build_XXXXXX)
    cp -r "$pkg_dir/." "$linux_tmp/"
    chmod -R 755 "$linux_tmp/DEBIAN/"

    echo "  Building: $pkg_name → $(basename "$deb_file")"
    tmp_deb="/tmp/${pkg_name}_${version}_${arch}.deb"
    dpkg-deb -Zgzip --build "$linux_tmp" "$tmp_deb"
    cp "$tmp_deb" "$deb_file"
    rm -rf "$linux_tmp" "$tmp_deb"
done

echo ""
echo "==> Generating Packages index..."
bash "$REPO_ROOT/scripts/generate-packages.sh"

echo ""
echo "==> Done. Commit docs/ to GitHub Pages to publish."
