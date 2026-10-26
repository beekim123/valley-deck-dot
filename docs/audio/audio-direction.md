# 音乐与音效

## 1 原则【定】

- **所有声音都由仓库里的代码合成。** 源数据是文字（音符、音色参数、包络）；不用录音、不用外部采样、不用任何 AI 音乐/语音服务、不用现成旋律。
- **确定性**：同一份源数据，每次合成逐样本一致。噪声只用带固定种子的伪随机数。
- 做法沿用 <https://github.com/beekim123/rpg2d-dot> 的 `resources/audio/synth.ts`：纯 TypeScript 合成器 → Node 离线导出 WAV → 数值检查 → 游戏只播放 WAV。可以参考或改写它的代码，**旋律必须为本作重新创作**。

## 2 管线【建议】

```text
resources/audio/cues/*.ts → synth.ts（renderCue）→ tools/resources/audio-pack.ts
  → resources/audio/export/*.wav + manifest.json（提交）→ npm run sync → godot/resources/audio/
```

| 项 | 规定 |
|---|---|
| 格式 | 单声道 PCM16 WAV |
| 采样率 | 音乐 22050 Hz，音效 44100 Hz |
| 单文件 | 小于 2 MB |
| 响度 | 音乐 RMS −20 ±2 dBFS，音效 −18 ±3 dBFS，峰值 ≤ −1 dBFS |
| 循环 | 首尾样本归零，接缝检查通过 |
| Godot 导入 | 关闭有损压缩；音乐前向循环 |

`npm run audio:check`：双次合成逐样本比较，报告 SHA-256、峰值、RMS、接缝。**数值通过不等于好听**，每首曲子都要在游戏里实际听过并记录听感。

### AudioService（Godot 端）

- 第一次点击后启声；最多 6 个音效、2 个音乐播放器交叉淡化（0.6 秒）。
- 三条总线（主、音乐、音效），末端限幅 −1 dB。
- **分层音乐**：白天曲由 3 条等长的分轨同步播放，按"回春地点数"开启声部（见第 5 节）。分轨必须从同一采样点开始、长度完全相同，切换声部用 1 秒音量渐变。

## 3 音色【建议】

安静、温暖、带一点木头和雪的质感。

| 音色 | 做法 | 用途 |
|---|---|---|
| 八音盒/钢片琴 | 双算子 FM，快起慢衰 | 冬天主旋律、夜里 |
| 拨弦 | Karplus-Strong | 白天伴奏、春天声部 |
| 木笛 | 正弦 + 少量谐波 + 轻颤音 | 春天旋律、回春短乐句 |
| 柔和铺底 | 两个略失谐的三角波 + 慢起慢落 | 冬天的空旷感 |
| 木鱼/轻鼓 | 短促的滤波噪声 | 春天声部的节奏 |
| 风 | 低通滤波的种子噪声，缓慢起伏 | 冬天环境声（作为独立循环音效） |

## 4 主题动机「春醒谣」【建议】

全游戏共用一个动机，意象是"冰下面有东西在慢慢动"。3/4 拍，像摇篮曲。下面是原创示例（数字为八分音符个数，每小节合计 6），可改写，但要保留"从低处慢慢往上爬、最后一个音悬着"的轮廓，并在 `resources/audio/README.md` 写清最终版本：

```text
A1 | G4×2 A4×2 C5×2   |
A2 | D5×3 C5×1 A4×2   |
A3 | G4×2 E4×2 G4×2   |
A4 | A4×6             |   悬着，不回到 G
```

第一卷结尾的曲子里，最后一个音第一次落回 G。

## 5 曲目表（Demo）

| id | 曲名 | 用在哪 | 情绪 | BPM | 主题处理 |
|---|---|---|---|---|---|
| `music.title` | 春醒谣 | 标题、卷轴匣 | 安静、期待 | 72 | 八音盒独奏动机 + 铺底 |
| `music.day.l1` / `l2` / `l3` | 牌桌的白天（分层） | 白天分派 | 温暖、悠闲 | 88 | l1：八音盒 + 铺底（始终响）；l2：拨弦伴奏（回春 ≥ 2 处开启）；l3：木笛对位 + 轻鼓（回春 ≥ 5 处开启） |
| `music.night` | 入夜 | 夜里结算、一日小结 | 柔和、安心 | 66 | 八音盒摇篮曲，动机放慢 |
| `music.memory` | 冻住的那一刻 | 回忆插画页、笔记 | 寂寞、温柔 | 60 | 只有钢片琴，动机前两小节 |
| `music.ending` | 水磨转了 | 第一卷结尾 | 释然、喜悦 | 96 | 全部声部，动机第一次完整落回主音 |

### 短乐句

| id | 用途 | 长度 |
|---|---|---|
| `sting.awaken` | 唤醒 | ~2.5 秒 |
| `sting.restore` | 回春 | ~2 秒 |
| `sting.combo` | 新鲜事 | ~1 秒 |
| `sting.event_new` | 事件出现 | ~0.8 秒 |
| `sting.event_done` | 事件完成 | ~1 秒 |
| `sting.event_expire` | 事件过期（温和，不是失败音） | ~1 秒 |
| `sting.goal_step` | 目标完成一步 | ~1.5 秒 |
| `sting.dawn` | 清晨 | ~1.5 秒 |

## 6 音效表（Demo）

| 分组 | id |
|---|---|
| 界面 | `sfx.ui_hover`、`sfx.ui_click`、`sfx.ui_cancel`、`sfx.ui_deny`、`sfx.page_turn`、`sfx.scroll_unroll` |
| 牌 | `sfx.card_pick`、`sfx.card_drop`、`sfx.card_return`、`sfx.preview_tick`、`sfx.card_flip` |
| 冰与雪 | `sfx.ice_crack`（三档音高）、`sfx.ice_shatter`、`sfx.snow_puff` |
| 资源 | `sfx.gain_wood`、`sfx.gain_stone`、`sfx.gain_warmth` |
| 夜里小场景 | `sfx.chop`、`sfx.stone_clink`、`sfx.splash`、`sfx.skip_stone`、`sfx.beaver_gnaw`、`sfx.hammer`、`sfx.fire_crackle` |
| 环境 | `amb.wind`（冬天循环）、`amb.birds`（回春 ≥ 5 处后叠加） |
| 彩蛋 | `sfx.teacup`、`sfx.pipe_puff`、`sfx.clock_tick`、`sfx.ember_huff` |

### 说话音

| 说话人 | 音色与音高 |
|---|---|
| 小烬 | 很快的高音脉冲，带一点噼啪噪声 |
| 阿暖 | 柔和正弦，中音，慢 |
| 托比 | 低音三角波，很慢 |
| 米拉 | 高音方波，很快 |
| 老梅 | 中音拨弦，干脆 |
| 大板牙 | 低音方波，很响，短促 |
| 旁白、笔记 | 不出声 |
