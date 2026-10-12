# BlankNote 0.1.0 验证记录

日期：2026-10-12。环境：macOS 26.6.2、Apple Silicon、Swift 6.3.3。

## 已通过

- XCTest：11 项，0 失败。覆盖持久化、空输入、Unicode、完成恢复、编辑、删除、笔记、无效 ID、备份恢复、损坏保护、不可写路径及保存失败（部分行为合并在同一测试中）。
- Release 应用构建、Info.plist 检查、ad-hoc 签名检查、zsh 脚本语法检查。
- 实际窗口视觉检查：完整窗口和收起状态均可读，控件无明显重叠。
- 独立数据目录 `/tmp/BlankNote-UI-20261012` 中，实际界面验证中文与 emoji 输入、回车添加、勾选完成、完成列表、恢复待办、编辑保存、多行随手记、收起和展开。
- 删除对话框列出具体事项；取消删除保留原项。界面未执行最终删除，删除数据逻辑由 XCTest 覆盖。
- Command-Q 正常退出；重新用相同隔离目录启动后，编辑后的待办、未完成状态及多行笔记均恢复。
- 正式应用安装于 `~/Applications/BlankNote.app`，正式数据中未写入测试事项。
- 登录代理已加载，`launchctl` 最终显示 `state = running`、`job state = running`，启动错误日志为空。

## 未执行的环境验收

- 没有注销或重启当前电脑，因此未宣称完整登录周期实测通过。
- 未故意崩溃正式应用；异常重启行为已配置为 `KeepAlive.SuccessfulExit = false`，尚未做故障注入测试。
- 跨显示器、全部桌面空间、不同全屏应用、Intel、macOS 14/15 仍需对应环境验收。
- 尚未推送远端仓库，GitHub Actions 配置未在 GitHub 实际运行。
- 公开分发用的 Developer ID 签名及 Apple 公证未配置。

## 开发构建

文件：`build/BlankNote-0.1.0-macOS-arm64.zip`

SHA-256：`e83c72bd31456e7fb9c1cd394b6b62e91bf786b13e10d7218fa59d9bb94751fd`

该归档为当前 Apple Silicon 机器的本机签名开发构建，不是经过 Apple 公证的正式发行包。
