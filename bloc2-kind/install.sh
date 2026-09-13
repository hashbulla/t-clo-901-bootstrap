#!/usr/bin/env bash
# Installe kubectl v1.37.0 et kind v0.33.0 dans ~/.local/bin, sans sudo, avec vérification des sommes.
# Versions épinglées sur celle du nœud que kind crée (Kubernetes v1.37.0) pour éviter tout écart client/serveur.
# Linux x86_64 uniquement. macOS / Windows / ARM : https://kind.sigs.k8s.io/docs/user/quick-start/#installation
set -euo pipefail
KUBECTL_VERSION="v1.37.0"
KIND_VERSION="v0.33.0"
mkdir -p "$HOME/.local/bin"
cd "$HOME/.local/bin"
curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -fsSLo kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --quiet
curl -fsSLo kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64"
curl -fsSLo kind.sha256sum "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64.sha256sum"
sed 's/kind-linux-amd64/kind/' kind.sha256sum | sha256sum --check --quiet
rm -f kubectl.sha256 kind.sha256sum
chmod +x kubectl kind
echo "kubectl ${KUBECTL_VERSION} et kind ${KIND_VERSION} installés dans ~/.local/bin"
echo 'Si votre shell ne les trouve pas : export PATH="$HOME/.local/bin:$PATH"'
