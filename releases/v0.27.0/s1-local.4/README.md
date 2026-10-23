# v0.27.0 S1 候选 4：去掉场景左上角 SPEED（Seed 11）

候选 `v0.27.0-s1-local.4`，源码提交 `0ad133c`，构建 `adj27e_td_s11`。在 [s1-local.3](../s1-local.3/README.md) 基础上只改一处。**卡不用换**。

## 改了什么

- **场景画面左上角的“SPEED: nX”字样和它底下的暗色底条去掉了**。速度改在面板“场景 → 速度”里看和调（s1-local.3 已加）。
- 画这一行的模块（`adjust_osd_overlay`）现在什么都不画，只负责把亮度、对比度、音量换成十进制数字给面板显示；端口不变。

面板外观和 s1-local.3 相同，预览沿用：[光标态](preview/panel_cursor.png)、[编辑速度](preview/panel_edit.png)、[四页](preview/pages.png)。

## 本地结果

| 项 | s1-local.3 | 本候选 |
|---|---:|---:|
| LUT | 17594（89.77%） | 17617（89.88%） |
| 寄存器 | 10272 | 10266 |
| BRAM9K | 55 | 55 |
| Setup / Hold (ns) | +0.113 / +0.012 | +0.116 / **+0.038**，STNS/HTNS=0 |

删掉的那部分逻辑本身少了约 10 LUT（`u_parameter_osd` 72→63），但整片总数多了 23，这是重新布局布线的正常波动，不是新增了逻辑。7 个种子里 11 通过（3/5/13/29/61 Setup 不过，37 Hold −0.012 ns）。

## 验证

- `mountain_scene/tb_m5_ui`：改为检查场景画面 70400 个像素经过这个模块后**完全不变**（原来检查 SPEED 字样），数码管阶段显示照旧，通过（`validation/tb_m5_ui.log`）。同一个 runner 里的 `tb_m5_scan` 连着读卡模块早已删掉的端口，本来就跑不起来，这次单独编译运行 `tb_m5_ui`。
- `media_adjust/run_unit.ps1` 6 项（`tb_adjust_osd` 改为读模块的十进制输出：128/255/200）、`adjust_panel/run_unit.ps1` 5 项、`bottom_waveform/run_integration.ps1` 3 项、`lut24/run_sd_pin_boot.ps1` 通过。
- 按键、情景文字模块没有改动，`keys_tick`、`s5_overlay`、`card_switch`、`scene_gates` 日志沿用 s1-local.3。
- 复位审计：面板、参数模块、控制、邮箱、音量、面板按键、速度请求、SW4 去抖的复位都来自复位同步寄存器。

## 上板检查

1. 烧录 [demo.bit](demo.bit)（677348 字节），卡不用换。
2. 进场景画面：左上角不再出现 SPEED 和暗条；KEY1 长按换速后左上角仍然没有字，SW4 面板“场景 → 速度”里显示变了。
3. 其余按 [s1-local.3 上板检查](../s1-local.3/README.md#上板检查)：中文面板、场景速度、OSD/字幕开关、音量 200%、01/10 等于 00。

回退：[s1-local.3](../s1-local.3/README.md)。
