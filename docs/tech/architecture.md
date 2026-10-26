# 技术架构

目录与模块边界见 [repository-layout.md](repository-layout.md)。本文的【定】：

- 引擎 **Godot 4.7.x（与 rpg2d-dot 相同的 4.7.2）+ GDScript**，渲染器 Compatibility。
- **规则与表现分离**，规则是确定性的（同一存档 + 同一串分派 = 同一结果）。
- 美术、声音、内容各走自己的管线，Godot 只读同步副本。
- 有**自动试玩**，能证明任何分派方式都不会卡死、目标一定能完成。
- 运行时不访问网络。

## 1 工具链

| 项 | 选择 |
|---|---|
| 游戏 | Godot 4.7.2，GDScript（静态类型标注尽量写全） |
| 资源工具 | Node.js 22.13+，`.mjs` 与 `node --experimental-strip-types` 运行的 `.ts` |
| Godot 位置 | 环境变量 `GODOT_BIN`，或仓库根目录的本机 `Godot.app`（不提交），或 PATH |
| 测试 | Godot 无界面运行自写测试框架；Node 端 `node --test` |

### npm 脚本【建议】

| 命令 | 作用 |
|---|---|
| `npm run art:build` / `art:verify` / `art:sheet` | 美术构建、校验、对照表 |
| `npm run audio:build` / `audio:check` | 声音导出与检查（含分层音乐的分轨等长检查） |
| `npm run content:check` | 内容引用、可达性、文字与效果一致、美术/声音 id 存在 |
| `npm run sync` / `sync:verify` | 同步资源和内容进 `godot/`；只读校验 |
| `npm run dev` | 打开游戏（调试版） |
| `npm run godot:test` | 无界面跑规则测试与回放测试 |
| `npm run sim` | 自动试玩，输出报告 |
| `npm run shots` | 按脚本走一遍主要画面截图到 `artifacts/screenshots/` |
| `npm run check` | art:verify、audio:check、content:check、sync:verify、godot:test、sim（快速档） |

## 2 Godot 工程设置【建议】

- 视口 640×360；拉伸模式 `viewport`，比例 `keep`，缩放 `integer`。
- 默认纹理过滤 `Nearest`；2D 变换和顶点吸附像素。
- 字体关闭抗锯齿、hinting、亚像素定位。

## 3 模块

```text
godot/scripts/
├─ core/                     纯规则（RefCounted，不碰 Node、资源）
│  ├─ rng.gd                 可序列化随机数（Demo 里几乎不用随机，保留给访客选择等）
│  ├─ valley_state.gd        一卷的全部状态：天数、资源、地点（状态/进度/槽位）、人物（醒着/冻住/位置）、事件、冬眠诀、标记
│  ├─ day_rules.gd           assign / unassign / preview / end_day → 事件列表
│  ├─ uses.gd                数据驱动的用法与操作（见第 4 节）
│  ├─ combos.gd              新鲜事判定（单人、双人、前置条件、只触发一次）
│  ├─ events.gd              事件牌：发牌日程、条件触发、倒计时、完成与过期
│  ├─ dealer.gd              清晨发牌、保底访客
│  ├─ goals.gd               章节目标步骤
│  └─ bots.gd                自动试玩策略：目标导向、随机、偷懒（只派一个人）
├─ content/                  读取 godot/data/*.json，校验并构造规则对象
├─ view/                     牌桌、地点牌、人物牌、事件牌、预览框、长卷、一日小结；NightPlayer 逐张播放结算
├─ story/                    StoryPlayer（插画页、笔记版式）、BanterDirector（台词、拖动嘀咕）、AwakenDirector（唤醒演出）
├─ services/                 AssetCatalog、AudioService（含分层音乐）、SaveService
└─ debug/
```

### 3.1 规则接口【建议】

```gdscript
var p := DayRules.preview(state, resident_id, location_id)   # {uses:[{id,label,cost,gain,combo_hint,blocked_reason}]}
var ok := DayRules.assign(state, resident_id, location_id, use_id)   # 预扣资源，返回 {ok, reason}
DayRules.unassign(state, resident_id)                         # 退回预扣
var events := DayRules.end_day(state)                         # 夜里结算 + 倒计时 + 回春 + 次日清晨，返回事件列表
```

事件示例：`{type="resolve", loc="loc.pines", res="res.toby", use="chop", gain={wood=2}}`、`{type="combo", id="combo.mira_river_skip"}`、`{type="reveal", loc="loc.misty_bank", slot=[0,5]}`、`{type="thaw", loc="loc.mill"}`、`{type="awaken", res="res.mei"}`、`{type="restore", loc="loc.flower_slope"}`、`{type="event_expire", id="ev.storm"}`、`{type="dawn", day=6}`。

**界面上的预览、资源剩余、高亮全部从 preview/状态读，表现层不自己算规则。**

## 4 数据驱动的用法【建议】

```json
{
  "id": "loc.pines",
  "name": "松林",
  "start": "thawed",
  "slot": [0, 0],
  "uses": [
    { "id": "chop",   "who": { "tag": "伐木" }, "label": "伐木",
      "ops": [ { "op": "gain", "res": "wood", "n": 2, "bonus_flag": "axe_sharp", "bonus": 1 } ] },
    { "id": "gather", "who": "any", "label": "拾柴",
      "ops": [ { "op": "gain", "res": "wood", "n": 1 } ] }
  ],
  "restore": { "combo": "combo.toby_mira_pines" },
  "daily": { "res": "wood", "n": 1 },
  "art": { "winter": "locart.pines.winter", "spring": "locart.pines.spring" },
  "pano": "pano.pines"
}
```

基础操作：`gain`、`spend`、`reveal`（揭示隐藏地点）、`thaw`、`awaken`、`restore`（回春）、`progress`（给指定地点的进度型用法 +1，可以跨地点，例如雾中河岸的新鲜事推进河湾的筑坝）、`set_flag`、`grant_spell`、`story`（播放插画页）、`flood`（设定若干地点若干天不可用）、`goal_step`。

新鲜事：

```json
{ "id": "combo.toby_mira_pines", "loc": "loc.pines", "who": ["res.toby", "res.mira"],
  "requires": [], "ops": [ { "op": "restore", "loc": "loc.pines" } ],
  "line": { "speaker": "res.toby", "text": "嗯……这棵，是你出生那年种的。" } }
```

**`label` 和预览文字必须和 `ops` 一致**：`content:check` 对 `gain`/`spend` 做模板比对。

## 5 存档

- `user://save.json`，带 `version`；内容是 `valley_state` 的快照 + 设置。
- 每天清晨自动保存；白天的分派不保存。
- 读取失败：坏文件改名备份，回到标题，不崩溃。

## 6 测试与验证

| 层 | 内容 | 命令 |
|---|---|---|
| 规则单元测试 | 每个用法、每条新鲜事、每个事件的完成和过期、预扣与退回、[02-rules.md](../design/02-rules.md) 第 11 节的每条边界情况 | `npm run godot:test` |
| 回放测试 | 固定分派序列 → 期望的最终状态哈希 | 同上 |
| 自动试玩 | 三种策略各跑若干次（见下） | `npm run sim` |
| 内容检查 | 引用完整；每个隐藏地点都有揭示它的新鲜事；每条新鲜事的人物和地点都能同时存在；每种资源有无条件来源 | `npm run content:check` |
| 资源校验 | 美术逐字节、调色板；声音确定性、响度、分层分轨等长 | `art:verify`、`audio:check` |
| 画面 | 截图走查：标题、卷轴匣、第 1 天、拖动预览、入夜结算、唤醒演出、长卷全屏、结尾 | `npm run shots` |

### 自动试玩策略与报告

| 策略 | 怎么玩 | 用来证明 |
|---|---|---|
| 目标导向 | 每天优先做推进目标的用法，其次新鲜事，其次资源 | 正常玩大约几天能完成；作为时长估算 |
| 随机 | 每个人随机挑一个可用的用法（也可能休息），跑 200 次，每次最多 60 天 | **任何玩法都不会卡死**：200 次全部在 60 天内完成目标 |
| 偷懒 | 每天只派一个人 | 极端情况下仍能完成 |

报告包含：完成天数分布；每天"有没有新东西"（翻牌、新鲜事、新事件、唤醒、回春任一项）——**"白过的一天"的比例**；每种资源的最低余额；17 条新鲜事各自被触发的比例；事件的完成率与过期率。

目标区间写在 [plan/playtest.md](../plan/playtest.md)。

## 7 调试版

- 命令行参数：`--day=8`、`--give=wood:10`、`--wake=res.mei`、`--shots`。
- F1 调试面板，F2 台词立即显示。
- 发布版不加载 `scripts/debug/`。
