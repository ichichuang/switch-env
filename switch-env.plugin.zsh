# ~/.bin/switch-env.plugin.zsh

# 核心 IPC 执行器
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

_switch_env_with_lock_capture() {
  local cmd="$1"
  local out
  {
    export SWITCH_ENV_EXECUTING=1
    out="$(eval "$cmd")"
  } always {
    unset SWITCH_ENV_EXECUTING
  }
  REPLY="$out"
}

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

_switch_env_chpwd() {
  local new_root old_root="$SWITCH_ENV_PROJECT_ROOT"

  local cur="$PWD"
  new_root=""
  while [[ "$cur" != "/" && -n "$cur" ]]; do
      if [[ -f "$cur/.nvmrc" || -f "$cur/.node-version" || -f "$cur/package.json" || -f "$cur/.python-version" || -f "$cur/pyproject.toml" || -f "$cur/.switch-env" ]]; then
          new_root="$cur"
          break
      fi
      cur=$(dirname "$cur")
  done

  if [[ "$new_root" == "$old_root" ]]; then
    return 0
  fi

  if [[ -n "$old_root" ]]; then
    export SWITCH_ENV_PROJECT_ROOT=""
    _switch_env_with_lock_capture "switch-env deactivate --shell"
    _switch_env_eval_ipc "$REPLY"
  fi

  if [[ -n "$new_root" ]]; then
    export SWITCH_ENV_PROJECT_ROOT="$new_root"
    _switch_env_with_lock_capture "switch-env auto --shell --notify"
    _switch_env_eval_ipc "$REPLY"
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _switch_env_chpwd

se() {
  if [[ "$1" == "use" || "$1" == "auto" ]]; then
    local -a argv=("$@")
    if ! _switch_env_has_flag "--shell" "${argv[@]}"; then
      argv+=("--shell")
    fi
    if ! _switch_env_has_flag "--notify" "${argv[@]}"; then
      argv+=("--notify")
    fi
    _switch_env_with_lock_capture "switch-env ${(@q)argv}"
    _switch_env_eval_ipc "$REPLY"
  elif [[ "$1" == "deactivate" ]]; then
    local -a argv=("$@")
    if ! _switch_env_has_flag "--shell" "${argv[@]}"; then
      argv+=("--shell")
    fi
    _switch_env_with_lock_capture "switch-env ${(@q)argv}"
    _switch_env_eval_ipc "$REPLY"
  else
    switch-env "$@"
  fi
}

_switch_env_wrap_cmd() {
  local cmd="$1"
  shift

  if [[ -n "$SWITCH_ENV_EXECUTING" ]]; then
    command "$cmd" "$@"
    return
  fi

  if [[ -z "$SWITCH_ENV_LAZY_DONE" ]]; then
    export SWITCH_ENV_LAZY_DONE=1
    _switch_env_with_lock_capture "switch-env __hook --ensure --ensure-venv"
    _switch_env_eval_ipc "$REPLY"
  fi
  command "$cmd" "$@"
}

node() { _switch_env_wrap_cmd node "$@"; }
npm()  { _switch_env_wrap_cmd npm "$@"; }
yarn() { _switch_env_wrap_cmd yarn "$@"; }
pnpm() { _switch_env_wrap_cmd pnpm "$@"; }
python() { _switch_env_wrap_cmd python "$@"; }
python3() { _switch_env_wrap_cmd python3 "$@"; }
pip() { _switch_env_wrap_cmd pip "$@"; }
pip3() { _switch_env_wrap_cmd pip3 "$@"; }
pytest() { _switch_env_wrap_cmd pytest "$@"; }

if [[ -z "$SWITCH_ENV_INITIALIZED" ]]; then
  export SWITCH_ENV_INITIALIZED=1
  _switch_env_chpwd
fi
