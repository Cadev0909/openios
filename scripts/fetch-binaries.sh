#!/usr/bin/env bash
# =============================================================================
# fetch-binaries.sh
# Downloads pre-compiled iOS ARM64 binaries from trusted upstream sources
# (Procursus for Node/Python, llama.cpp GitHub releases for llama-server).
# Run ONCE before build-repo.sh to populate packages/ with actual binaries.
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
    local deb="$1" dest="$2"
    ar x "$deb" --output="$TMP_DIR/ar_out" 2>/dev/null || (mkdir -p "$TMP_DIR/ar_out" && cd "$TMP_DIR/ar_out" && ar x "$deb")
    for data_tar in "$TMP_DIR/ar_out"/data.tar.*; do
        [ -f "$data_tar" ] && tar -xf "$data_tar" -C "$dest" && break
    done
}

# ── 1. Node.js 20 from Procursus ─────────────────────────────────────────────
# Procursus hosts Debian-format packages for iphoneos-arm64.
# Check https://apt.procurs.us/pool/main/n/nodejs/ for latest version.
NODE_DEB_URL="https://apt.procurs.us/pool/main/n/nodejs/nodejs_20.12.2-1_iphoneos-arm64.deb"
NODE_DEST="$PKGS_DIR/nodejs"

echo "==> Fetching Node.js from Procursus..."
mkdir -p "$NODE_DEST"
download "$NODE_DEB_URL" "$TMP_DIR/nodejs.deb"
extract_deb_data "$TMP_DIR/nodejs.deb" "$NODE_DEST"
echo "  Node.js binaries extracted to $NODE_DEST"

# ── 2. Python 3.11 from Procursus ────────────────────────────────────────────
PYTHON_DEB_URL="https://apt.procurs.us/pool/main/p/python3.11/python3.11_3.11.8-1_iphoneos-arm64.deb"
PYTHON_DEST="$PKGS_DIR/python3-ios"

echo "==> Fetching Python 3.11 from Procursus..."
mkdir -p "$PYTHON_DEST"
download "$PYTHON_DEB_URL" "$TMP_DIR/python3.deb"
extract_deb_data "$TMP_DIR/python3.deb" "$PYTHON_DEST"
echo "  Python 3 binaries extracted to $PYTHON_DEST"

# ── 3. llama.cpp (latest release, iOS Metal build) ──────────────────────────
# llama.cpp releases ship macOS/Apple Silicon binaries which run on iOS too
# when compiled with the right flags. We pull the latest release tag.
LLAMA_VERSION="b3233"
LLAMA_RELEASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-bin-macos-arm64.zip"
LLAMA_DEST="$PKGS_DIR/llama-cpp/var/jb/usr/local/bin"

echo "==> Fetching llama.cpp ${LLAMA_VERSION} (arm64 Metal build)..."
mkdir -p "$LLAMA_DEST" "$TMP_DIR/llama"
download "$LLAMA_RELEASE_URL" "$TMP_DIR/llama.zip"
unzip -q "$TMP_DIR/llama.zip" -d "$TMP_DIR/llama"

# Copy the key binaries
for bin in llama-server llama-cli llama-bench llama-run; do
    src=$(find "$TMP_DIR/llama" -name "$bin" -type f 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        install -m 755 "$src" "$LLAMA_DEST/$bin"
        echo "  Copied: $bin"
    fi
done
echo "  llama.cpp binaries at $LLAMA_DEST"

echo ""
echo "==> All binaries fetched. Now run: bash scripts/build-repo.sh"
