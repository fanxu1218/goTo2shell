# GoToShell

一个轻量的 macOS 原生工具：点击 Finder 工具栏按钮，在当前目录打开 Terminal 或 iTerm2。灵感来自 [Go2Shell](https://zipzapmac.com/Go2Shell)，本项目为独立实现，不使用原应用的代码、图标或品牌资源。

**当前版本：0.1.1。** 面向本机开发与试用，已经实现核心功能；Finder 工具栏、系统授权流程和 iTerm2 的完整桌面联调仍需实际验证。

## 功能

- Terminal、iTerm2 两种终端，记住选择。
- 点击 Finder 工具栏入口，打开当前窗口目录；没有 Finder 窗口时打开桌面目录。
- 可选：优先使用选中的文件夹；选中文件时使用其所在目录。
- 支持向应用图标拖入单个文件或文件夹，也可以从菜单栏选择文件夹。
- 每次打开新窗口；菜单栏提供设置入口，关闭设置后继续响应 Finder 点击。
- 中文、空格、引号及 shell 特殊字符按原样处理。路径作为 Apple event 参数传入，并对 shell 参数做单引号转义。包含控制字符的路径明确报错。
- Finder 的「最近使用」、搜索结果等没有实际目录的页面会显示「此页面没有固定目录」，并提供选择文件夹、打开设置和取消操作。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS 13 或以上 |
| 开发工具 | Xcode 或 Command Line Tools，Swift 5.9 或以上 |
| 终端 | 系统 Terminal，或已安装的 iTerm2 |
| 依赖 | 无第三方依赖 |

构建脚本生成当前 Mac 架构的应用；尚未提供通用二进制安装包。

## 快速开始

### 1. 获取源码并构建

```sh
git clone https://github.com/fanxu1218/goTo2shell.git
cd goTo2shell
./Scripts/build-app.sh
```

构建脚本会编译 Release 版本、生成应用图标、组装 `.app` 并进行本机签名与签名校验。产物位于 `dist/GoToShell.app`，构建缓存位于 `.build/`；这两个目录不提交到 Git。

### 2. 打开应用

```sh
open dist/GoToShell.app
```

首次启动选择终端，点击「完成」保存设置。也可以先使用「打开 Finder 当前目录」或「选择文件夹…」试用。首次操作时，按系统提示允许 GoToShell 控制 Finder 和所选终端。

### 3. 添加到 Finder 工具栏

1. 退出 GoToShell，将 `dist/GoToShell.app` 复制到固定位置，如 `/Applications`，避免覆盖已有的同名应用。
2. 从固定位置重新打开应用，点击菜单栏的终端图标，进入「设置与安装引导…」。
3. 点击「在 Finder 中显示应用」。
4. **按住 ⌘ Command，将应用拖到 Finder 顶部工具栏**。这是 [Apple 官方支持的操作](https://support.apple.com/zh-cn/guide/mac-help/mchlp3011/mac)。
5. 进入任意本机文件夹，点击工具栏上的 GoToShell 图标。

未安装 iTerm2 时会显示提示，不会自动切换终端。设置窗口关闭后，可点击菜单栏的终端图标再次打开。按住 ⌘ 将图标拖出工具栏即可移除入口。

## 目录选择规则

| 操作或状态 | 打开的目录 |
| --- | --- |
| 默认点击 Finder 工具栏按钮 | 最前面的 Finder 窗口目录 |
| 没有 Finder 窗口 | 桌面目录 |
| 启用「优先打开 Finder 中选中的项目」，选中一个文件夹 | 选中的文件夹 |
| 启用上述选项，选中一个文件 | 文件所在目录 |
| 启用上述选项，没有选中项目 | 最前面的 Finder 窗口目录，或桌面目录 |
| 启用上述选项，选中多个项目 | 提示一次只选择一个项目 |
| 向应用拖入一个文件或文件夹 | 文件所在目录，或拖入的文件夹 |
| 菜单栏或设置中的「选择文件夹…」 | 手动选择的文件夹 |

首次使用时应先完成设置，再使用文件拖入功能。每次操作都会创建新终端窗口，iTerm2 使用默认 profile。

## 权限

通过原生 AppleScript / Apple events 读取 Finder 目录并控制终端，无需辅助功能权限，不修改 Finder 的配置文件。拒绝自动化授权后，可在 **系统设置 → 隐私与安全性 → 自动化 → GoToShell** 中重新开启，随后重试。该应用未启用 App Sandbox，以便执行用户授权的应用自动化。

## 常见问题

**找不到设置窗口？** 点击菜单栏的终端图标，选择「设置与安装引导…」。应用以菜单栏工具方式运行，不显示 Dock 图标。

**系统提示不允许控制 Finder 或终端？** 在「系统设置 → 隐私与安全性 → 自动化」中找到 GoToShell，开启对应应用的权限后重试。权限提示在第一次调用相应应用时出现。

**点击工具栏图标没有效果，或出现问号？** 确认应用仍在添加入口时的固定位置。移动或删除应用后，移除旧入口并从新位置重新添加。

**无法打开「最近使用」或搜索页面？** 这些页面可能没有实际文件夹路径。弹窗会说明原因，可直接点击「选择文件夹…」；也可以进入具体文件夹后操作，或在设置中启用「优先打开 Finder 中选中的项目」，在汇总页面中选中一个文件后再次点击工具栏按钮。

**iTerm2 不可用？** 先安装 iTerm2，再重新打开设置确认安装状态，或选择系统 Terminal。

**哪些路径不支持？** 仅支持可访问的本机文件和文件夹，不直接打开远程 URL。路径包含换行、制表符等控制字符时会拒绝发送给终端。

## 签名与发布

默认使用 ad-hoc 签名，适用于本机开发与试用。分发给其他用户时，应设置自己的 bundle identifier，使用 Developer ID 签名并完成公证。构建脚本支持通过环境变量指定签名身份：

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
```

上述命令只进行签名和本地校验，不会自动公证、上传或发布应用。

## 验证

```sh
./Scripts/test.sh
```

自动测试覆盖文件/目录解析、符号链接、无效路径、AppleScript 参数传递与错误，以及在 sh / bash / zsh 中实际进入特殊名称目录，检查文件名不会被当作命令执行。Finder / Terminal 脚本只编译，不在测试中触发授权或打开窗口。

当前 8 项自动测试已通过，包括区分无目录页面与自动化权限错误。脚本编译检查需要正常访问系统的应用查找服务；在受限执行环境中，该检查可能失败，需要在本机终端运行测试。

真实应用联调还需在桌面上验证：

- 首次启动和重新启动；工具栏连续点击、菜单栏设置、文件拖入均工作。
- Finder 前台目录、桌面、单个选中目录、选中文件、多个选中项目及虚拟目录。
- Terminal 与已安装的 iTerm2 均在正确目录打开新窗口。
- 允许/拒绝自动化权限后，结果或错误提示符合预期。
- 深浅色模式下设置窗口内容完整。

## 项目结构

```text
Package.swift                     Swift Package 定义
Sources/
  GoToShell/                      应用生命周期、菜单栏与设置窗口
  GoToShellCore/                  目录解析、路径转义与 AppleScript 自动化
Resources/
  Info.plist                      应用信息、文件类型与权限说明
  GoToShell.entitlements          Apple events 自动化权限
Scripts/
  build-app.sh                    构建、打包与签名
  make-icon.swift                 生成独立应用图标
  test.sh                         运行自动测试
Tests/GoToShellCoreTests/          核心功能测试
```

使用 Swift、AppKit 和 Foundation 实现原生界面；终端适配与目录处理集中在 `GoToShellCore`，便于后续扩展。

## 当前限制与后续方向

当前自动化依赖终端的 AppleScript 接口；自定义 profile 或 shell 启动脚本应保留标准的 `cd` 行为。第一版只支持新窗口，不提供新标签页、全局快捷键或开机自启。

后续可增加：

- 新标签页与更多终端适配。
- Finder Quick Action 和全局快捷键。
- 通用二进制构建、Developer ID 签名和公证发布。

提交问题时，请附上 macOS 版本、终端类型、复现步骤和错误提示。
