# BlankNote

一张安静的 macOS 桌面待办便签。Swift + SwiftUI + AppKit，MIT 许可证，无第三方运行依赖，无账号、广告、遥测或联网服务。

## 功能

- 桌面常驻，默认置顶，在多个桌面空间中显示；图钉按钮可取消置顶。
- 回车添加待办，勾选完成，在「已完成」中恢复；双击文字原地编辑，回车保存、Esc 取消，离开编辑框也会保存非空修改。
- 拖动事项左侧手柄调整顺序；放到另一事项上方会移到它之前，放到列表末尾空白处可排到最后。
- 支持最近 50 次待办操作的撤销与重做，包括编辑、完成、删除和排序；撤销不会回退之后写入的随手记。
- 删除单条事项前明确确认。
- 随手记可折叠，逐次修改后本地保存；未按回车的新待办草稿也会保留到下次启动。
- 原子写入、上一版备份、损坏文件保留及恢复；保存失败会显示提示。
- 拖动标题区域移动窗口，拖动边缘调整大小，收起后保留标题。
- 菜单栏入口，关闭其他窗口不退出；登录自动启动，异常退出后自动重启。
- 全局快捷键 `Control + Option + N`（⌃⌥N）唤出并聚焦输入，再按一次隐藏。注册失败时菜单会提示，仍可从菜单栏打开。
- 菜单中集中提供置顶、登录自启，以及跟随系统 / 浅色 / 深色外观。

撤销按钮位于待办列表右上角，菜单中可重做。`⌘Z` / `⌘⇧Z` 优先处理正在编辑的文字，没有文字撤销记录时处理待办操作。待办撤销历史只保留在本次进程中，重新启动后不保留；实际笔记与待办状态会持续保存。

## 环境

macOS 14 或更新版本，Xcode 15 或更新版本（包含 Swift 5.9+）。项目使用 Swift Package Manager，无外部依赖。构建脚本输出当前 Mac 架构的应用；Intel 和 Apple Silicon 分别在对应机器构建。

## 开发、测试与构建

```sh
zsh scripts/test.sh
zsh scripts/build.sh
open build/BlankNote.app
```

也可以用 Xcode 打开 `Package.swift` 开发。核心数据逻辑位于 `Sources/BlankNoteCore`，窗口与界面位于 `Sources/BlankNote`，XCTest 测试位于 `Tests/BlankNoteCoreTests`。

如需界面测试并隔离个人数据和偏好设置，在终端启动：

```sh
zsh scripts/run-ui-test.sh
```

脚本复制出具有独立应用标识的 `BlankNoteUITest.app`，输出临时数据目录，可与正式版并行运行。通过 `BLANKNOTE_TEST_DATA_DIR=/tmp/之前的测试目录 zsh scripts/run-ui-test.sh` 复用测试数据。测试版禁止切换正式版登录启动配置；退出测试版后再验证正式版全局快捷键，避免快捷键注册冲突。不要同时运行多个实例操作同一数据目录。

## 安装与登录自启

```sh
zsh scripts/install.sh
```

安装位置为 `~/Applications/BlankNote.app`，启动项为 `~/Library/LaunchAgents/org.blanknote.BlankNote.plist`。脚本完成后立即启动；以后登录 macOS 桌面会自动启动。电脑关机或尚未登录时，图形便签不会运行。

启动项在异常退出后重启进程。主动选择「退出 BlankNote」会退出到下一次登录，或手动重新打开应用为止。系统设置 → 通用 → 登录项与扩展中应允许 BlankNote 的后台项目。

菜单中的「登录时自动启动」通过当前用户的 launchd 启用状态切换，不删除启动项或关闭当前便签；关闭后下次登录不启动，再次开启则恢复。此开关只在正式安装且存在启动项时可用。

安装脚本遇到已有应用或启动项会停止，避免不可逆覆盖。升级时，先通过菜单退出正式版和测试版，再运行：

```sh
zsh scripts/build.sh
zsh scripts/update.sh
```

更新脚本会在数据目录内的 `Upgrade Backups/` 中保留带日期的旧应用、笔记、上一版笔记备份和应用偏好；校验笔记字节未变，再启动新应用。它不会强制结束进程、删除笔记或重设登录启动偏好。不要移动或清空数据目录。

0.2.0 继续使用 0.1.0 的 JSON 格式；读取旧记录不会重写文件。新增的外观、折叠状态和输入草稿存入应用偏好，不改变已有待办记录。保存失败会显示重试入口，退出前会再次提示尚未保存的修改。

应用采用本机 ad-hoc 签名，可用于本机构建运行。公开分发的正式版本仍需维护者配置 Developer ID 签名和 Apple 公证；CI 的 zip 是开发构建。

## 数据与备份

数据存储于 `~/Library/Application Support/BlankNote/`：

| 文件 | 用途 |
| --- | --- |
| `notebook.json` | 当前待办与笔记 |
| `notebook.backup.json` | 上一次成功保存前的内容 |
| `notebook-unreadable-*.json` | 恢复时保留的损坏原文件 |
| `Logs/` | 登录启动的进程输出 |

文件是未加密的本地 JSON。可通过菜单栏「打开数据文件夹」手动复制备份；上一版备份不是长期版本历史。请使用 Time Machine 等工具保留长期备份。无法恢复损坏数据时会阻止写入，防止覆盖原文。

## 停止自启与卸载

先从菜单栏退出应用。下面的命令只卸载本次登录会话中的启动任务，不删除数据：

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/org.blanknote.BlankNote.plist"
```

若要长期停用，请将该 plist 移到 LaunchAgents 以外的备份目录。卸载应用时先确认备份，再由用户自行将应用移到废纸篓。待办数据目录保持原样，除非用户明确决定删除。

## 参与项目

参见 [贡献指南](CONTRIBUTING.md)、[测试清单](docs/TESTING.md)、[安全说明](SECURITY.md) 和 [更新日志](CHANGELOG.md)。仓库包含 GitHub Actions 测试与构建配置；推送至 GitHub 后运行。本地源码准备完成不代表已发布到公共仓库。

## 许可证

[MIT](LICENSE)
