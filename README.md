# switch-env

`switch-env` 是一个统一的多运行时环境管理工具，用于自动识别并切换项目中的 Python / Node.js 运行环境。  
项目包含三部分：

- `switch-env`：CLI 主程序（Python）
- `switch-env.plugin.zsh`：zsh 自动切换插件
- `install-switch-env.sh`：安装/卸载/打包脚本

---

## 1 分钟快速开始（新用户）

### 路径 A：命令行一键安装（开发者推荐）

```bash
curl -fsSL https://github.com/ichichuang/switch-env/releases/latest/download/install.sh | AUTO_YES=1 bash
```

说明：
- 使用最新 Release 安装包
- `AUTO_YES=1` 表示自动确认安装步骤

### 路径 B：双击安装（普通用户推荐）

1. 从 Release 页面下载 `switch-env-installer.command`
2. 双击执行（脚本会自动下载最新 `switch-env-installer.sh` 并安装）

如无法双击运行，手动执行：

```bash
chmod +x switch-env-installer.command
./switch-env-installer.command
```

安装完成后执行：

```bash
source ~/.zshrc
```

或重开终端（推荐）。若通过 `curl` 安装，也可执行 `exec zsh`。

---

## 安装器行为说明（重要）

安装器会自动识别三种安装模式：

- `fresh`：首次安装（未检测到历史安装痕迹）
- `update`：检测到官方安装痕迹，执行更新
- `conflict`：检测到同名但非官方文件，默认中止保护你的环境

冲突时如你确认覆盖，使用：

```bash
FORCE=1 curl -fsSL https://github.com/ichichuang/switch-env/releases/latest/download/install.sh | AUTO_YES=1 bash
```

调试安装模式评分（排障专用）：

```bash
DEBUG_INSTALL_MODE=1 QUIET=0 bash ./install-switch-env.sh
```

或统一调试开关（未来兼容）：

```bash
SWITCH_ENV_DEBUG=1 QUIET=0 bash ./install-switch-env.sh
```

---

## 项目契约自动切换（Project Runtime Orchestration v1）

`switch-env` 支持按项目契约文件 `.switch-env` 自动切换运行时。  
当你 `cd` 进入项目目录（或其子目录）时，zsh 插件会调用：

```bash
switch-env auto --shell
```

并将输出的 shell 命令 `eval` 到当前会话中。

### 协议边界（JSON IPC + Shell 输出）

- Python 决策层会先构建 `RuntimePlan`（结构化计划对象）。
- `switch-env auto --json`：输出结构化 JSON，便于审计与调试。
- `switch-env auto --shell`：基于计划渲染 shell-safe 命令，供 plugin `eval` 执行。
- 未授权契约时默认安全 no-op：`--shell` 不输出命令到 stdout，仅在 stderr 提示需先 `trust`。

示例：

```bash
switch-env auto --json
switch-env auto --shell
```

### `.switch-env` 示例

```ini
# 仅支持 key=value（严格语法）
python=3.12
node=22
pnpm=8
env_file=.env
post_activate=echo ready
```

### 严格语法规则（v1）

- 允许空行、`#` 开头整行注释
- 仅支持 `key=value`
- `key` 必须是 `[a-z_][a-z0-9_]*`
- `value` 按原始字符串处理，不做 shell 展开
- 不允许 inline comment（例如 `python=3.12 # comment` 会报错）

### 信任流程（hash-based）

出于安全原因，`.switch-env` 默认不会自动执行，需先 trust：

```bash
switch-env resolve
switch-env trust
switch-env auto --shell
```

取消信任：

```bash
switch-env untrust
```

信任基于 `sha256(content)`，当 `.switch-env` 内容变化时会自动失效，需重新 `trust`。

---

## 验证安装是否成功

```bash
command -v switch-env
switch-env doctor
switch-env status
```

说明：
- `command -v switch-env`：确认命令是否在 PATH 中
- `switch-env doctor`：检查 pyenv/conda/nvm/node/switch-env 可用性
- `switch-env status`：查看当前目录的 Python / Node 匹配状态

---

## CLI 命令手册（全量）

### 子命令一览（速查）

| 子命令 | 作用摘要 |
|--------|----------|
| `use` | 按项目标识切换/激活 Python、Node，可选安装依赖 |
| `status` | 表格展示当前目录 Python / Node 请求与现状 |
| `doctor` | 检查 pyenv/conda/nvm/node/switch-env 与安装态 `fresh/update/conflict` |
| `list` | 列出 pyenv 版本、conda 环境、nvm 已装 Node |
| `bootstrap` | 检测项目后一次性准备环境（偏「初始化一条龙」） |
| `deactivate` | 去激活 Python / Node（通过 IPC 输出 shell 命令） |
| `init` | 创建或复用虚拟环境，可选装依赖 |
| `clean` | 清理 `__pycache__` 或删除指定 venv 目录 |
| `resolve` | 向上查找当前目录生效的 `.switch-env` 路径 |
| `trust` | 将契约文件按内容哈希记入 `~/.switch-env/allowlist.json` |
| `untrust` | 从 allowlist 移除指定契约路径的记录 |
| `auto` | 解析 `.switch-env` 契约，输出人类可读 / JSON / shell 计划 |
| `repair` | 修复安装态（meta、shebang 等），冲突时保护非官方二进制 |
| `upgrade` | 拉取最新 Release 的 `install.sh` 并执行升级 |
| `__hook` | **内部/调试**：输出 `__SWITCH_ENV_CMD__:` 风格片段；日常请用 `auto --shell` |

说明：

- 不带子命令时执行 `switch-env` 会打印帮助并退出（退出码 `0`）。
- zsh 插件提供别名：`alias se='switch-env'`，以下示例中 `se` 与 `switch-env` 等价。

### 全局参数（适用于所有子命令）

写在子命令**之前**，对整条命令生效：

- `--dry-run`：只打印将执行动作，不真正改动环境（具体子命令是否支持以行为为准；`trust`/`untrust` 写 allowlist 时会跳过写入）
- `--interactive`：允许交互确认（如 `clean` 删除 venv、`use`/`bootstrap` 安装步骤）
- `--verbose`：输出调试信息；对 `doctor` 会打开安装态评分调试输出

示例：

```bash
switch-env --verbose doctor
switch-env --dry-run use
```

### 输出协议：`__SWITCH_ENV_CMD__` 与 `auto --shell`

- **`use`、`deactivate`、`bootstrap`（及部分管理器激活）**：在标准输出中打印形如 `__SWITCH_ENV_CMD__:<shell 命令>` 的行；**zsh 插件**会捕获这些行并 `eval` 对应命令。若你在脚本中直接调用，请同样解析该前缀或改用 `source` 配合插件文档。
- **`auto --shell`**：直接输出**可执行的 shell 脚本片段**（多行 `export` / `if` 等），**不带** `__SWITCH_ENV_CMD__:` 前缀，供 `eval "$(switch-env auto --shell)"` 使用。
- **`auto --json`**：输出单行 JSON，对应内部 `RuntimePlan`（字段含 `action`、`env`、`commands`、`meta`）；与 `--shell` **互斥**，不可同一次调用。

### 1) `use`：智能切换/激活当前目录环境

作用：根据项目标识自动切 Python / Node，并按需安装依赖。

常用参数：
- `--py-manager {pyenv,conda}`：强制 Python 管理器
- `-v, --version`：强制 Python 版本
- `-e, --env`：强制 Conda 环境名
- `--scope {local,global}`：pyenv 写入范围（默认 `local`）
- `--no-install`：不自动安装缺失版本或依赖
- `--clean-cache`：切换后清理缓存

示例：

```bash
switch-env use
switch-env use --py-manager pyenv -v 3.12 --scope local
switch-env use --py-manager conda -e myenv --no-install
```

### 2) `status`：查看当前目录环境状态

作用：输出 Python / Node 请求版本、当前版本与匹配状态。

```bash
switch-env status
```

### 3) `doctor`：环境诊断

作用：诊断 pyenv、conda、nvm、node、PATH 优先级，并输出安装态评分（`fresh/update/conflict`）。

参数：

- 无子命令专有参数；可使用全局 `--verbose` 查看安装态检测的调试信息（与安装器 `DEBUG_INSTALL_MODE` 逻辑对应的 Python 侧评分）。

```bash
switch-env doctor
switch-env --verbose doctor
```

典型用途：
- 判断当前安装是否正常（install-mode 是否为 `update`）
- 在升级前确认是否需要先 `repair`

### 4) `list`：列出可用版本/环境

作用：列出 pyenv 版本、conda 环境、nvm Node 版本。

参数：

- `--pyenv-only`：Python 侧只显示 pyenv 版本表，不显示 conda 环境
- `--conda-only`：Python 侧只显示 conda 环境表，不显示 pyenv 版本
- `--python-only`：不显示 Node（nvm）段落
- `--node-only`：不显示 Python（pyenv/conda）段落

组合说明：默认四类信息按可用性输出。`--python-only` 会隐藏 Node 列表；`--node-only` 会隐藏 Python（pyenv/conda）列表。若两者**同时**指定，则 Python 与 Node 段落均被关闭（通常无输出，属边缘用法）。

示例：

```bash
switch-env list
switch-env list --python-only
switch-env list --node-only
switch-env list --pyenv-only
switch-env list --conda-only
```

### 5) `bootstrap`：一键初始化当前项目环境

作用：检测当前目录项目类型后，依次尝试：确保 Python 版本、（在配置允许时）创建/复用 `.venv`、安装依赖、输出 Node 版本；激活信息通过 **`__SWITCH_ENV_CMD__:`** 行打印，需由 shell 插件解析执行。

参数：
- `--py-manager {pyenv,conda}`：覆盖自动选择的 Python 管理器
- `--no-install`：跳过依赖安装等步骤（具体跳过范围以实现为准）

示例：

```bash
switch-env bootstrap
switch-env bootstrap --py-manager pyenv
```

### 6) `deactivate`：去激活环境

作用：去激活 Python 环境并恢复 Node 默认版本。

参数：
- `--runtime {all,python,node}`（默认 `all`）

示例：

```bash
switch-env deactivate
switch-env deactivate --runtime python
```

### 7) `init`：仅创建虚拟环境

作用：在**已配置 pyenv** 的前提下，于当前目录创建（或复用）指定名称的虚拟环境目录；可选在安装后根据项目文件安装依赖。不做「智能推断用 conda」等分支（与 `use`/`bootstrap` 不同）。

参数：
- `-n, --name`：虚拟环境目录名（默认 `.venv`）
- `-i, --install`：创建后安装依赖

前置条件：

- 需要 `pyenv` 管理器可用；若不可用会报错。

示例：

```bash
switch-env init
switch-env init -n .venv-dev -i
```

### 8) `clean`：清理缓存或删除虚拟环境

作用：删除 Python 缓存，或删除指定虚拟环境目录。

参数：
- `-n, --name`：目标虚拟环境目录名（默认 `.venv`）
- `-c, --cache-only`：仅清理缓存，不删虚拟环境

示例：

```bash
switch-env clean -c
switch-env clean -n .venv-dev
```

### 9) `repair`：修复安装态异常（Runtime v1）

作用：修复 `meta/shebang` 等安装态问题；如果主程序不是官方版本会拒绝自动修复并给出建议。可使用全局 `--verbose` 查看安装态评分细节。

```bash
switch-env repair
switch-env --verbose repair
```

典型场景：
- `doctor` 显示 install-mode 为 `conflict`
- `~/bin/switch-env` shebang 被改坏
- `~/.switch-env/meta` 缺失或损坏

### 10) `upgrade`：升级到最新 Release（Runtime v1）

作用：从 GitHub Release latest 下载并执行官方安装器，完成无交互升级。冲突安装态下会先拒绝并提示先 `repair`。可使用 `--verbose` 查看升级前后安装态检测输出。

```bash
switch-env upgrade
switch-env --verbose upgrade
```

说明：
- 若当前安装态为 `conflict`，会先阻止升级并提示执行 `switch-env repair`
- 升级入口与安装入口一致（统一走 `install.sh` bootstrap）
- 升级完成后会再次检测安装态并输出结果

### 11) `resolve`：解析当前生效契约文件

作用：从当前工作目录向上查找第一个存在的 `.switch-env` 文件，将**绝对路径**打印到标准输出。

退出码：

- `0`：找到契约文件
- `1`：未找到任何 `.switch-env`

```bash
switch-env resolve
```

### 12) `trust`：信任契约文件

作用：校验并解析目标 `.switch-env`（严格语法），通过后把「绝对路径 + 内容 sha256 + 时间」写入 `~/.switch-env/allowlist.json`。

参数：

- `path`（可选）：契约文件路径，或项目目录（若为目录则使用 `<path>/.switch-env`）。省略时从当前目录向上解析，与 `resolve` 规则一致。

```bash
switch-env trust
switch-env trust /path/to/project
switch-env trust /path/to/project/.switch-env
```

### 13) `untrust`：取消信任契约文件

作用：从 allowlist 中移除与给定路径对应的记录（按 `file` 字段匹配，不要求哈希仍一致）。

参数：

- `path`（可选）：同 `trust`。

```bash
switch-env untrust
switch-env untrust /path/to/project
switch-env untrust /path/to/project/.switch-env
```

### 14) `auto`：自动解析并输出执行计划

作用：解析已信任的 `.switch-env` 契约，生成运行时计划。

参数：

- `--json`：输出一行 JSON（`RuntimePlan`）；无契约或未信任时输出 `action` 为 `noop` 的结构化说明（仍合法 JSON）。
- `--shell`：将计划渲染为 shell 脚本片段，供插件或 `eval`；无契约或未信任时标准输出为空，**提示信息在标准错误**。
- `--json` 与 `--shell` **互斥**，同时使用会报错退出。

无附加参数时：人类可读地打印契约路径与键值（不输出 JSON）。

契约键当前行为提示：`pnpm` 在 v1 仅导出 `SWITCH_ENV_TARGET_PNPM`；`post_activate` 仅告警「v1 不执行」，避免任意命令执行风险。

```bash
switch-env auto
switch-env auto --json
switch-env auto --shell
```

### 15) `__hook`（内部命令，普通用户可忽略）

作用：供旧版插件或调试使用，按项目检测输出 `__SWITCH_ENV_CMD__:` 形式的激活片段；日常 **zsh 自动切换请使用 `auto --shell`**。

参数（实现细节，可能变动）：

- `--ensure`
- `--ensure-venv`

```bash
switch-env __hook --ensure --ensure-venv
```

---

## 安装脚本命令手册（install-switch-env.sh）

### 基本命令

```bash
./install-switch-env.sh
./install-switch-env.sh --build switch-env-installer.sh
./install-switch-env.sh --uninstall
./install-switch-env.sh --help
```

说明：
- 无参数：执行安装流程
- `--build`：构建单文件安装包（带 payload）
- `--uninstall`：卸载 `switch-env`

### 环境变量

- `AUTO_YES=1`：自动确认
- `QUIET=1`：减少输出
- `FORCE=1`：冲突场景强制覆盖
- `DEBUG_INSTALL_MODE=1`：输出安装模式评分调试信息
- `SWITCH_ENV_DEBUG=1`：统一调试开关（兼容未来命令）

示例：

```bash
AUTO_YES=1 ./install-switch-env.sh
FORCE=1 AUTO_YES=1 ./install-switch-env.sh
DEBUG_INSTALL_MODE=1 QUIET=0 ./install-switch-env.sh
```

---

## 双击安装器说明（switch-env-installer.command）

行为：
- 自动下载 latest bootstrap：`install.sh`
- bootstrap 再下载正式安装器 `switch-env-installer.sh` 并执行
- 显示成功/失败状态并防止窗口闪退

---

## Runtime v1 生命周期建议

建议排障流程：

```bash
switch-env doctor
switch-env repair
switch-env doctor
switch-env upgrade
switch-env doctor
```

解释：
- 第一轮 `doctor`：确认问题类型
- `repair`：修复安装态异常
- `upgrade`：拉齐到最新发布版本
- 最后一轮 `doctor`：确认最终状态

注意：
- 首次运行可能被 macOS Gatekeeper 拦截
- 放行方式：
  - Finder 右键 `switch-env-installer.command` -> 打开
  - 系统设置 -> 隐私与安全性 -> 允许执行

---

## 自动发布（GitHub Actions）

工作流文件：`.github/workflows/release.yml`

触发方式：
- 推送 tag：`v*`（例如 `v1.0.0`）

发布产物：
- `install.sh`
- `switch-env-installer.sh`
- `switch-env-installer.command`
- `sha256.txt`

发布步骤：

```bash
git add .
git commit -m "release: prepare v1.0.0"
git push
git tag v1.0.0
git push origin v1.0.0
```

---

## 开发者工作流（方案 A）

核心原则：
- 仓库目录是源码单一真相源：`/Users/cc/MyPorject/switch-env`
- `~/bin` 是安装产物目录，不直接改源码

建议流程：
1. 在仓库改代码
2. 运行安装器做本机验证
3. 运行 `doctor/status` 验证行为
4. 提交与打 tag 发布

---

## 常见问题（FAQ）

### Q1: 双击 `.command` 没反应
- 先执行：
  ```bash
  chmod +x switch-env-installer.command
  ./switch-env-installer.command
  ```
- 再检查系统是否拦截（隐私与安全性放行）

### Q2: 安装提示同名冲突
- 说明本地已有同名工具，不是官方安装痕迹
- 默认中止是保护机制
- 确认覆盖再用 `FORCE=1`

### Q3: 安装后命令找不到
- 执行：
  ```bash
  source ~/.zshrc
  ```
- 或重开终端

---

## 仓库结构

- `install-switch-env.sh`：安装/卸载/打包脚本
- `switch-env`：Python CLI 主程序
- `switch-env.plugin.zsh`：zsh 插件
- `install.sh`：一行安装 bootstrap 入口（支持 `curl | bash`）
- `switch-env-installer.command`：双击安装入口
- `.github/workflows/release.yml`：tag 自动发布流程
- `.cursor/rules`：项目规则文件

---

## 许可证

本项目采用 MIT License，详见 `LICENSE`。
