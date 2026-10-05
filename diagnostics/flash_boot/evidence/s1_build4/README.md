# S1第四次构建：寄存器keep未改善物理结果

在寄存器上同时使用keep/max_fanout后，最终仍有相同两个SD域−0.273ns复位recovery负端点。因此不保留这些无效RTL属性和新增参数，reset_sync恢复S0版本，顶层恢复为仅两处PLL reset改接~rst_n。

接下来使用TD官方物理布局参数place hfn_opt_effort high处理高扇出分布。依据TD_User_Guide_V6.2.pdf第282页（正文281页），该参数用于提高高扇出网络拆分优化力度，适用于ALL器件。构建脚本新增显式开关，高扇出优化仅在指定时启用；原有调用默认不变，SDC不变。
