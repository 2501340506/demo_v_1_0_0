# S4与S3时序/资源对比

TD 6.2.1，EG4S20BG256，同一工程及约束。最终构建stability_s4_local2。

| 项目 | S3 | S4 |
|---|---:|---:|
| 全局Setup WNS / TNS (ns) | −6.565 / −296.409 | −6.565 / −295.994 |
| 全局Hold WNS (ns) | +0.003 | +0.011 |
| SD同域Setup (ns) | +0.106 | +0.107 |
| 内存同域Setup (ns) | −0.332 | −0.138 |
| 内存同域负端点 | 3 | 3 |
| SDRAM接口负端点 | 64 | 64 |
| LUT / 寄存器 | 3739 / 2846 | 3817 / 2861 |
| BRAM / DSP / PLL | 4 / 4 / 2 | 4 / 4 / 2 |

SD域无负端点；跨SD/内存两个方向均+0.725ns。内存3个负端点在未修改frame_fifo_read的state[2]两引脚（−0.138ns）、frame_fifo_write的state[2]（−0.074ns）；与S3同属原内存控制模块，但具体端点随布局变化，不宣称端点完全相同。SDRAM读接口−6.565ns，写接口−2.955ns。STA覆盖99.88%，全局仍未收敛。

首轮构建SD域−0.331ns已处理：将load_sector宽寄存器的复杂恢复使能链改为load_idx直接译码；完整仿真相关复测与第二次TD构建通过。首轮证据保留在diagnostics/stability/evidence/s4_build1，约束未放宽。
