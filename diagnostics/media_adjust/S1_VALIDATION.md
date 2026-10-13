# S1独立验证

实际通过：ModelSim adjust_unit2 中 tb_adjust、tb_volume、tb_adjust_cdc、tb_adjust_keys、tb_adjust_osd。

RGB9216组含灰阶/通道变化/参数变化和四拍旁带；音频11档含正负极值/渐变/背压/样本计数；参数邮箱连续更新与帧提交；按键端点/组合/切项/长按/模式取消/原00操作；OSD边界/高亮/底条/百分号。

TD adjust_syn1：media_adjust_control、media_adjust_cdc、brightness_contrast_adjust、pcm_master_volume、adjust_osd_overlay、mode_key_control独立综合通过。

尚未验证：生产接入、完整物理时序、板级行为。本阶段无bit，不建立local/board标签。
