# 《一副山谷》网页试玩包 · 第一卷「河湾」

这是完整第一卷的独立网页包，不是在线发布，也不需要安装 Godot。建议使用桌面浏览器和鼠标；浏览器必须支持 WebAssembly 与 WebGL 2。

## 本地打开

1. 完整解压 ZIP，不要移动或重命名其中的文件。
2. 在解压后的 `valley-deck-0.1.0-web` 目录打开终端，执行 `python3 serve.py`（需要 Python 3）。
3. 浏览器访问 **http://127.0.0.1:8060/**，点击“进入山谷”。不要直接双击 `index.html`（`file://` 无法正确加载游戏）。
4. 结束后在终端按 Ctrl+C。服务器只绑定本机，不公开发布。

也可以在该目录运行 `python3 -m http.server 8060 --bind 127.0.0.1`，再打开同一地址。

## 操作与限制

- 人物牌拖到地点牌，先看预览再确认；按天推进，完整教学、叙事、声音、四目标和结尾后自由玩均保留。
- 浏览器需要点击才允许播放声音；游戏内再点击一次可解锁声音。设置里可调音乐与音效音量。
- 存档在当前浏览器的站点存储中。保持相同浏览器、地址和端口；隐私模式、清理站点数据或更换浏览器可能导致存档丢失。不要在正在加载/保存时关闭页面。
- 网页使用单线程 Compatibility/WebGL 2，不要求 COOP/COEP。保留同步音乐与混音效果，Web 使用 Stream 播放模式；性能较低的设备可能有音频延迟或卡顿，主观听感仍需用户实测。
- 需要完整 `index.html`、`.js`、`.wasm`、`.pck`、音频 worklet 与图标。全部运行资源在包内，无远程 CDN、统计或外部字体请求；源码和许可说明见 `third_party/`。
- 包含制作时的文件哈希及源码快照清单。导出成功/包检查不等于所有浏览器和真实 Mac 都已验证。

## 当前验证范围

- 同版原生引擎检查 Web PCK：283 项通过，原始 WAV/字体/内容与源文件逐字节校验通过；ZIP、清单哈希与相对资源路径通过。
- 云端 Chromium 打开本地 HTTP 页面，加载入口与缺失能力提示正确显示；该环境未提供 WebGL 2，所以游戏渲染、浏览器内拖放/存档及 Web 音频尚未实际验证。此包为待用户浏览器试玩的候选包，不冒充浏览器全流程已通过。

## 从仓库复现

使用经官方 SHA512 校验的 Godot 4.7.2 与同版 `web_nothreads_release.zip`，设置 `GODOT_BIN`、`GODOT_WEB_TEMPLATE` 后运行 `node tools/godot/export-web.mjs`。产物在 `build/web/`，不进入 Git。导出在隔离暂存工程中进行：保留原始 WAV/WOFF2 的插件与 Web 音频覆盖不会修改 macOS 工程。

技术依据：[Godot Web 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)、[4.7.2 官方 Web 导出实现](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.cpp)。
