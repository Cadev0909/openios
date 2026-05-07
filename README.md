# iOS LLM Repo

A Sileo/Zebra/Cydia-compatible apt repository for **rootless jailbroken iOS** (Dopamine, Fugu15, Palera1n).

Hosts Node.js, Python 3, llama.cpp (local LLM inference with Metal GPU), and a web UI for both local and cloud models.

---

## Packages

| Package | Version | Description |
|---|---|---|
| `nodejs-ios` | 20.12.2 | Node.js v20 LTS + npm + npx |
| `python3-ios` | 3.11.8 | Python 3.11 + pip3 |
| `llama-cpp-ios` | b3233 | llama-server, llama-cli, llama-bench (Metal GPU) |
| `cloud-ui` | 1.0.0 | Web chat UI — local + OpenAI/Claude/Gemini |

---

## Setup: Building the Repo (from Windows/Mac/Linux)

### Prerequisites

You need WSL, macOS, or a Linux machine with:
```sh
# Debian/Ubuntu
sudo apt install dpkg curl gzip bzip2 xz-utils binutils

# macOS (Homebrew)
brew install dpkg
```

### Step 1 — Fetch upstream binaries

```sh
bash scripts/fetch-binaries.sh
```

This downloads:
- Node.js and Python from the [Procursus](https://apt.procurs.us) apt mirror
- llama.cpp arm64 Metal binaries from the official GitHub releases

### Step 2 — Build .deb packages

```sh
bash scripts/build-repo.sh
```

Output: all `.deb` files land in `docs/debs/` and `docs/Packages` is regenerated.

### Step 3 — (Optional) Sign the Release

GPG signing lets users verify packages haven't been tampered with:

```sh
# Generate a key if you don't have one
gpg --gen-key

# Sign
gpg --clearsign -o docs/InRelease docs/Release
gpg -abs -o docs/Release.gpg docs/Release

# Export public key for users to import on device
gpg --armor --export YOUR_EMAIL > docs/public.key
```

On device (via SSH):
```sh
wget -O /var/jb/etc/apt/trusted.gpg.d/ios-llm-repo.asc https://YOUR_USERNAME.github.io/YOUR_REPO/public.key
```

### Step 4 — Publish to GitHub Pages

1. Push to GitHub
2. Go to **Settings → Pages → Source: Deploy from branch → main → /docs**
3. Your repo URL will be: `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/`

---

## Adding the Repo on Device

Open **Sileo** or **Zebra** → Sources → Add Source:
```
https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/
```

---

## Using llama.cpp on Device

After installing `llama-cpp-ios` via Sileo:

```sh
# SSH into device (via NewTerm2 or SSH)
# Download a small model (e.g. Phi-3 Mini 4-bit ~2GB)
wget -O /var/jb/var/llama-models/active.gguf \
  https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf

# Start the inference server (Metal GPU accelerated)
/var/jb/usr/local/bin/llama-server \
  --model /var/jb/var/llama-models/active.gguf \
  --port 8080 \
  --n-gpu-layers 99 \
  --ctx-size 4096
```

Open Safari → `http://127.0.0.1:8080` for the built-in llama.cpp web UI, or `http://127.0.0.1:3000` for the multi-backend Cloud UI.

---

## Cloud Models (via Cloud UI)

After installing `cloud-ui`, open `http://127.0.0.1:3000` in Safari, tap the gear icon, and enter:
- **OpenAI key** for GPT-4o / GPT-4o-mini
- **Anthropic key** for Claude 3 Haiku / Sonnet
- **Gemini key** for Gemini 1.5 Flash / Pro

Keys are stored locally in `/var/jb/var/cloud-ui-config.json` on device.

---

## Adding More Packages

1. Create a new directory under `packages/YOUR_PACKAGE/DEBIAN/`
2. Add a `control` file (see existing packages for the format)
3. Add a `postinst` script if needed
4. Place binaries under `packages/YOUR_PACKAGE/var/jb/...` (matching the rootless install path)
5. Re-run `bash scripts/build-repo.sh`

---

## Recommended Models for iOS

| Model | Size | Notes |
|---|---|---|
| Phi-3 Mini Q4_K_M | ~2.2 GB | Fast, great for iPads with 6–8 GB RAM |
| Mistral 7B Q4_K_M | ~4.1 GB | Good general purpose (iPad Pro 11/12") |
| Llama 3.2 3B Q5_K_M | ~2.1 GB | Meta's latest small model |
| Gemma 2 2B Q8 | ~2.7 GB | Google, excellent quality for size |

Browse GGUF models at [HuggingFace](https://huggingface.co/models?library=gguf).

---

## Credits

- [Procursus](https://github.com/ProcursusTeam/Procursus) — iOS arm64 bootstrap packages
- [llama.cpp](https://github.com/ggerganov/llama.cpp) — LLM inference engine
- [Dopamine](https://github.com/opa334/Dopamine) — rootless jailbreak
