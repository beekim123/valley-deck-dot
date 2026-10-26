# 一副山谷（暂定名）

> 整座山谷冻在一副牌里。春天来了，把它一张张焐暖。

没有战斗、没有失败、按天推进的卡牌式山谷复原游戏，2D 像素风，用 Godot 4 制作。长冬把晴溪谷冻进了一副牌，守谷人的学徒阿暖带着会说话的火种「小烬」回来，每天把村民放到地点牌上：伐木、探路、焐化冰封、唤醒冻住的人。回春的地方会出现在桌子上方的山谷长卷里，醒来的人在上面走来走去。

当前阶段：**核心玩法 demo**（第一卷「河湾」，约 12 天，30–45 分钟）。

## 当前状态

尚未开工，只有设计文档。从 [docs/README.md](docs/README.md) 开始读；开发规则见 [AGENTS.md](AGENTS.md)。

## 目录

| 目录 | 职责 |
|---|---|
| [`docs/`](docs/README.md) | 设计文档、计划、进度 |
| `resources/art/` | 美术制作源（代码绘制的像素图）与导出的 PNG |
| `resources/audio/` | 声音制作源（代码合成）与导出的 WAV |
| `content/` | 游戏内容数据（地点、人物、新鲜事、事件、剧情、台词） |
| `godot/` | Godot 工程（游戏源码）；其中 `resources/`、`data/` 是自动同步副本 |
| `tools/`、`tests/` | 构建、校验、同步工具与测试 |
| `third_party/fonts/` | OFL 字体及许可证 |
| `artifacts/screenshots/` | 已检查的截图 |

详细规则见 [docs/tech/repository-layout.md](docs/tech/repository-layout.md)。

## 运行（开发开始后补全）

需要 Node.js 22.13+ 和 Godot 4.7.2。

```sh
npm ci
npm run sync
npm run dev
```
