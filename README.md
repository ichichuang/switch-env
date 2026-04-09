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
curl -fsSL https://github.com/ichichuang/switch-env/releases/latest/download/switch-env-installer.sh | AUTO_YES=1 bash
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
FORCE=1 curl -fsSL https://github.com/ichichuang/switch-env/releases/latest/download/switch-env-installer.sh | AUTO_YES=1 bash
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

### 全局参数（适用于所有子命令）

- `--dry-run`：只打印将执行动作，不真正改动环境
- `--interactive`：启用交互确认
- `--verbose`：输出调试信息

示例：

```bash
switch-env --verbose doctor
switch-env --dry-run use
```

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

```bash
switch-env doctor
```

典型用途：
- 判断当前安装是否正常（install-mode 是否为 `update`）
- 在升级前确认是否需要先 `repair`

### 4) `list`：列出可用版本/环境

作用：列出 pyenv 版本、conda 环境、nvm Node 版本。

参数：
- `--pyenv-only`
- `--conda-only`
- `--python-only`
- `--node-only`

示例：

```bash
switch-env list
switch-env list --python-only
switch-env list --node-only
```

### 5) `bootstrap`：一键初始化当前项目环境

作用：检测项目后一次性完成版本准备、依赖安装、激活计划输出。

参数：
- `--py-manager {pyenv,conda}`
- `--no-install`

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

作用：创建（或复用）`.venv`，可选安装依赖。

参数：
- `-n, --name`：虚拟环境目录名（默认 `.venv`）
- `-i, --install`：创建后安装依赖

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

作用：修复 `meta/shebang` 等安装态问题；如果主程序不是官方版本会拒绝自动修复并给出建议。

```bash
switch-env repair
```

典型场景：
- `doctor` 显示 install-mode 为 `conflict`
- `~/bin/switch-env` shebang 被改坏
- `~/.switch-env/meta` 缺失或损坏

### 10) `upgrade`：升级到最新 Release（Runtime v1）

作用：从 GitHub Release latest 下载并执行官方安装器，完成无交互升级。

```bash
switch-env upgrade
```

说明：
- 若当前安装态为 `conflict`，会先阻止升级并提示执行 `switch-env repair`
- 升级完成后会再次检测安装态并输出结果

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
- 自动下载 latest 安装器：`switch-env-installer.sh`
- 调用安装器执行安装
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
- `switch-env-installer.command`：双击安装入口
- `.github/workflows/release.yml`：tag 自动发布流程
- `.cursor/rules`：项目规则文件

---

## 许可证

本项目采用 MIT License，详见 `LICENSE`。
