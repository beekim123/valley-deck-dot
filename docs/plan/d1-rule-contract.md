# D1 规则契约与验证计划（开工前草案）

状态：**D0 于 2026-10-26 已通过（41 Node 测试、Godot 单测/标题集成、冷导入及实机截图）。本契约 v1 已采纳，D1 开始实施；本文仍不是 D1 验收证明。**
依据：`design/02-rules.md`、`design/03-content.md`、`tech/architecture.md`、`plan/playtest.md`；【定】不变。下列补足未指定行为的选择均为【建议】，实现前由主任务统一采纳并记入 progress；不能各 worker 自行选不同解释。

## 1 并行职责与交接

- 规则 worker：`godot/scripts/core/`、对应 `godot/tests/`；确定性状态、指令、操作、结算与回放。不读图片、音频、Node 或 SceneTree。
- 数据 worker：`content/`、内容 checker 的约定范围；11 地点、6 人物记录（5 张可操作牌 + 结尾磨坊一家）、17 新鲜事、6 事件、3 访客、2 冬眠诀。数值、中文文案、前置条件全部在数据。
- UI worker：`godot/scenes/`、`scripts/view/`、服务与读取层按主任务分工；只读 preview / view model，不重写规则。
- 集成者：统一 API 和 schema，拥有 sync / package 脚本和验收记录。`godot/data/`、`godot/resources/` 永远只由同步器写。
- 顺序：D0 通过 → 冻结本契约接口 → 数据/规则/UI 并行 → 真实数据集成 → 单测/回放/模拟 → 亲自从标题玩到结尾。mock 只用于开发，不能作为验收证据。

## 2 数据契约 v1

沿用 D0 `content/registry.json` 的 `{format:"content/1",files:[{id,path}]}`，每个文件 `{format:"content/1",<collection>:[...]}`；balance 使用对象。不要把现有 `locations` 数组改成另一种顶层结构。

登记集合：`locations,residents,combos,events,visitors,spells,goals,schedule,balance`；剧情另放 `content/story/`。

| 集合 | 必需字段与语义 |
|---|---|
| locations | `id,name,start,slot,uses`；`start` 为 hidden/fog/frozen/thawed；`slot:[row,col]` 0 基；`reveal_state` 为 fog 翻开后的 frozen/thawed；`thaw_cost` 资源映射；`awaken` 人物 id 数组；`restore_when` 条件；可选 `daily:{res,n}`、art、pano |
| residents | `id,name,tags,initial_status,home,playable`；status 为 awake/frozen；磨坊一家 `playable:false`（本卷仅剧情） |
| uses | 地点内局部唯一 `id,label,who,requires,ops`；`who` 为 `"any"` / `{resident:id}` / `{tag:tag}`；可选 `progress_key`。D0 的 `chop/gather` id 保留 |
| combos | `id,loc,who:[resident_id],requires,ops,priority`；可选 `use_id` 限定、`replace_use_gain` 标记。who 长度 1 或 2；once 固定 true |
| events / visitors | `id,name,trigger,duration,related_locations,complete_when,done_ops,expire_ops,requirement_text,done_text,expire_text`；每项公开文案与操作一致 |
| spells | `id,name,effect`；`two_actions` 需要一个 awake/playable 目标；`extra_flip` 无人物目标 |
| goals | `id,label,when,hint,related_locations`；4 个独立布尔步骤，不以列表顺序隐含前置 |
| schedule | `id,day,ops`；触发一次；固定排序按 day 再 id |
| balance | 初始三资源、地点容量 3、事件容量 3、空过提醒阈值 3、进度上限、测试策略参数。规则中的玩法数值不另硬编码 |

`requires` 统一为条件数组（全满足；缺省空数组）。`restore_when`、`complete_when`、目标 `when` 使用单个条件对象；空条件用 `{all:[]}`。条件为 JSON AST，不执行字符串表达式：`{all:[...]}` / `{any:[...]}` / `{not:...}`；叶子 `flag`、`awake`、`location_state`、`progress_at_least`、`goal_done`、`combo_done`、`event_active`、`assigned`、`use_resolved`、`day_at_least`、`days_since`。叶子必须显式带目标 id、值或天数。空 all 为真，空 any 为假；未知操作/条件拒绝加载。

具体叶子格式（禁止自创另一套参数名）：

```json
{"flag":"axe_sharp","value":true}
{"awake":"res.mei"}
{"location_state":"loc.mill","value":"thawed"}
{"progress_at_least":"wheel","loc":"loc.mill","n":2}
{"goal_done":"goal.water"}
{"combo_done":"combo.mira_river_skip"}
{"event_active":"ev.dull_axe"}
{"assigned":"res.mira","loc":"loc.pines"}
{"use_resolved":"herbs","loc":"loc.flower_slope","resident":"res.mei"}
{"day_at_least":3}
{"days_since":"awaken","target":"res.mei","n":1}
```

`days_since` 类型为 awaken/thaw/reveal，target 对应人物/地点；尚未发生永远 false。事件 trigger 也是条件对象，固定日期用 day_at_least；调度一次性由状态记账保证。goal id 在数据统一为 `goal.thaw_mill/goal.wheel/goal.water/goal.family`。

操作参数模板：`gain/spend:{op,res,n}`；`reveal/thaw/restore:{op,loc}`；`awaken:{op,resident}`；`progress:{op,loc,key,n,max}`；`set_flag:{op,key,value}`；`grant_spell:{op,id}`；`story:{op,id}`；`flood:{op,locations:[id],days}`；`goal_step:{op,id}`。spend 可加 once_key；gain 可加 bonus_flag/bonus，保持 D0 松林字段兼容。op.reveal 只将 hidden 转为该地点定义的 reveal_entry_state（默认 fog）；fog 翻面由通用 explore 用法转为 reveal_state。数据 worker 与规则 worker 在实现前确认这些键，之后不得单方改名。

操作沿用设计文档：gain/spend/reveal/thaw/awaken/restore/progress/set_flag/grant_spell/story/flood/goal_step。资源映射只允许 wood/stone/warmth 非负整数；gain/spend 的 n 非负。`spend` 在预扣编译阶段收集，夜间不得重复扣。`progress` 明确 `loc,key,n,max`，夹到 max；`flood` 明确地点数组与持续白天数；story 只发语义事件，不调用 UI。

一次性修理费采用 `spend` 的 `once_key:"mill.wheel_materials"`，不是 `progress==0` 的临时 UI 推断；这保证撤销可退款、已开始的修理次日免费、进度被别处推进时不乱收费。

单人新鲜事没有普通用法时（托比/米拉 × 雾中河岸等），核心向 preview 暴露稳定的合成用法 `combo:<combo_id>`。新鲜事名/ops 不向拖动 UI 泄露，只显示“看看这里 ✦”。若已有适用普通用法，则组合随该用法执行；凿冰的鱼只随 `chisel`，采药的姜茶只随 `herbs`。不允许给任何人万能动作来掩盖数据缺口。

Checker：所有 id 引用、slot 唯一、once_key 唯一归属、资源闭包、条件合法、隐藏地点可揭示、组合人物和地点可同时可用、事件队列有限且不重复、公开资源数字与 ops 一致。D1 灰盒可暂不具备 D2 正式美术，但所有实际引用的 art/audio id 必须存在；禁止假 id 绕校验。

## 3 状态契约

`state` 使用简单 Dictionary；`state.defs` 引用独立只读 defs Dictionary（按集合名索引内容），不写入存档或状态哈希。无需为每个记录建类；内容对象只读，共享内容不得被局内状态改写。

```text
version:int, content_version:string, seed:int, rng_state:int
revision:int, day:int (首日为 1), phase:day|ending
resources:{wood:int,stone:int,warmth:int}    # 当前可支配，已经减去 escrow
locations:{id:{state,progress:{key:int},revealed_day,thawed_day,restored_day,
                blocked_until_day:int}}   # hidden 与 fog 分开；0 表示未发生
residents:{id:{status,awakened_day}}
assignments:[{id,resident_id,location_id,use_id,order,escrow:{...},once_keys:[]}]
paid_once_keys:[string], triggered_combos:[id], flags:{key:bool|int|string}
active_events:[{id,issued_day,remaining:int}], queued_events:[id]
event_history:{id:{status:completed|expired,day:int}}, schedule_done:[id]
spell_inventory:[id], day_modifiers:{two_actions_resident:string,extra_flip:bool}
goal_steps:{id:bool}, chapter_complete:bool, ending_seen:bool
visitors_seen:[id], idle_streak:int, idle_reminder_sent:bool
last_day_events:[event], dawn_snapshot:Dictionary
```

数组顺序必须显式：桌面按 row/col，分派按递增 order，事件按 issued_day/id，组合按人数降序/priority/id。快照哈希先对 Dictionary 键递归排序；不哈希对象地址、系统时间、渲染或音频状态。

不变量：资源不负；每人最多 1 次（被指定冬眠诀目标最多 2 次且不同地点）；fog 最多 1 人、其他地点最多 3 人；同一 assignment id 唯一；active_events ≤ 3；已完成组合/事件/目标不反转；进度不溢出；day 无游戏上限。

`blocked_until_day` 为包含端点：夜 D 洪水持续 3 天 → D+1、D+2、D+3 禁用，D+4 清晨恢复，恢复时才发河滩。避免当晚扣掉一天。

## 4 API 与 UI 交互边界

公共静态接口：`new_game(defs)` 注入只读定义，其余从 state.defs 读取；不额外引入服务依赖。

```text
new_game(defs,seed=1) -> state
preview(state,resident_id,location_id,replacing_assignment_id="") -> Preview
assign(state,resident_id,location_id,use_id,replacing_assignment_id="") -> Result
unassign(state,assignment_id) -> Result
use_spell(state,spell_id,target_resident_id="") -> Result
tutorial_awaken(state,resident_id) -> Result
end_day(state) -> Result
view_model(state) -> Dictionary
```

`Result={ok:bool,reason_code:string,reason_args:Dictionary,events:Array,revision:int}`；assign 额外返回 assignment_id。失败完全不修改状态或 RNG；成功 revision +1。end_day 一次完成夜间及次日清晨，返回 events 和 summary，UI 播放期间禁用再次入夜；章节首次完成时返回 ending 标记。小结仅是表现层停留，不另建 begin_day API。

`Preview={revision,uses:[{id,label,enabled,blocked_reason,reason_args,cost,gain,remaining,combo_hint,priority}],resources_before,resources_after}`；gain 是普通用法可公开的确定数值，隐藏新鲜事只给 hint，不把惊喜内容塞到 UI。组合的公开数字替换若无法不剧透，显示普通收益 + “✦ 可能有额外变化”，不得伪称精确全收益。已有新鲜事完成后 hint 消失。

preview 纯函数（哈希、RNG、revision 均不变），移动预览用排除旧 assignment 的模拟状态，以便原预扣可用。确认前不能先占槽或扣资源；多用法取消等同无操作。默认选择优先级：新鲜事 > 特长 > 通用，最后按稳定 id 排序。

常用 reason_code：wrong_phase、unknown_id、resident_frozen、action_limit、same_location、location_hidden、location_flooded、fog_occupied、location_full、wrong_resident、requirements_unmet、insufficient_resource、progress_complete、stale_revision。

事件统一 `{seq:int,day:int,type:string,payload:Dictionary}`；type 包含 assign/unassign/spell_used/resolve/combo/reveal/flip/thaw/awaken/restore/gain/progress/event_new/event_done/event_expire/event_paused/flood/flood_end/goal_step/story/night_empty/summary/dawn/chapter_complete。`reveal` 是隐藏牌进入桌面，`flip` 是 fog 翻面，不能混为一谈。UI 逐条播放不可变事件，不在动画回调中改变规则；跳过、加速不改变最终状态。

## 5 预扣 / 退款 / 夜间原子性

1. preview 与 assign 共用一次校验/费用编译器；今天尚未产生的木/石/暖意不可用于预扣。
2. assign 成功：一次性验证全部资源，然后 resources -= cost，记录精确 escrow。资源条显示 `resources + Σescrow → resources`，不是二次扣减。
3. move：在副本退旧 escrow → 验新目标 → 成功后原子提交；失败保留原分派、顺序与 escrow。unassign 精确退账一次，重复撤销失败且不加钱。
4. once_key 在分派时只“保留”，夜间实际执行才记为 paid；取消释放。不得靠“曾点击过”视为已付。多份预留不能同时占用同一 once_key。
5. 夜间消费 escrow，不再次 spend；新获得资源只影响结算后的余额。额外翻牌必须跳过已预约的雾牌，不抢占探索；不允许状态变化导致整个夜间崩溃。
6. 全晚在工作副本验证，成功后提交；非法内容或内部错误不能留下部分结算、负资源和不可恢复存档。生产错误回报到服务层，保留此前清晨存档。

## 6 一天的确定性顺序

- 首日：初始化资源 2/0/3；托比/米拉冻住，教学点击免费唤醒、不消耗阿暖行动，只能第 1 天执行一次。首日清晨存档包含当前教学进度的处理由 SaveService 统一；不得付费重复唤醒。
- 入夜：锁定分派集合；按桌面顺序处理地点；双人组合先于单人组合；随后普通用法按分派顺序。组合按适用规则替换指定收益，否则追加，不吞人物原行动。
- 建议明确：本夜所有组合资格在入夜快照计算，避免前排刚唤醒人物改变后排 ✦；组合产生的进度和 flag 仍供夜末目标/事件判断。双人组合仅要求两人当日同地，不要求选相同用法。
- 全地点结算后先检查事件完成，再递减未完成且未暂停的计时器，再执行到 0 的过期效果。到期最后一晚完成优先于过期。
- 暂停集合使用本夜计时阶段开始前的阻塞快照；本夜刚发生的洪水从下一完整白天开始暂停，避免 active_events 排序影响结果。
- 回春条件统一夜末运行至稳定（如松林带动树洞），每地点只发一次 restore；目标独立重算。四步齐全只发一次 chapter_complete；不强制把未完成的所有地点改春天。
- 清理分派/当日冬眠诀，记录 summary（事件 payload，不是状态阶段）。普通路线 end_day 最后：day +1 → 水退与河滩揭示 → 回春每日产出 → 到期日程和条件事件入队 → 空槽发牌 → 保底 → 开场 → 保存完整清晨快照。
- 清晨自动保存须包含“已领产出、已发事件、已揭示”的状态；虽然原流程把自动保存写在清晨第一步，若在那里只存天数会重复领奖。保存的是可操作的完整清晨边界，退出白天恢复该快照，资源/分派/消耗的冬眠诀一起回滚。

## 7 内容中的歧义默认方案（须集成者确认）

- 老梅第一次花坡采药 +2 **替代** +1；鱼 +1 石、海狸啃松林 +3 木等未写替代的，作为普通用法以外新增奖励，必须在数据显式标明。不能规则 worker 与数据 worker 各自猜。
- 条件事件“醒/焐开后的第二天清晨”取次日（夜 D 发生 → D+1 发）；若采用 D+2 必须同步文案和测试。
- 货郎地点是 OR：河湾或旧桥至少一个合法可用就不暂停；仅当所有完成地点都暂时被淹而不可用时暂停。AND 事件任意必需地点被淹即暂停。未翻开/未解冻不属于被淹暂停。
- 同时最多三事件；新触发先入 FIFO 待发，只有真正发出时开始 duration；不丢牌、不在队列扣日、不重复触发。访客也占事件槽。
- “多翻一张”：每次有效探索翻面后，从其后桌面顺序寻找下一 fog（不回绕、不递归触发额外翻牌）；跳过已有探索预约的 fog（与 questions.md 已记录默认一致），避免同日重复翻面。没有下一 fog 就无额外效果。
- 河滩出现三天后自动回春：清晨 D 出现 → 夜 D+2 结束第三个可玩白天后回春。洪水不可无限延期关键资源来源。
- 连续空过第三晚提醒一次，之后不每天刷屏；有一天有行动则 idle_streak 归零，但全局提醒不重复。
- 访客全用完改往事 story；若三事件槽满且没有可做的新内容，往事作为非事件叙事保底，不突破事件容量。必须在报告中分别记 story 保底与原定义的新东西，不能静默把无内容天改记“新事件”。
- 第一卷结尾文本说“每一段都是春天”，但规则允许尚未做可选回春；UI 应反映真实成果，不伪造完成所有地点。需主任务在 questions/progress 明记此叙事差异。

## 8 必达解锁链与反死锁断言

```text
任意醒着的人免费探雾 A → 花坡 → 免费暖意
任意醒着的人免费探雾 B → 碎石滩 → 免费石
开局松林 → 免费木
米拉 × 河湾 → 雾中河岸进入桌面(fog)
任意人探路 → 霜封河岸 → 阿暖暖意 2 → 海狸醒来
海狸筑坝 2 次（或托比/米拉河岸组合各 +1）→ 目标 3
阿暖暖意 4 焐水磨 → 目标 1
托比修轮：首次木 3 石 2，累计 2 次 → 目标 2
目标 2 + 3 已完成，阿暖暖意 3 焐磨坊一家 → 目标 4 → 结尾
```

目标 3 可以先于目标 1/2；第 4 步真实前置不能因“顺序不限”删掉。暴雨过期仅河湾/旧桥临时禁用，不删海狸、进度或资源源头。事件失败不封锁主链。任何 reachable 非终局状态都应存在有限完成路径；这不等于玩家可以永远休息却自动通关。

## 9 十一项边界回归

原 `02-rules.md` **第 11 节目前只有九行**。下表前 9 项一一对应原文；第 10/11 项为本契约新增工程回归，不谎称原文有 11 条。

| # | fixture / 操作 | 必须断言 |
|---|---|---|
| 1 | A 探同一 fog，B 再探 | B preview disabled/fog_occupied；assign 失败，状态哈希不变；撤 A 后 B 可放 |
| 2 | 暖意 2 尝试费 3 的焐；当日另有人产暖意 | preview 显示 2/3；不能用夜间预期收入；资源不负 |
| 3 | 预扣后撤销/移动/取消选择框/移动到非法目标 | 全额一次退款；失败移动保留原预约；重复 unassign 不造资源 |
| 4 | 倒计时剩 1，必需地点淹 3 天 | 三晚不减；水退恢复；OR 地点仍有可用项不暂停；最后一晚完成优先 |
| 5 | 药圃/河岸仍 fog，试焐隐藏人物 | 不暴露人物可分派；探后 frozen；下一日合法焐同时 thaw+awaken 一次 |
| 6 | 托比 + 米拉同日松林，单人组合未触发 | 双人 combo seq < 单人 combo seq；各一次；普通收益按替换策略；次日无旧 hint |
| 7 | 先完成坝，再融水磨/修轮/唤醒 | 第 3 步先打勾且不回退；第 4 步仍要求 2/3；四步齐全结尾仅一次 |
| 8 | 连续 4 天无人分派，再正常行动 | 可进入每一天；第 3 晚一次提醒；无失败/强制分派；事件正常处理 |
| 9 | 一人两用指定阿暖 | 两不同地点合法，第三份/同地点第二份非法；可撤指定 assignment；次日能力清空 |
| 10 | 水轮首修预扣木 3 石 2 → 撤 → 再派 → 结算 → 次日修 | 取消不设 paid；第一次实际结算只扣一次；第二次零费用；进度满后禁用 |
| 11 | extra_flip，两 fog 各有预约，另有第三张未预约 fog | 额外翻牌跳过预约，翻第三张；每 fog 只 flip 一次；无双倍奖励；不递归翻全桌 |

额外必须测：首日免费教学；非法/负数 JSON；同 id 重复；被唤醒人物次日才可行动；每日产出幂等；三事件排队与 duration；暴雨 D+1..D+3/D+4 边界；存档恢复无复制资源；损坏存档备份回标题；UI 播放期 end_day 双击防护；preview 纯函数；不同动画速度得到同哈希。

## 10 自动试玩：安全性与活性不能混称

- **安全性**：所有随机轨迹每一步保持不变量；任意资源为零时仍能恢复免费来源；事件过期无永久封锁；洪水有有限终点。可使用属性测试、定向极端状态、可达性检查。
- **存在完成路径**：对采样 reachable 状态运行明确目标策略恢复；保存失败 seed/状态/指令轨迹。这提供反例搜索，不是穷尽无限状态空间的数学证明。
- **统计验收**：保留原门槛，纯随机 200 次、每次最多 60 天、全部完成；这是固定样本通过，不是“任何任意策略必定完成”。随机允许休息，故永远休息本来合法；200 次全过若未达到，报告真实失败，不能到期限改由目标 bot 接管或把休息删掉后仍叫纯随机。
- 目标导向 10–14 天、白过 0%；偷懒每天只派一人 ≤40 天；随机白过 ≤10%；平均组合触发 ≥60%。随机策略分布、种子列表和内容哈希必须写报告，复跑逐字节一致。
- 暴雨目标导向完成率 30–60% 对单一确定策略+确定内容可能只能 0/100%；要有明确记录的不同目标导向偏好/种子策略族才有比例意义。不能注入隐藏运行时随机来做指标。
- 每天 report 记录资源最小余额、目标进度、组合、事件完成/过期/暂停、是否有新东西、保底种类。按 playtest 定义统计新东西；同日清晨新事件计入该日，非新往事不自动抵消白过。
- 达不到验收时记录失败 seed 与原因，调【建议】数值需同步设计/progress 后重跑。D1 gate 保持未过；不得用“模拟脚本退出 0”代替指标。

## 11 交付与停止条件

本文件不是实现或验收证据。D0 gate 已解除，D1 开始实施。D1 gate 仍需以下真实证据。

实现后需提交给集成者（不在本准备任务执行提交）：测试清单及真实结果、回放 hash、200 次完整模拟报告、失败 seed（如有）、标题至结尾亲自试玩时间/截图。任何缺失明确标 pending/failed/not run；不称 demo 已完成。
