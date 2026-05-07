#!/usr/bin/env bash
# =============================================================================
# fetch-binaries.sh
# Downloads pre-compiled iOS ARM64 binaries from trusted upstream sources.
# Run ONCE before build-repo.sh to populate packages/ with actual binaries.
#
# Sources:
#   python3-ios : Procursus iphoneos-arm64-rootless pool (Python 3.9)
#   llama-cpp   : ggml-org/llama.cpp GitHub releases (macOS arm64)
#   nodejs-ios  : No pre-built iOS binary is available from Procursus or
#                 any other known trusted source. The nodejs-ios package
#                 is built as a meta/stub package. Users who need Node.js
#                 must install it from a compatible jailbreak repository.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGS_DIR="$REPO_ROOT/packages"
TMP_DIR="$(mktemp -d)"
trap "rm -rf $TMP_DIR" EXIT

# ── Helpers ──────────────────────────────────────────────────────────────────
download() { curl -fsSL --retry 3 -o "$2" "$1"; }
extract_deb_data() {
    # $1 = .deb path, $2 = destination directory
    # Extract to Linux tmpfs first to avoid NTFS utime errors on /mnt/,
    # then copy files to the real destination (no -a to skip timestamp preservation).
    local linux_tmp
    linux_tmp=$(mktemp -d /tmp/deb_extract_XXXXXX)
    dpkg-deb --extract "$1" "$linux_tmp"
    cp -r "$linux_tmp/." "$2/"
    rm -rf "$linux_tmp"
}

# ── 1. Node.js ───────────────────────────────────────────────────────────────
# Procursus does not publish a Node.js binary for iphoneos-arm64.
# The nodejs-ios package will be built as a stub (metadata only).
# No binary extraction is performed here.
echo "==> Skipping Node.js binary fetch (no iOS pre-built binary available)."
echo "    nodejs-ios will be built as a metadata-only stub package."
mkdir -p "$PKGS_DIR/nodejs"

# ── 2. Python 3.9 from Procursus ─────────────────────────────────────────────
# Procursus iphoneos-arm64-rootless pool (3000 = iOS 16+).
# python3.9_3.9.9-1 is a small wrapper; libpython3.9_3.9.9-1 has the runtime.
PYTHON_DEB_URL="https://apt.procurs.us/pool/main/iphoneos-arm64-rootless/3000/python3/libpython3.9_3.9.9-1_iphoneos-arm64.deb"
PYTHON_DEST="$PKGS_DIR/python3-ios"

echo "==> Fetching Python 3.9 from Procursus..."
mkdir -p "$PYTHON_DEST"
download "$PYTHON_DEB_URL" "$TMP_DIR/python3.deb"
extract_deb_data "$TMP_DIR/python3.deb" "$PYTHON_DEST"
echo "  Python 3.9 binaries extracted to $PYTHON_DEST"

# ── 3. llama.cpp (macOS arm64 Metal build) ───────────────────────────────────
# NOTE: llama.cpp repo moved to ggml-org/llama.cpp.
# The macOS arm64 build is the closest available pre-built binary to iOS arm64.
# Releases now ship as .tar.gz (no longer .zip).
# A native iOS jailbreak build would require cross-compilation with the iOS SDK.
LLAMA_VERSION="b9049"
LLAMA_RELEASE_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-bin-macos-arm64.tar.gz"
LLAMA_DEST="$PKGS_DIR/llama-cpp/var/jb/usr/local/bin"

echo "==> Fetching llama.cpp ${LLAMA_VERSION} (macOS arm64 Metal build)..."
mkdir -p "$LLAMA_DEST" "$TMP_DIR/llama"
download "$LLAMA_RELEASE_URL" "$TMP_DIR/llama.tar.gz"
tar -xzf "$TMP_DIR/llama.tar.gz" -C "$TMP_DIR/llama"

# Copy the key binaries
for bin in llama-server llama-cli llama-bench llama-run; do
    src=$(find "$TMP_DIR/llama" -name "$bin" -type f 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp "$src" "$LLAMA_DEST/$bin"
        echo "  Copied: $bin"
    else
        echo "  Warning: $bin not found in release archive"
    fi
done
echo "  llama.cpp binaries at $LLAMA_DEST"

echo ""
echo "==> Fetch complete. Now run: bash scripts/build-repo.sh"
