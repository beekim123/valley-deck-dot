# 内容数据（唯一编辑入口）

`registry.json` 使用 `content/1`，各文件为 `{format:"content/1",<集合名>:数据}`。
11 个登记集合：locations、residents、combos、events、visitors、spells、goals、schedule、balance、pages、banter。

D1 规则内容完整：11 地点、6 人物记录（5 可操作）、17 新鲜事、6 事件、3 保底访客、2 冬眠诀、4 独立目标。`story/` 是文字版剧情，不引用尚未制作的插画。正式 D2 表现尚未完成。

接口以 `docs/plan/d1-rule-contract.md` 为准。条件采用封闭 JSON AST；普通用法的 `preview` 是资源操作的校验模板，不代替运行时 `DayRules.preview`。
`spend.once_key` 同一用法可覆盖多种材料，第一次实际结算后才永久记账；不同用法不得共享。`progress_key` 仅用于进度满后禁用的动作，碎石滩搬石仍可重复获石，所以不设置此字段。

事件 `done_preview/expire_preview` 校验直接资源操作，`done_text/expire_text` 说明完整公开结果。`pause_mode:"all"` 表示所有候选地点都被淹时才暂停（货郎、纸片），默认任一必需地点被淹就暂停。排队计时、发出一次和动态完成性由核心测试验证。

balance 中 `explorer_bonus/awaken_bonus` 显式指定人物、条件标记与额外资源；`flood_end_flag` 在水退时设立，使旧桥不会在仍淹水时回春。`flood_reveal_location` 是水退出现的河滩。首次教程人物免费唤醒，不能支付重复费用。

`node tools/qa/content-check.mjs --require-assets`：完整数量、字段与 AST、引用、用法选择器、首次材料归属、进度上限、公开资源模板、有限洪水与事件时长、免费资源恢复源、剧情字数和真实美术引用。

**静态解锁边检查不是动态可达性证明**。它只检查隐藏地点/人物存在进入路径，以及免费木/石/暖意来源可在零资源下经免费探路取得且不受洪水影响。完整目标路径、组合是否实际可同时触发、随机完成率和无死锁反例搜索，必须用真实 Godot 规则回放与自动试玩验证，不能凭静态 checker 声称已通过。

改内容后由集成者运行同步器；禁止手改 `godot/data/`。
