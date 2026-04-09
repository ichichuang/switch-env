# switch-env.plugin.zsh — 统一多运行时环境自动切换插件
# 替代 switch-node.plugin.zsh + switch-py.plugin.zsh
#
# 状态变量:
#   SWITCH_ENV_PROJECT_ROOT  — 当前激活的项目根目录 (绝对路径)
#   SWITCH_ENV_LAZY_DONE     — 非空表示本项目的懒加载已完成
#   SWITCH_ENV_PY_ACTIVE     — 非空表示 Python 环境已激活
#   SWITCH_ENV_NODE_ACTIVE   — 非空表示 Node 版本已切换

autoload -U add-zsh-hook

# ─── 项目根目录探测 ───────────────────────────────────────────────────────────
# 从当前目录向上查找标志文件，确定项目根。纯 zsh 实现，不 fork 子进程。

_switch_env_find_project_root() {
  local dir="$PWD"
  local markers=(
    .switch-env .switch-py-env .python-version
    .nvmrc .node-version
    pyproject.toml requirements.txt environment.yml
    package.json
  )
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    for m in "${markers[@]}"; do
      [[ -f "$dir/$m" ]] && { echo "$dir"; return 0; }
    done
    dir="${dir:h}"   # zsh dirname
  done
  return 1  # 未找到项目根
}

# ─── IPC 解析 ─────────────────────────────────────────────────────────────────
# 捕获 switch-env 的 stdout，逐行提取 __SWITCH_ENV_CMD__:<cmd> 并 eval

_switch_env_eval_ipc() {
  local output="$1"
  local line cmd
  while IFS= read -r line; do
    if [[ "$line" == __SWITCH_ENV_CMD__:* ]]; then
      cmd="${line#__SWITCH_ENV_CMD__:}"
      eval "$cmd"
    elif [[ "$line" == __SWITCH_PY_ACTIVATE_CMD__:* ]]; then
      cmd="${line#__SWITCH_PY_ACTIVATE_CMD__:}"
      eval "$cmd"
    fi
  done <<< "$output"
}

# 交互式：对 IPC 子命令捕获 stdout 后在当前 shell eval（避免管道子 shell）
_switch_env_run_ipc_stream() {
  local line tmp ret
  tmp="$(mktemp)"
  command switch-env "$@" >"$tmp"
  ret=$?
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == __SWITCH_ENV_CMD__:* ]]; then
      eval "${line#__SWITCH_ENV_CMD__:}"
    elif [[ "$line" == __SWITCH_PY_ACTIVATE_CMD__:* ]]; then
      eval "${line#__SWITCH_PY_ACTIVATE_CMD__:}"
    else
      print -r -- "$line"
    fi
  done <"$tmp"
  rm -f "$tmp"
  return ret
}

# 跳过全局参数后取第一个子命令名（用于分流）
_switch_env_first_subcmd() {
  local -a a
  a=("$@")
  local i s
  for ((i = 1; i <= $#a; i++)); do
    s="${a[i]}"
    case "$s" in
      -h | --help | --dry-run | --interactive | --verbose) continue ;;
      -*) continue ;;
      *) echo "$s"
        return 0 ;;
    esac
  done
  return 1
}

# 包装命令：IPC 子命令立即生效；auto --shell 与插件 chpwd 一致
switch-env() {
  local sub
  if ! sub="$(_switch_env_first_subcmd "$@")"; then
    command switch-env "$@"
    return $?
  fi

  if [[ "$sub" == "auto" ]] && [[ -n ${(M)@:#--shell} ]]; then
    eval "$(command switch-env "$@")"
    return $?
  fi

  case "$sub" in
    use | bootstrap | deactivate | __hook) _switch_env_run_ipc_stream "$@" ;;
    *) command switch-env "$@" ;;
  esac
}

# ─── 核心 chpwd 钩子 ─────────────────────────────────────────────────────────

_switch_env_chpwd() {
  local new_root old_root="$SWITCH_ENV_PROJECT_ROOT"

  # 1) 探测新目录的项目根
  new_root="$(_switch_env_find_project_root)"

  # 2) 判断是否跨项目 / 离开项目 / 进入项目
  if [[ "$new_root" == "$old_root" ]]; then
    # ── 同一项目树内移动：什么都不做，保留 lazy 标记 ──
    return 0
  fi

  # ── 跨项目或离开/进入项目 ──

  # 3) 离开旧项目 → 去激活
  if [[ -n "$old_root" ]]; then
    local deact_out
    deact_out="$(command switch-env deactivate 2>/dev/null)"
    _switch_env_eval_ipc "$deact_out"
    export SWITCH_ENV_PROJECT_ROOT=""
    export SWITCH_ENV_LAZY_DONE=""
    export SWITCH_ENV_PY_ACTIVE=""
    export SWITCH_ENV_NODE_ACTIVE=""
  fi

  # 4) 进入新项目 → 激活
  if [[ -n "$new_root" ]]; then
    export SWITCH_ENV_PROJECT_ROOT="$new_root"
    export SWITCH_ENV_LAZY_DONE=""  # 新项目，重置懒加载

    # 新架构：自动契约引擎（shell-safe 输出）
    eval "$(switch-env auto --shell 2>/dev/null)"

    # 标记由 auto 推断触发
    export SWITCH_ENV_PY_ACTIVE=1
    export SWITCH_ENV_NODE_ACTIVE=1
  fi
}

# ─── 懒加载 ──────────────────────────────────────────────────────────────────
# 仅在首次调用包装命令时触发 __hook，同项目内不重复触发

_switch_env_lazy_activate() {
  [[ -n "$SWITCH_ENV_LAZY_DONE" ]] && return 0

  # 如果不在任何项目中，跳过
  local root
  root="$(_switch_env_find_project_root)" || return 0

  # 确保项目根已记录
  if [[ -z "$SWITCH_ENV_PROJECT_ROOT" ]]; then
    export SWITCH_ENV_PROJECT_ROOT="$root"
  fi

  # v1: 统一走 auto 契约入口
  eval "$(switch-env auto --shell 2>/dev/null)"

  export SWITCH_ENV_LAZY_DONE=1
}

# ─── 命令包装 ─────────────────────────────────────────────────────────────────
# 首次调用触发懒加载，之后直接透传到原生命令

_switch_env_wrap() {
  local cmd="$1"
  shift
  _switch_env_lazy_activate
  command "$cmd" "$@"
}

# Python 系
python()  { _switch_env_wrap python  "$@"; }
python3() { _switch_env_wrap python3 "$@"; }
pip()     { _switch_env_wrap pip     "$@"; }
pip3()    { _switch_env_wrap pip3    "$@"; }
pytest()  { _switch_env_wrap pytest  "$@"; }

# Node.js 系
node()    { _switch_env_wrap node    "$@"; }
npm()     { _switch_env_wrap npm     "$@"; }
yarn()    { _switch_env_wrap yarn    "$@"; }
pnpm()    { _switch_env_wrap pnpm    "$@"; }

# ─── Zsh 补全 ─────────────────────────────────────────────────────────────────

_switch_env_completion() {
  local cur prev commands
  cur="${words[CURRENT]}"
  prev="${words[CURRENT-1]}"
  commands="use status doctor list bootstrap deactivate init clean resolve trust untrust auto repair upgrade"

  if (( CURRENT == 2 )); then
    compadd $commands
    return
  fi

  case "$words[2]" in
    use)
      if [[ "$prev" == "--py-manager" ]]; then
        compadd "pyenv" "conda"
        return
      fi
      if [[ "$prev" == "-v" || "$prev" == "--version" ]]; then
        local pyenv_versions
        pyenv_versions=("${(f)$(pyenv versions --bare 2>/dev/null)}" "system")
        pyenv_versions=(${pyenv_versions:#})
        compadd $pyenv_versions
        return
      fi
      if [[ "$prev" == "-e" || "$prev" == "--env" ]]; then
        local conda_envs
        conda_envs=(${${(f)$(conda env list --json 2>/dev/null | python3 -c "import sys,json;[print(p.rsplit('/',1)[-1] or 'base') for p in json.load(sys.stdin).get('envs',[])]" 2>/dev/null)}:#})
        compadd $conda_envs
        return
      fi
      if [[ "$prev" == "--scope" ]]; then
        compadd "local" "global"
        return
      fi
      if [[ "$cur" == -* ]]; then
        compadd "--py-manager" "-v" "--version" "-e" "--env" "--scope" "--no-install" "--clean-cache" "--dry-run" "--interactive" "--verbose" "-h" "--help"
      fi
      ;;
    status)
      if [[ "$cur" == -* ]]; then
        compadd "--dry-run" "--verbose" "-h" "--help"
      fi
      ;;
    doctor)
      if [[ "$cur" == -* ]]; then
        compadd "--dry-run" "--verbose" "-h" "--help"
      fi
      ;;
    list)
      if [[ "$cur" == -* ]]; then
        compadd "--pyenv-only" "--conda-only" "--python-only" "--node-only" "--dry-run" "--verbose" "-h" "--help"
      fi
      ;;
    bootstrap)
      if [[ "$prev" == "--py-manager" ]]; then
        compadd "pyenv" "conda"
        return
      fi
      if [[ "$cur" == -* ]]; then
        compadd "--py-manager" "--no-install" "--dry-run" "--interactive" "--verbose" "-h" "--help"
      fi
      ;;
    deactivate)
      if [[ "$prev" == "--runtime" ]]; then
        compadd "all" "python" "node"
        return
      fi
      if [[ "$cur" == -* ]]; then
        compadd "--runtime" "--dry-run" "--verbose" "-h" "--help"
      fi
      ;;
    init)
      if [[ "$cur" == -* ]]; then
        compadd "-n" "--name" "-i" "--install" "--dry-run" "--interactive" "--verbose" "-h" "--help"
      fi
      ;;
    clean)
      if [[ "$cur" == -* ]]; then
        compadd "-n" "--name" "-c" "--cache-only" "--dry-run" "--interactive" "--verbose" "-h" "--help"
      fi
      ;;
    auto)
      if [[ "$cur" == -* ]]; then
        compadd "--dry-run" "--interactive" "--verbose" "-h" "--help" "--shell" "--json"
      fi
      ;;
    resolve|trust|untrust|repair|upgrade)
      if [[ "$cur" == -* ]]; then
        compadd "--dry-run" "--interactive" "--verbose" "-h" "--help"
      fi
      ;;
  esac
}

compdef _switch_env_completion switch-env 2>/dev/null || true

# 命令别名
alias se='switch-env'

# ─── 注册钩子 & 启动初始化 ───────────────────────────────────────────────────

add-zsh-hook chpwd _switch_env_chpwd

# Shell 启动时执行一次，处理已在项目目录中的情况
_switch_env_chpwd
