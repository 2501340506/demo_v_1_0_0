# S1首次构建：未交付候选

两处PLL reset接~rst_n后，TD完整构建通过，但SD域新增两个复位recovery负端点，最差−0.273ns。路径来自u_reset_sd/release_pipe[2]，扇出690、布线延时9.577ns，终点为SPI模块寄存器异步复位端。内存同域+0.160ns，另有原64个SDRAM接口负端点。此构建不作为上板候选。

保留原报告和顶层快照。处理方式：仅在顶层rst_sd增加TD支持的max_fanout=128属性，允许工具复制末级释放寄存器以缩短高扇出布线；三拍释放行为不变。不修改SDC，不排除recovery检查，不插额外延时级。

属性依据：本机TD文档SWUG106_HDL_Coding_Synthesis_User_Guide.pdf第40–41页（正文33–34页），4.2.8 max_fanout。修订后必须复跑复位专项并完整TD构建核对效果。
