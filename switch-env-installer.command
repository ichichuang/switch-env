#!/usr/bin/env bash
set -u

REPO_URL="https://github.com/ichichuang/switch-env"
BOOTSTRAP_URL="${REPO_URL}/releases/latest/download/install.sh"
BOOTSTRAP_NAME="install.sh"

echo "======================================"
echo "      switch-env 一键安装程序"
echo "======================================"
echo ""
echo "仓库: ${REPO_URL}"
echo ""

DIR="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP_PATH="${DIR}/${BOOTSTRAP_NAME}"

download_bootstrap() {
  echo "正在下载安装入口脚本..."
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 15 --retry 2 --retry-delay 2 -o "${BOOTSTRAP_PATH}" "${BOOTSTRAP_URL}"
    return $?
  fi
  echo "错误: 未找到 curl，无法下载安装入口脚本。"
  return 127
}

if [[ ! -f "${BOOTSTRAP_PATH}" ]]; then
  if ! download_bootstrap; then
    code=$?
    echo ""
    echo "下载安装入口失败 (exit code: ${code})"
    echo "请检查网络/代理后重试，或手动下载："
    echo "  ${BOOTSTRAP_URL}"
    echo ""
    read -n 1 -s -r -p "按任意键退出..."
    echo ""
    exit "${code}"
  fi
else
  echo "检测到本地安装入口: ${BOOTSTRAP_PATH}"
fi

chmod +x "${BOOTSTRAP_PATH}" 2>/dev/null || true

echo ""
echo "开始执行安装..."
AUTO_YES=1 bash "${BOOTSTRAP_PATH}"
install_code=$?

echo ""
if [[ ${install_code} -eq 0 ]]; then
  echo "安装完成。"
  echo "请执行: source ~/.zshrc"
  echo "或重新打开终端（推荐）。"
else
  echo "安装失败 (exit code: ${install_code})"
  echo "请查看上方日志并重试。"
fi
echo ""
read -n 1 -s -r -p "按任意键退出..."
echo ""
exit "${install_code}"
