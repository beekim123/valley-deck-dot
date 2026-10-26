# 内容数据（唯一编辑入口）

`registry.json` 使用 `content/1` 格式，`files` 中每项为 `{id,path}`。
路径相对于 `content/`，文件为同版本 JSON 对象，以登记 id 为集合键，例如
`{format:"content/1",locations:[...]}`。同步器原样复制这些文件，禁止手改 `godot/data/`。

D0 只有松林的最小数据，用来验证资源引用与内容管线；**不是完整规则 demo**。
D1 再添加人物、新鲜事、事件、访客、冬眠诀、目标、日程和数值文件，以及松林回春条件。
未制作的长卷/新鲜事不登记虚假引用。

地点字段沿用 `docs/tech/architecture.md`：`id/name/start/slot/uses/art`。
`slot` 为零基 `[行,列]`；`start` 为 `fog/frozen/thawed/restored` 或未登场 `hidden`。
每个用法包含 `id/who/label/ops`，另以 `preview` 保存可核对的资源结果文本。
`label` 只写用法名，不另藏资源数字；`preview` 由 `resourcePreview` 模板核对，
例如 `+2 木（斧头磨好后 +3 木）`。运行时预览仍必须由规则层计算。

`node tools/qa/content-check.mjs` 检查数据；已有资源清单时也检查资源 id。
`node tools/qa/content-check.mjs --require-assets` 要求美术/声音清单存在，用于 D0 验收。
独立拷贝内容时无清单会明确报告跳过资源检查；不应把它当成完整验收。

当前检查器严格支持 D0 的 `gain/spend` 操作。其它操作拒绝而不是静默放行；
D1 添加操作时必须同步实现字段、引用、可达性、免费资源来源等检查与反例测试。
D0 不声称已经证明全章节可达性或无死局。
