# ~/.bin/switch-env.plugin.zsh

# 1. 核心的 IPC 执行器 (安全解析多行命令)
_switch_env_eval_ipc() {
  local out="$1"
  while IFS= read -r line; do
    if [[ "$line" =~ "^__SWITCH_ENV_CMD__:(.*)" ]]; then
      eval "${match[1]}"
    elif [[ "$line" =~ "^__SWITCH_PY_ACTIVATE_CMD__:(.*)" ]]; then
      eval "${match[1]}"
    fi
  done <<< "$out"
}

# 锁包裹执行：保证任何情况下都能释放 SWITCH_ENV_EXECUTING
_switch_env_with_lock_capture() {
  local __cmd="$1"
  local __out_var="$2"
  local __out
  {
    export SWITCH_ENV_EXECUTING=1
    __out="$(eval "$__cmd")"
  } always {
    unset SWITCH_ENV_EXECUTING
  }
  typeset -g "$__out_var=$__out"
}

# 参数去重：避免重复拼接 --shell/--notify
_switch_env_has_flag() {
  local want="$1"
  shift
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "$want" ]]; then
      return 0
    fi
  done
  return 1
}

# 2. 目录切换钩子 (无缝、无静默吞噬)
_switch_env_chpwd() {
  local new_root old_root="$SWITCH_ENV_PROJECT_ROOT"

  # 简单的向上查找项目根，防止无限循环
  local cur="$PWD"
  new_root=""
  while [[ "$cur" != "/" && -n "$cur" ]]; do
      if [[ -f "$cur/.nvmrc" || -f "$cur/.node-version" || -f "$cur/package.json" || -f "$cur/.python-version" || -f "$cur/pyproject.toml" || -f "$cur/.switch-env" ]]; then
          new_root="$cur"
          break
      fi
      cur="$(dirname "$cur")"
  done

  if [[ "$new_root" == "$old_root" ]]; then
    return 0
  fi

  # 离开项目 -> 去激活 (移除 2>/dev/null 避免吞掉反馈)
  if [[ -n "$old_root" ]]; then
    export SWITCH_ENV_PROJECT_ROOT=""
    local deact_out
    _switch_env_with_lock_capture "switch-env deactivate --shell" deact_out
    _switch_env_eval_ipc "$deact_out"
  fi

  # 进入新项目 -> 激活
  if [[ -n "$new_root" ]]; then
    export SWITCH_ENV_PROJECT_ROOT="$new_root"
    local use_out
    # 核心修复：绝不加 2>/dev/null，让 stderr 自由输出到屏幕
    _switch_env_with_lock_capture "switch-env auto --shell --notify" use_out
    _switch_env_eval_ipc "$use_out"
  fi
}

# 注册目录钩子
autoload -U add-zsh-hook
add-zsh-hook chpwd _switch_env_chpwd

# 3. 提供 se 快捷命令 (手动触发)
se() {
  if [[ "$1" == "use" || "$1" == "auto" ]]; then
    local out
    local -a argv=("$@")
    if ! _switch_env_has_flag "--shell" "${argv[@]}"; then
      argv+=("--shell")
    fi
    if ! _switch_env_has_flag "--notify" "${argv[@]}"; then
      argv+=("--notify")
    fi
    _switch_env_with_lock_capture "switch-env ${(@q)argv}" out
    _switch_env_eval_ipc "$out"
  elif [[ "$1" == "deactivate" ]]; then
    local out
    local -a argv=("$@")
    if ! _switch_env_has_flag "--shell" "${argv[@]}"; then
      argv+=("--shell")
    fi
    _switch_env_with_lock_capture "switch-env ${(@q)argv}" out
    _switch_env_eval_ipc "$out"
  else
    # doctor, status, list 等直接运行
    switch-env "$@"
  fi
}

# 4. 懒加载包装器 (防无限递归挂死终端)
_switch_env_wrap_cmd() {
  local cmd="$1"
  shift
  
  # 防御死锁：如果是在 switch-env Python 脚本的子进程中，直接放行原生命令
  if [[ -n "$SWITCH_ENV_EXECUTING" ]]; then
      command "$cmd" "$@"
      return
  fi

  if [[ -z "$SWITCH_ENV_LAZY_DONE" ]]; then
      export SWITCH_ENV_LAZY_DONE=1
      local out
      _switch_env_with_lock_capture "switch-env __hook --ensure --ensure-venv" out
      _switch_env_eval_ipc "$out"
  fi
  command "$cmd" "$@"
}

# 绑定常用命令
node() { _switch_env_wrap_cmd node "$@"; }
npm()  { _switch_env_wrap_cmd npm "$@"; }
yarn() { _switch_env_wrap_cmd yarn "$@"; }
pnpm() { _switch_env_wrap_cmd pnpm "$@"; }
python() { _switch_env_wrap_cmd python "$@"; }
python3() { _switch_env_wrap_cmd python3 "$@"; }
pip() { _switch_env_wrap_cmd pip "$@"; }
pip3() { _switch_env_wrap_cmd pip3 "$@"; }
pytest() { _switch_env_wrap_cmd pytest "$@"; }

# 5. 初始化：打开新终端时执行一次
if [[ -z "$SWITCH_ENV_INITIALIZED" ]]; then
  export SWITCH_ENV_INITIALIZED=1
  _switch_env_chpwd
fi
