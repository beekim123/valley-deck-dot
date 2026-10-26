# macOS 0.1.0 候选包（不是 demo-1）

此构建用于第一轮试玩，不代表 D3 已验收。真实干净 macOS 从启动到结尾、主观听感仍未验证；当前 Linux 云端不能替代这些检查，不打 `demo-1` 标签。

## 可复现导出

先完成 `npm run check` 和同步资源，再设置本机环境变量：

```sh
GODOT_BIN="<已校验的 Godot 4.7.2 编辑器>" \
GODOT_MACOS_TEMPLATE="<官方 4.7.2 templates/macos.zip>" \
node tools/godot/export-macos.mjs
```

脚本核对引擎版本、官方模板 SHA-512 和同步清单，复制独立工程到忽略的 `build/macos/` 临时目录；模板绝对路径只写临时副本，不修改已跟踪的 preset。失败也清理临时工程，导出日志保留。不要并行运行两个导出；异常强制终止留下的 `.export.lock` 应先确认无进程运行再处理。

- ZIP：`build/macos/valley-deck-0.1.0-macos-candidate.zip`。
- 通用架构：Intel x86_64 + Apple Silicon arm64；模板最低版本分别为 macOS 11 / 13，尚非实机兼容性保证。
- Bundle ID：`io.github.beekim123.valleydeck`；版本 `0.1.0`；Testing 导出。
- Godot 内建 ad-hoc 签名；无 Apple 开发者身份、无公证、无凭据。
- 显式保留原始 WAV、JSON、像素字体与全部许可证；Godot include_filter 不会保留已识别导入素材的原始字节，因此脚本在临时工程注册导出插件添加 WAV/WOFF2 原文，插件不进入发布包；排除测试、截图、布局检查和调试入口，保留叙事运行时辅助脚本。
- 模板 SHA-512：`0310a772b1acf3a63acc74a2a44352bb3a20cb3bee4a8112cc124e6f078dbef2109629f07b87e561a0a87966ee15d595fbc9dc9d2a6b49bd38aa7f9278f62c27`。

## 验证记录

2026-10-26 候选包已导出并通过下述云端检查：

- ZIP：74,756,455 字节；SHA-256 `69e09ced52d665294dac91c676219a44ab9e2699ce5020e744f507144bb8387b`。
- SHA-512：`0f991570f3c77eac5382445d8b81636cadad08aee8d6ada1ec5ed3410667814f5c1312423b3b3e8782fade1b95ac4992e2e34f958398b723619a1eb13a6fc7bf`。
- 源文件快照清单 SHA-256：`2dab29fdcfe97b3dae42669c91392298ee7cba02df3bbc2bdc4ad7e440a7296b`。清单包括当时未提交的改动，不把候选包声明为旧 Git HEAD 的产物。
- ZIP CRC、相对安全路径、可执行权限、中文 App 名/Bundle ID/0.1.0/最低系统版本全部正确。
- x86_64 与 arm64 Mach-O 均存在；ad-hoc 标志正确，两架构 SHA-256/SHA-1 CodeDirectory 的全部代码页哈希验证通过；3 项资源封套 SHA-256 通过。这不是 Apple 平台信任/公证验证。
- 同版 Linux 引擎加载导出 PCK：283 项断言、0 失败，覆盖164项美术、55项声音、中文字体、11个地点和标题实例化。
- 原始55份 WAV、15份 JSON、1份 WOFF2、4份字体许可证和 README 与同步源 SHA-256 一致；9个代表性 QA/调试入口确认不在包中。
- 修复记录：首轮导出因通用架构要求 ETC2/ASTC 导入标志失败，补充设置后导出；下一轮探针检出原始 WAV 缺失，添加临时原文导出插件后重新导出并全部复验。失败日志保留，不把失败包作为交付物。

完整记录保留到 `build/macos/export-manifest.json`、`package-validation.json`、`export.log` 和 `export-probe.log`。

运行包探针只验证同版 Linux 引擎读取导出的 PCK、全部素材、原始 PCM、中文字体、内容和标题实例化，**不是 macOS 启动测试**。下载的未公证应用可能被系统拦截；不要关闭系统保护或移除隔离标记。用户自行决定是否信任并按系统支持的单应用批准流程测试。
