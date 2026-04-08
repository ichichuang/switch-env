# switch-env

统一管理 Python/Node.js 项目环境的命令行工具，提供安装器、zsh 插件与自动切换能力。

## 团队 Onboarding（1 分钟执行清单）

1. 只在仓库目录开发：`/Users/cc/MyPorject/switch-env`（不要在 `~/bin` 改源码）。
2. 修改后先本地安装验证：`AUTO_YES=1 bash ./install-switch-env.sh`。
3. 运行三条检查命令：
   - `command -v switch-env`
   - `switch-env doctor`
   - `switch-env status`
4. 需要分发时构建安装包：`AUTO_YES=1 ./install-switch-env.sh --build switch-env-installer.sh`。
5. 提交前检查：
   - 不提交 `~/bin`、`~/.zshrc`、缓存目录、密钥信息
   - 遵循 `.cursor/rules` 下规则文件
6. 安装后生效方式：`source ~/.zshrc`（或重开终端，curl 场景可 `exec zsh`）。

## 安装

### 方式一：CLI 一键安装（开发者）

```bash
curl -fsSL https://github.com/ichichuang/switch-env/releases/latest/download/switch-env-installer.sh | AUTO_YES=1 bash
```

### 方式二：双击安装（普通用户，仅需一个文件）

1. 从 Release 页面下载 `switch-env-installer.command`
2. 双击该文件，脚本会自动下载最新 `switch-env-installer.sh` 并执行安装

若双击无法运行，可在终端执行：

```bash
chmod +x switch-env-installer.command
./switch-env-installer.command
```

### macOS 安全提示（首次运行）

- 若系统提示“无法打开/来源不明”，请使用以下方式放行：
  - Finder 中右键 `switch-env-installer.command` -> 打开
  - 或系统设置 -> 隐私与安全性 -> 允许执行

安装后请执行：

```bash
source ~/.zshrc
```

或重开终端（推荐）；若为 `curl` 场景也可执行 `exec zsh`。

## 验证

```bash
command -v switch-env
switch-env doctor
switch-env status
```

## 构建单文件安装包

```bash
AUTO_YES=1 ./install-switch-env.sh --build switch-env-installer.sh
```

## 卸载

```bash
AUTO_YES=1 ./install-switch-env.sh --uninstall
```

## 仓库内容

- `install-switch-env.sh`: 安装/卸载/打包脚本
- `switch-env`: Python CLI 主程序
- `switch-env.plugin.zsh`: zsh 插件

## 开发规则

- 规则目录：`.cursor/rules`
- 核心约束：
  - 仓库目录是源码单一真相源，`~/bin` 仅为安装产物
  - 不手工拷贝覆盖 `~/bin` 与仓库文件
  - 变更后按安装器流程验证，再提交仓库
  - 发布前执行敏感信息与路径泄漏检查
