#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/ichichuang/switch-env}"
INSTALLER_URL="${INSTALLER_URL:-${REPO_URL}/releases/latest/download/switch-env-installer.sh}"

AUTO_YES="${AUTO_YES:-0}"
QUIET="${QUIET:-0}"
FORCE="${FORCE:-0}"
SWITCH_ENV_DEBUG="${SWITCH_ENV_DEBUG:-0}"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: 需要 curl 以下载安装器。"
  exit 127
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

installer_path="$tmpdir/switch-env-installer.sh"

echo "Installing switch-env via bootstrap..."
echo "Source: $INSTALLER_URL"

if ! curl -fL --connect-timeout 15 --retry 2 --retry-delay 2 -o "$installer_path" "$INSTALLER_URL"; then
  echo "ERROR: 下载安装器失败。请检查网络后重试。"
  exit 1
fi

chmod +x "$installer_path"

AUTO_YES="$AUTO_YES" QUIET="$QUIET" FORCE="$FORCE" SWITCH_ENV_DEBUG="$SWITCH_ENV_DEBUG" bash "$installer_path"
