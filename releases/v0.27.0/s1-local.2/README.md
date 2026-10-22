# v0.27.0 S1 候选 2：调节面板修复（Seed 47）

候选 `v0.27.0-s1-local.2`，源码提交 `3fc0e2a`，构建 `adj27b_td_s47`。在 [s1-local.1](../s1-local.1/README.md) 基础上按板测反馈修改。**卡不用换**。

## 改了什么

1. **OSD、SCROLL 开关在情景和宣讲画面也生效**（s1-local.1 板测发现没效果）。上一版只关了旧图片模式的左上状态行和滚动字幕，情景和宣讲画面的文字是另外两个模块画的，没有接上。现在：
   - **OSD = OFF**：情景画面右上角面板（告警色块、阶段标题/村名、进度条）和左下图例都不画；旧图片模式的左上状态行不画。
   - **SCROLL = OFF**：情景画面底部字幕条（含预警时滚动的预警语）、宣讲画面底部旁白字幕、旧图片模式的滚动字幕都不画，底下的半透明带也一起去掉。
   - 预警时的红色闪框不受这两个开关影响。
2. **去掉 SW1/SW2 的 01、10 调节模式**。这两个位置现在和 00 完全一样（图片/应用模式）；亮度、对比度、音量只能在 SW4 面板里调。11（预览）不变。
3. **音量最大 200%**：0..200%，每格 10%，默认 100%。超过 100% 时声音放大，波形顶到最大值就削顶（不会翻转成爆音），声音大的素材在 150% 以上可能听出失真。面板数值条按 0..200% 画。

情景画面三种开关的真实 RTL 渲染（滑坡卡阶段 4）：[全开](preview/scene_on.png)、[OSD 关](preview/scene_hud.png)、[SCROLL 关](preview/scene_sub.png)。面板：[光标态](preview/panel_cursor.png)、[编辑态（波形高度）](preview/panel_edit.png)。

## 本地结果

| 项 | s1-local.1 | 本候选 |
|---|---:|---:|
| LUT | 17560（89.59%） | 17464（89.10%） |
| 寄存器 | 10295 | 10270 |
| DSP | 16 | 17 |
| Setup / Hold (ns) | +0.111 / +0.075 | +0.136 / **+0.003**，STNS/HTNS=0 |

5 个种子只有 47 时序通过；7、21、43 Hold 差 0.002～0.020 ns，13 Setup −1.578 ns。最差路径都在 SD 时钟域的读卡/缩放/菜单逻辑，不在这次改的模块里。Hold +0.003 ns 和板测通过的 v0.26（Seed 7，+0.003 ns）一样小；板上如果有偶发异常，先告诉我，我再多跑几个种子找余量更大的。

## 验证

- 新增 `diagnostics/adjust_panel/run_scene_gates.ps1`：真实卡、真实 `scene_text_overlay`，全开 / OSD 关 / SCROLL 关三帧逐区域比较（面板、图例、字幕各自消失且互不影响），8 项全过（`validation/scene_gates.log`）。
- `adjust_panel/run_unit.ps1`：SW1/SW2 01/10 不再改任何参数；音量 20 档到 200% 为止、单项恢复回 100%；其余同 s1-local.1。
- `media_adjust/run_unit.ps1`：音量 21 档逐样本对照（含正负削顶、流控停顿），模式 1/2 下按键不改参数、旧模式翻页/重扫/AUTO 不变。
- 情景文字：`lut_opt25/run_s5_overlay.ps1` 8 张卡逐像素通过、24 个变异全部检出；`run_card_switch.ps1` 4 次换卡通过。
- `bottom_waveform` unit 4 项、integration 3 项（生产 top 逐像素），`lut_opt25/run_s1_keys.ps1` 12 项，`lut24/run_sd_pin_boot.ps1` 通过。
- 复位审计（`validation/reset_audit.txt`）：新增和改动模块的异步复位都来自复位同步寄存器。`reset_request` 是复位同步器自己的输入（`~rst_n | ~pll_lock`），`scanner/rst_n_dup_*` 是读卡器原有的 `!rst && !scan_cancel_q`，v0.26 网表里同样存在；`u_picture_adjust/center_*` 是同步 SR。
- `mountain_scene/run_m5_text.ps1` 在 main 上同样失败（同一个像素），没有作为依据。

## 上板检查

1. 烧录 [demo.bit](demo.bit)（675020 字节），卡不用换，SW4 先拨下。
2. SW1/SW2 拨到 01、10：画面和按键表现应与 00 相同，左上不再出现 B/C/V 数值。
3. SW4 拨上，分别在**情景**、**宣讲**、**旧图片**画面把 OSD、SCROLL 关掉再打开，看对应文字是否消失/恢复（对照上面三张情景渲染图）。
4. 音量从 100% 往上加到 200%，听是否变大、是否有明显破音；减到 0 静音；KEY1+KEY2 回到 100%。
5. 其余同 s1-local.1：滑入滑出、波形三项、FADE、长按 KEY4 全部重置、面板打开时不翻页、SW3 菜单先后。

回退：[s1-local.1](../s1-local.1/README.md)、[v0.26.0-s1-local.1](../../v0.26.0/s1-local.1/README.md)。
