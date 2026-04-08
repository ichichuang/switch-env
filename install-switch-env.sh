#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  install-switch-env.sh — switch-env 一键安装 / 卸载程序         ║
# ║                                                                  ║
# ║  用法:                                                           ║
# ║    ./install-switch-env.sh            # 安装                     ║
# ║    ./install-switch-env.sh --uninstall # 卸载                    ║
# ║                                                                  ║
# ║  支持两种分发模式:                                               ║
# ║    1. 伴随文件模式: 与 switch-env, switch-env.plugin.zsh 同目录  ║
# ║    2. 内嵌模式: 由 build-installer.sh 打包为单文件 (自解压)      ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# 非交互/静默控制
AUTO_YES="${AUTO_YES:-0}"   # 1=自动确认
QUIET="${QUIET:-0}"         # 1=减少输出

# ─── 全局配置 ─────────────────────────────────────────────────────
readonly VENV_DIR="$HOME/.venv-tools"
readonly BIN_DIR="$HOME/bin"
readonly ZSHRC="$HOME/.zshrc"
readonly MIN_PY_MAJOR=3
readonly MIN_PY_MINOR=10
readonly SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PAYLOAD_MARKER='##__SWITCH_ENV_PAYLOAD_BELOW__##'
readonly SWITCH_ENV_SOURCE_URL="${SWITCH_ENV_SOURCE_URL:-https://github.com/ichichuang/switch-env}"

# ─── 颜色与符号 ──────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

info()    { [[ "$QUIET" == "1" ]] || printf "${BLUE}[·]${NC} %s\n" "$*"; }
ok()      { [[ "$QUIET" == "1" ]] || printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn()    { [[ "$QUIET" == "1" ]] || printf "${YELLOW}[!]${NC} %s\n" "$*"; }
fail()    { printf "${RED}[✗]${NC} %s\n" "$*"; }
fatal()   { fail "$*"; exit 1; }

# ─── 工具函数 ─────────────────────────────────────────────────────

# 比较 Python 版本: py_version_ge "3.12" "3.10" → true
py_version_ge() {
  local IFS='.'
  local -a a=($1) b=($2)
  (( a[0] > b[0] )) && return 0
  (( a[0] < b[0] )) && return 1
  (( a[1] >= b[1] )) && return 0
  return 1
}

# 跨平台 sed -i (macOS vs Linux)
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# ─── 查找可用 Python >= 3.10 ─────────────────────────────────────
find_suitable_python() {
  local candidates=()

  # 1) pyenv 管理的版本 (优先)
  if command -v pyenv &>/dev/null; then
    local pyenv_root
    pyenv_root="$(pyenv root 2>/dev/null)" || true
    if [[ -d "$pyenv_root/versions" ]]; then
      for d in "$pyenv_root"/versions/3.*/bin/python3; do
        [[ -x "$d" ]] && candidates+=("$d")
      done
    fi
  fi

  # 2) Homebrew Python
  for p in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    [[ -x "$p" ]] && candidates+=("$p")
  done

  # 3) conda base Python
  local conda_prefix="${CONDA_PREFIX:-}"
  [[ -z "$conda_prefix" && -d /opt/homebrew/Caskroom/miniconda/base ]] && conda_prefix="/opt/homebrew/Caskroom/miniconda/base"
  [[ -n "$conda_prefix" && -x "$conda_prefix/bin/python3" ]] && candidates+=("$conda_prefix/bin/python3")

  # 4) 系统 Python (最低优先)
  [[ -x /usr/bin/python3 ]] && candidates+=("/usr/bin/python3")

  for py in "${candidates[@]}"; do
    local ver
    ver="$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)" || continue
    if py_version_ge "$ver" "${MIN_PY_MAJOR}.${MIN_PY_MINOR}"; then
      echo "$py"
      return 0
    fi
  done
  return 1
}

# ─── 获取载荷文件 ────────────────────────────────────────────────
# 返回值: 设置 PAYLOAD_DIR (临时目录或脚本所在目录)
#   PAYLOAD_IS_TEMP=1 表示需要清理

PAYLOAD_DIR=""
PAYLOAD_IS_TEMP=0

extract_payloads() {
  # 尝试从自身解压内嵌载荷
  if grep -q "$PAYLOAD_MARKER" "$SELF" 2>/dev/null; then
    PAYLOAD_DIR="$(mktemp -d)"
    PAYLOAD_IS_TEMP=1

    local in_file="" filename=""
    local collecting=0

    while IFS= read -r line; do
      if [[ "$line" == "@@FILE:"* ]]; then
        # 结束上一个文件
        [[ -n "$in_file" ]] && base64 -d < "$in_file.b64" > "$PAYLOAD_DIR/$filename" && rm -f "$in_file.b64"
        filename="${line#@@FILE:}"
        in_file="$PAYLOAD_DIR/$filename"
        collecting=1
        : > "$in_file.b64"
        continue
      fi
      if [[ "$line" == "@@END@@" ]]; then
        [[ -n "$in_file" ]] && base64 -d < "$in_file.b64" > "$PAYLOAD_DIR/$filename" && rm -f "$in_file.b64"
        break
      fi
      [[ $collecting -eq 1 ]] && echo "$line" >> "$in_file.b64"
    done < <(sed -n "/${PAYLOAD_MARKER}/,\$p" "$SELF" | tail -n +2)

    # 验证
    if [[ -f "$PAYLOAD_DIR/switch-env" && -f "$PAYLOAD_DIR/switch-env.plugin.zsh" ]]; then
      ok "从安装包中解压载荷文件"
      return 0
    else
      warn "内嵌载荷解压不完整，尝试伴随文件模式"
      rm -rf "$PAYLOAD_DIR"
      PAYLOAD_IS_TEMP=0
    fi
  fi

  # 伴随文件模式
  if [[ -f "$SCRIPT_DIR/switch-env" && -f "$SCRIPT_DIR/switch-env.plugin.zsh" ]]; then
    PAYLOAD_DIR="$SCRIPT_DIR"
    PAYLOAD_IS_TEMP=0
    ok "在同目录找到伴随文件"
    return 0
  fi

  fatal "未找到安装所需文件。请确保 switch-env 和 switch-env.plugin.zsh 与安装脚本在同一目录，或使用 build-installer.sh 打包的单文件版本。"
}

cleanup_payload() {
  [[ $PAYLOAD_IS_TEMP -eq 1 && -n "$PAYLOAD_DIR" ]] && rm -rf "$PAYLOAD_DIR"
}

# ─── 安装流程 ─────────────────────────────────────────────────────
do_install() {
  echo ""
  printf "${BOLD}╔═══════════════════════════════════════════════╗${NC}\n"
  printf "${BOLD}║  ${CYAN}switch-env${NC}${BOLD} 一键安装程序                     ║${NC}\n"
  printf "${BOLD}║  统一多运行时环境管理工具                     ║${NC}\n"
  printf "${BOLD}╚═══════════════════════════════════════════════╝${NC}\n"
  echo ""
  echo "Installing switch-env..."
  echo "Source: $SWITCH_ENV_SOURCE_URL"
  echo ""
  echo "本程序将执行以下操作："
  echo "  1. 检查系统环境与前置依赖"
  echo "  2. 创建隔离 Python 运行时 (~/.venv-tools/)"
  echo "  3. 安装 switch-env 到 ~/bin/"
  echo "  4. 配置 ~/.zshrc 自动加载"
  echo "  5. 验证安装"
  echo ""

  if [[ "$AUTO_YES" == "1" ]]; then
    confirm="y"
  else
    read -rp "是否继续？ [Y/n] " confirm
  fi
  case "$confirm" in
    [Nn]*) echo "已取消。"; exit 0 ;;
  esac
  echo ""

  # ── 阶段 1: 环境检测 ──────────────────────────────────────────
  printf "${BOLD}── 阶段 1/5: 环境检测 ──${NC}\n"

  local os_type arch
  os_type="$(uname -s)"
  arch="$(uname -m)"
  ok "系统: ${os_type} ${arch}"

  # Shell
  if [[ "$SHELL" == */zsh ]] || [[ -n "${ZSH_VERSION:-}" ]]; then
    ok "默认 Shell: zsh"
  else
    warn "默认 Shell 非 zsh ($SHELL)，插件自动加载需要 zsh"
  fi

  # Python
  local python_bin python_ver
  python_bin="$(find_suitable_python)" || fatal "未找到 Python >= ${MIN_PY_MAJOR}.${MIN_PY_MINOR}。请先安装:\n    brew install python@3.12  或  brew install pyenv && pyenv install 3.12"
  python_ver="$("$python_bin" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")"
  ok "Python: ${python_ver} (${python_bin})"

  # 版本管理器 (可选)
  local has_pyenv=0 has_conda=0 has_nvm=0

  if command -v pyenv &>/dev/null; then
    ok "pyenv: $(pyenv --version 2>&1 | awk '{print $2}')"
    has_pyenv=1
  else
    warn "pyenv 未安装 (可选，用于 Python 版本管理)"
  fi

  if command -v conda &>/dev/null; then
    ok "conda: $(conda --version 2>&1 | awk '{print $2}')"
    has_conda=1
  else
    warn "conda 未安装 (可选，用于 Conda 环境管理)"
  fi

  if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    ok "nvm: 已安装"
    has_nvm=1
  else
    warn "nvm 未安装 (可选，用于 Node.js 版本管理)"
  fi

  if (( has_pyenv == 0 && has_conda == 0 && has_nvm == 0 )); then
    warn "未检测到任何版本管理器 (pyenv/conda/nvm)，switch-env 功能将受限"
  fi

  echo ""

  # ── 阶段 2: 载荷文件 ──────────────────────────────────────────
  printf "${BOLD}── 阶段 2/5: 准备文件 ──${NC}\n"
  extract_payloads
  trap cleanup_payload EXIT
  echo ""

  # ── 阶段 3: 创建隔离运行时 ────────────────────────────────────
  printf "${BOLD}── 阶段 3/5: 创建隔离运行时 ──${NC}\n"

  if [[ -d "$VENV_DIR" ]]; then
    # 检查现有 venv 是否可用
    if "$VENV_DIR/bin/python" -c "import rich" &>/dev/null; then
      ok "$VENV_DIR 已存在且可用，跳过创建"
    else
      warn "$VENV_DIR 已存在但不完整，重建中..."
      rm -rf "$VENV_DIR"
      info "创建 $VENV_DIR ..."
      "$python_bin" -m venv "$VENV_DIR" || fatal "创建 venv 失败"
      info "安装依赖 (rich) ..."
      "$VENV_DIR/bin/pip" install --quiet --disable-pip-version-check rich || fatal "安装 rich 失败"
      ok "$VENV_DIR 创建完成"
    fi
  else
    info "创建 $VENV_DIR ..."
    "$python_bin" -m venv "$VENV_DIR" || fatal "创建 venv 失败"
    info "安装依赖 (rich) ..."
    "$VENV_DIR/bin/pip" install --quiet --disable-pip-version-check rich || fatal "安装 rich 失败"
    ok "$VENV_DIR 创建完成"
  fi

  echo ""

  # ── 阶段 4: 安装文件 ──────────────────────────────────────────
  printf "${BOLD}── 阶段 4/5: 安装文件 ──${NC}\n"

  mkdir -p "$BIN_DIR"

  # switch-env 主程序
  cp "$PAYLOAD_DIR/switch-env" "$BIN_DIR/switch-env"
  # 动态修正 shebang 为当前用户的 venv 路径
  sedi "1s|^#!.*|#!${VENV_DIR}/bin/python|" "$BIN_DIR/switch-env"
  chmod +x "$BIN_DIR/switch-env"
  ok "switch-env → $BIN_DIR/switch-env"

  # zsh 插件
  cp "$PAYLOAD_DIR/switch-env.plugin.zsh" "$BIN_DIR/switch-env.plugin.zsh"
  ok "switch-env.plugin.zsh → $BIN_DIR/switch-env.plugin.zsh"

  # 文档 (可选)
  if [[ -f "$PAYLOAD_DIR/switch-env.md" ]]; then
    cp "$PAYLOAD_DIR/switch-env.md" "$BIN_DIR/switch-env.md"
    ok "switch-env.md → $BIN_DIR/switch-env.md"
  fi

  echo ""

  # ── 阶段 5: 配置 Shell ────────────────────────────────────────
  printf "${BOLD}── 阶段 5/5: 配置 Shell ──${NC}\n"

  local zshrc_changed=0

  # 确保 zshrc 存在
  [[ -f "$ZSHRC" ]] || touch "$ZSHRC"

  # 备份
  local backup="${ZSHRC}.pre-switch-env.$(date +%Y%m%d%H%M%S)"
  cp "$ZSHRC" "$backup"
  ok "备份 ~/.zshrc → $(basename "$backup")"

  # (a) 确保 ~/bin 在 PATH 中
  if ! grep -qE 'PATH.*\$HOME/bin|\~/bin' "$ZSHRC" 2>/dev/null; then
    {
      echo ''
      echo '# [switch-env] Ensure ~/bin is in PATH'
      echo 'export PATH="$HOME/bin:$PATH"'
    } >> "$ZSHRC"
    ok "已添加 ~/bin 到 PATH"
    zshrc_changed=1
  else
    ok "~/bin 已在 PATH 中"
  fi

  # (b) 注释旧插件 (仅处理未注释的行)
  if grep -qE '^[^#]*source.*switch-node\.plugin\.zsh' "$ZSHRC" 2>/dev/null; then
    sedi 's|^\([^#]*source.*switch-node\.plugin\.zsh.*\)|# \1  # replaced by switch-env|' "$ZSHRC"
    ok "已注释旧 switch-node 插件"
    zshrc_changed=1
  fi
  if grep -qE '^[^#]*source.*switch-py\.plugin\.zsh' "$ZSHRC" 2>/dev/null; then
    sedi 's|^\([^#]*source.*switch-py\.plugin\.zsh.*\)|# \1  # replaced by switch-env|' "$ZSHRC"
    ok "已注释旧 switch-py 插件"
    zshrc_changed=1
  fi

  # (c) 添加 switch-env 插件
  if ! grep -q 'switch-env\.plugin\.zsh' "$ZSHRC" 2>/dev/null; then
    {
      echo ''
      echo '# [switch-env] Unified runtime environment manager'
      echo 'source "$HOME/bin/switch-env.plugin.zsh"'
    } >> "$ZSHRC"
    ok "已添加 switch-env 插件到 ~/.zshrc"
    zshrc_changed=1
  else
    ok "switch-env 插件已在 ~/.zshrc 中"
  fi

  if [[ $zshrc_changed -eq 0 ]]; then
    ok "~/.zshrc 无需修改"
    rm -f "$backup"  # 不需要备份
  fi

  echo ""

  # ── 验证 ──────────────────────────────────────────────────────
  printf "${BOLD}── 验证安装 ──${NC}\n"
  export PATH="$BIN_DIR:$PATH"
  echo ""
  "$BIN_DIR/switch-env" doctor 2>&1 || true
  echo ""

  # ── 完成 ──────────────────────────────────────────────────────
  printf "${BOLD}════════════════════════════════════════════════${NC}\n"
  printf "${GREEN}${BOLD}  ✓ 安装完成！${NC}\n"
  echo ""
  echo "  请执行以下命令以立即生效："
  printf "    ${BOLD}source ~/.zshrc${NC}\n"
  echo ""
  echo "  或重新打开终端（推荐）"
  echo ""
  echo "  提示：如果是通过 curl 安装，请执行："
  printf "    ${BOLD}exec zsh${NC}\n"
  echo ""
  if ! command -v switch-env >/dev/null 2>&1; then
    warn "当前 shell 尚未加载 ~/bin，请执行: source ~/.zshrc 或重新打开终端"
  else
    ok "当前 shell 已可直接使用 switch-env"
  fi
  echo ""
  echo "  快速上手:"
  echo "    switch-env doctor     # 环境诊断"
  echo "    switch-env status     # 当前环境状态"
  echo "    switch-env use        # 切换到项目环境"
  echo "    se use                # 简写"
  echo "    switch-env --help     # 查看帮助"
  printf "${BOLD}════════════════════════════════════════════════${NC}\n"
  echo ""
}

# ─── 打包流程 ─────────────────────────────────────────────────────
do_build() {
  local out="${1:-switch-env-installer.sh}"
  info "构建单文件安装包: $out"

  [[ -f "$SCRIPT_DIR/switch-env" ]] || fatal "缺少: $SCRIPT_DIR/switch-env"
  [[ -f "$SCRIPT_DIR/switch-env.plugin.zsh" ]] || fatal "缺少: $SCRIPT_DIR/switch-env.plugin.zsh"

  awk -v marker="$PAYLOAD_MARKER" '
    $0==marker {exit}
    {print}
  ' "$SELF" > "$out"

  {
    echo ""
    echo "$PAYLOAD_MARKER"
    echo "@@FILE:switch-env"
    base64 < "$SCRIPT_DIR/switch-env"
    echo "@@FILE:switch-env.plugin.zsh"
    base64 < "$SCRIPT_DIR/switch-env.plugin.zsh"
    if [[ -f "$SCRIPT_DIR/switch-env.md" ]]; then
      echo "@@FILE:switch-env.md"
      base64 < "$SCRIPT_DIR/switch-env.md"
    fi
    echo "@@END@@"
  } >> "$out"

  chmod +x "$out"
  ok "构建完成: $out"
  echo "分发命令示例:"
  echo "  curl -fsSL <YOUR_URL>/$(basename "$out") | AUTO_YES=1 bash"
}

# ─── 卸载流程 ─────────────────────────────────────────────────────
do_uninstall() {
  echo ""
  printf "${BOLD}╔═══════════════════════════════════════════════╗${NC}\n"
  printf "${BOLD}║  ${RED}switch-env${NC}${BOLD} 卸载程序                          ║${NC}\n"
  printf "${BOLD}╚═══════════════════════════════════════════════╝${NC}\n"
  echo ""
  echo "将移除以下内容："
  echo "  • $BIN_DIR/switch-env"
  echo "  • $BIN_DIR/switch-env.plugin.zsh"
  echo "  • $BIN_DIR/switch-env.md"
  echo "  • $VENV_DIR/ (隔离运行时)"
  echo "  • ~/.zshrc 中的 switch-env 配置行"
  echo ""

  if [[ "$AUTO_YES" == "1" ]]; then
    confirm="y"
  else
    read -rp "确认卸载？ [y/N] " confirm
  fi
  case "$confirm" in
    [Yy]*) ;;
    *) echo "已取消。"; exit 0 ;;
  esac
  echo ""

  # 删除文件
  for f in "$BIN_DIR/switch-env" "$BIN_DIR/switch-env.plugin.zsh" "$BIN_DIR/switch-env.md"; do
    if [[ -f "$f" ]]; then
      rm -f "$f"
      ok "已删除 $f"
    fi
  done

  # 删除 venv
  if [[ -d "$VENV_DIR" ]]; then
    rm -rf "$VENV_DIR"
    ok "已删除 $VENV_DIR"
  fi

  # 清理 zshrc
  if [[ -f "$ZSHRC" ]]; then
    local backup="${ZSHRC}.pre-uninstall.$(date +%Y%m%d%H%M%S)"
    cp "$ZSHRC" "$backup"

    # 移除 switch-env 相关行
    sedi '/\[switch-env\]/d' "$ZSHRC"
    sedi '/switch-env\.plugin\.zsh/d' "$ZSHRC"

    # 恢复被注释的旧插件 (可选: 用户可能想手动处理)
    if grep -q 'replaced by switch-env' "$ZSHRC" 2>/dev/null; then
      sedi 's|^# \(.*\)  # replaced by switch-env|\1|' "$ZSHRC"
      ok "已恢复旧插件配置 (如有)"
    fi

    ok "已清理 ~/.zshrc (备份: $(basename "$backup"))"
  fi

  echo ""
  printf "${BOLD}════════════════════════════════════════════════${NC}\n"
  printf "${GREEN}${BOLD}  ✓ 卸载完成！${NC}\n"
  echo "  请重启终端使更改生效。"
  printf "${BOLD}════════════════════════════════════════════════${NC}\n"
  echo ""
}

# ─── 入口 ─────────────────────────────────────────────────────────
case "${1:-}" in
  --build)
    shift
    do_build "$@"
    ;;
  --uninstall|-u)
    do_uninstall
    ;;
  --help|-h)
    echo "用法: $(basename "$0") [选项]"
    echo ""
    echo "选项:"
    echo "  (无)          安装 switch-env"
    echo "  --build [out] 构建单文件安装包"
    echo "  --uninstall   卸载 switch-env"
    echo "  --help        显示此帮助"
    echo "  环境变量: AUTO_YES=1 QUIET=1"
    ;;
  *)
    do_install
    ;;
esac
