#!/usr/bin/env bash
# Installe kubectl (dernière version stable) et kind v0.33.0 dans ~/.local/bin, sans sudo.
# Linux x86_64 uniquement. macOS / Windows : https://kind.sigs.k8s.io/docs/user/quick-start/#installation
set -euo pipefail
mkdir -p "$HOME/.local/bin"
cd "$HOME/.local/bin"
KV=$(curl -Ls https://dl.k8s.io/release/stable.txt)
curl -Lo kubectl "https://dl.k8s.io/release/${KV}/bin/linux/amd64/kubectl"
curl -Lo kind "https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64"
chmod +x kubectl kind
echo "kubectl ${KV} et kind v0.33.0 installés dans ~/.local/bin"
echo 'Ajoute à ton shell si besoin : export PATH="$HOME/.local/bin:$PATH"'
