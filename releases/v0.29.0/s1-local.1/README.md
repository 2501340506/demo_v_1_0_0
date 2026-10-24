# v0.29.0 S1 候选 1：场景底图与泥石流特效（Seed 5）

基线 v0.28.0。源码 `b712397`，分支 `feature/scene-art-debris-v029`。本地验证通过，**尚未上板**。

## 要换的文件

- 烧 [demo.bit](demo.bit)。
- 把 [card/情景模式/](card/情景模式/) 里的 10 个文件拷到 TF 卡的 `情景模式/` 下面，覆盖同名文件：
  - `debris_village/`：PIC1–4.BMP、THUMB.BMP
  - `quake_village/`：PIC1–4.BMP、THUMB.BMP
- 其他文件都不用动（FONT/TEXT/SND、`宣讲模式/`、另外两种灾害）。
- 地震的 PIC1、PIC2、PIC4 内容没变，只是一起重新打了包，覆盖也没关系。
- bit 和卡可以混用，不会出错：
  - 新 bit 配旧卡：泥石流掩膜还是旧的，效果是新的；
  - 旧 bit 配新卡：效果还是旧的。

## 改动

- **地震 PIC3（灾后）**：
  - 房屋改成倒塌、损坏的样子，低空有灰尘，灰尘是静态画在底图里的；
  - 只重绘了村子这一片，其余区域用原图像素合成回去；
  - 房屋位置不变，原有的碎石、地裂缝、废墟特效都对得上。
- **泥石流掩膜**：
  - PIC3/PIC4 沟床从溪水出雾的地方开始画，并贴合溪水（原来从 y=30 开始，压在雾上）；
  - 冲过石桥以后，扇区下方整片铺到底边（原来只有一条窄沟）。PIC4 的危险区跟着扩大，路线检查通过；
  - PIC2 泥流冲过公路和小桥，流出画面；
  - PIC1 物源区黄框收窄，贴合沟床。
- **泥石流特效**（`hazard_layer_v3.v` 和 `hazard_v3.slurry`）：
  - 原来是半透明泥色加浪头带，和山洪太像，现在换成不透明的浑浊泥浆：
    - 值噪声向下游流动，形成成团的泥；
    - 噪声峰值处是裹泥的石块，中心亮、边缘暗，底图透出一半；
    - 有稀疏的深色泥粒和浅色碎屑；
    - 龙头是深色。
  - 发生阶段（PIC2）用 8 px 格，每帧移动 2 px；灾后阶段（PIC3）用 4 px 格，每帧移动 1 px，远景比例相应缩小。
  - RTL 复用了这两个阶段原本空闲的噪声单元，以及已有的调色板项，没有新增 ROM。去掉了不再使用的 `surge` 信号。

## 验证

- **逐位等价**：和 `tools/mountain_port/hazard_v3.render` 比较，用 ModelSim 跑。
  - `tb_m3v3_sweep`：20 个灾害/角色块，共 1,228,800 个向量，PASS。日志：[validation/tb_m3v3_sweep.log](validation/tb_m3v3_sweep.log)
  - `tb_m3v3_card`：泥石流、地震两套新卡，共 96 帧（发生阶段每帧 5 个帧计数），PASS。日志：[validation/tb_m3v3_card.log](validation/tb_m3v3_card.log)
- **TD**：14 个种子里，通过的有 Seed 5 和 Seed 37。
  - Seed 5：Setup +0.164 ns，Hold +0.110 ns，TNS 都是 0。
  - Seed 37：+0.118 / +0.003，作为备选，产物在 `diagnostics/output/v29_td_s37`。
  - 其他 12 个种子的违例全部在 `sd_card_clk`（100 MHz），原因和 v0.27/v0.28 一样，不是这次改动引入的。
  - `hazard_layer_v3` 所在的 `video_clk`，Setup 余量是 +1.747 ns。
  - 报告：[validation/final_timing.rpt](validation/final_timing.rpt)
- **资源**：17623 LUT（89.91%，比 v0.28 多 52），10281 寄存器，55 BRAM9K。`hazard_layer_v3` 占 1738 LUT。见 [validation/demo_phy.area](validation/demo_phy.area)。
- **尚未验证**：上板。其余模块源码没改，这次没有重跑它们的单元测试。

## 上板要看的

- 泥石流：
  - 第 1 页黄框贴着沟床；
  - 第 2 页是浑浊泥浆夹着石块往下流，冲过小桥流出画面，看起来不像洪水；
  - 第 3 页沟床加堆积扇是泥浆纹理，桥下方整片被盖住；
  - 第 4 页危险区、撤离路线正常。
- 地震第 3 页：房屋损坏，有灰尘，原有特效位置正确。
- 抽查滑坡、山洪是否回归。

## 回退

v0.28.0 的 bit，加上 v0.28 卡上原来的 `情景模式/debris_village/` 和 `quake_village/`。
