# BMP 2.11 最终接口与架构

bmp_header_check 负责头字段采集和格式/长度校验，供扫描和独立解码复用。bmp24_decoder 负责字节流解码、BGR 转 RGB、行填充、坐标、像素完整性及完成事件。bmp_read 负责 SD 扇区扫描、跨度计算、读取调度、短扇区检查、超时和 SDRAM 写请求握手，外部接口不变。sd_card_bmp 继续负责原有调度和显示提交。

file_start 独占一拍，随后 file_valid 每拍至多一个字节，offset 从 0 顺序输入，可插空拍，无背压。file_end 只结束本次输入，可与末字节同拍；file_size 来自上游。动态宽高在任务期间保持稳定。

header_accepted、pixel_valid、frame_commit、bmp_done 为单周期脉冲；bmp_error 锁存到下一次 file_start：0 正常、1 头错误、2 上游错误、3 截断。frame_commit 仅为解码成功，显示交换还要等待 SDRAM 和跨域确认。包装层正常 load_done 相比 S2 晚一个时钟。

RGB888 按文件顺序输出，x 递增、y=height-1-row，不缓存整帧反转。支持正高度未压缩 24/32 位、行填充；32 位 alpha 丢弃。生产 ALLOW_32=0，维持仅 24 位显示，32 位扫描快跳。

原始连续扇区没有真实 EOF，不能检测所有头部伪报完整长度的物理截断。2.12 image 层、8 位错误码、独立恢复 FSM、fast_boot_gate 等不属于本次实现。