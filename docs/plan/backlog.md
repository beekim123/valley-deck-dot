# 任务池

开发者持续维护：做完打勾，太大的任务拆小，新发现的问题加进来。用户的试玩意见放在最前面，标为最高优先级。

## 用户反馈（最高优先级）

（暂无）

## D0 · 地基

- [x] 目录骨架、`.gitignore`、`README.md` 补运行方式
- [x] `package.json` 脚本
- [x] 拷贝 Fusion Pixel 12px 字体和全部许可证到 `third_party/fonts/`
- [x] `resources/art/palette.json`（48 色）+ 换色表 `winter` / `memory`
- [x] `resources/art/lib/png.mjs`、`pixel.mjs`（含 `recolor`、`snowcap`、`dissolve`）
- [x] `tools/resources/art.mjs`：build / verify / sheet
- [x] 素材：`portrait.toby`（字符画）、`locart.pines.spring` + 自动生成的 `.winter`
- [x] `resources/audio/synth.ts` + `audio-pack.ts` + `audio:check`
- [x] 音效 `sfx.card_drop`、`sfx.ice_crack`；8 秒测试旋律
- [x] `content/registry.json`、最小 `locations.json`、`tools/qa/content-check`
- [x] `tools/resources/sync-godot.mjs`（含 `--verify`）
- [x] Godot 工程设置、AssetCatalog、AudioService、SaveService 空壳
- [x] 标题画面
- [x] 无界面测试框架 + `tools/godot/cli.mjs`
- [x] D0 验收

## D1 · 规则可玩

- [ ] 内容数据：residents、locations、combos、events、visitors、spells、goals、schedule、balance
- [ ] `valley_state.gd`、`day_rules.gd`：分派、预扣、撤销、preview
- [ ] `uses.gd` 操作：gain / spend / reveal / thaw / awaken / progress / set_flag / grant_spell / story / flood / goal_step / restore
- [ ] `combos.gd`：单人、双人、前置条件、只触发一次、✦ 提示
- [ ] `events.gd`：日程、条件触发、倒计时、完成、过期、被淹时暂停
- [ ] `dealer.gd`：清晨发牌、保底访客
- [ ] `goals.gd`：四个步骤、步骤提示
- [ ] 回春判定与每日产出
- [ ] 冬眠诀两张
- [ ] 牌桌界面（灰盒）：拖动、高亮、预览框、多用法选择框、撤销、资源显示
- [ ] 事件牌、目标卡、一日小结
- [ ] 夜里逐张结算播放（灰盒版）
- [ ] 长卷色块版
- [ ] 教学第 1 天流程
- [ ] 存档与读档、损坏保护
- [ ] 规则单元测试 + 边界情况测试 + 回放测试
- [ ] `bots.gd` 三种策略 + `npm run sim` 报告
- [ ] D1 验收（含自己完整玩一遍）

## D2 · 叙事与表现

- [ ] StoryPlayer（图层、小循环、平移、翻页、跳过、条件页、笔记版式）
- [ ] 全部插画页素材与 `pages.json`
- [ ] AwakenDirector 唤醒演出
- [ ] BanterDirector + `banter.json`（含拖动嘀咕、冷却、once）
- [ ] 小烬说话人
- [ ] 夜里小场景动画（约 14 段）
- [ ] 长卷：冬春两版拼接、溶解、小人走动、全屏查看、结尾平移
- [ ] 牌桌彩蛋（茶杯、烟斗、窗户四阶段、灯笼、挂钟）
- [ ] 正式美术：牌桌、11 个地点 × 冬春、牌框、人物头像/立绘/小人、小烬、图标、界面、特效
- [ ] 音乐：标题、白天三层、夜里、回忆、结尾；短乐句；音效；环境声；说话音
- [ ] 设置菜单
- [ ] `npm run shots` 截图脚本
- [ ] D2 验收

## D3 · 试玩版

- [ ] 按自动试玩和自玩调节奏
- [ ] 阻断性问题清零
- [ ] macOS 导出（Web 可选）
- [ ] 试玩说明 + 问卷
- [ ] D3 验收，打标签 `demo-1`
