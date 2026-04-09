# ~/.bin/switch-env.plugin.zsh

# 核心 IPC 执行器
_switch_env_eval_ipc() {
  local out="$1"
  # 逐行处理输出，确保 eval 稳定执行
  echo "$out" | while IFS= read -r line; do
    if [[ "$line" =~ "^__SWITCH_ENV_CMD__:(.*)" ]]; then
      eval "${match[1]}"
    fi
  done
}

_switch_env_chpwd() {
  [[ -n "$SWITCH_ENV_EXECUTING" ]] && return 0

  local cur="$PWD"
  local new_root=""
  while [[ "$cur" != "/" ]]; do
      if [[ -f "$cur/.nvmrc" || -f "$cur/.node-version" || -f "$cur/package.json" || -f "$cur/.python-version" || -f "$cur/pyproject.toml" || -f "$cur/.switch-env" ]]; then
          new_root="$cur"
          break
      fi
      cur=$(dirname "$cur")
  done

  if [[ "$new_root" == "$SWITCH_ENV_PROJECT_ROOT" ]]; then return 0; fi

  # 状态切换
  export SWITCH_ENV_EXECUTING=1
  if [[ -n "$SWITCH_ENV_PROJECT_ROOT" ]]; then
    _switch_env_eval_ipc "$(switch-env deactivate --shell 2>/dev/null)"
  fi

  export SWITCH_ENV_PROJECT_ROOT="$new_root"
  if [[ -n "$new_root" ]]; then
    # 让人类提示穿透到终端
    _switch_env_eval_ipc "$(switch-env auto --shell --notify)"
  fi
  unset SWITCH_ENV_EXECUTING
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _switch_env_chpwd

se() {
  if [[ "$1" == "use" || "$1" == "auto" ]]; then
    export SWITCH_ENV_EXECUTING=1
    local out=$(switch-env "$@" --shell --notify)
    _switch_env_eval_ipc "$out"
    unset SWITCH_ENV_EXECUTING
  else
    switch-env "$@"
  fi
}

# 初始化
_switch_env_chpwd
