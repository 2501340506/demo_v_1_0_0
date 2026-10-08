# FAT32 S2 核心模块与验证（2026-10-08）

S2 已完成本地模块验证，尚未接入生产。开发在原项目目录的 feature/fat32-filesystem 分支进行；生产仍为已上板通过的 S1。没有生成 S2 bit 或 local/board 标签。

## 接口约定

- scanner 在 scan_busy=0 时接受单周期 scan_start；scan_done 为单周期脉冲，fs_error=0 时才可使用布局和 resource_valid/cluster/size。每次扫描清空旧资源。资源位对应 PIC1～PIC4，缺图允许；紧凑播放列表由 S3 包装器生成。
- streamer 在 file_busy=0 时接受单周期 file_start，锁存起始簇、文件大小与簇大小对应移位量。卷配置在读取期间保持稳定。file_valid 无反压，file_byte_offset 从零连续递增；只输出目录项大小范围内的字节。
- 文件长度读足后等待当前扇区成功结束，再产生单周期 file_done；不为最后一个簇额外查询 EOC。file_done 同时表示失败结束，须检查 fs_error。零长度文件不发扇区请求。
- 两模块分时使用 S1 sd_sector_adapter，事务排空前不能切换所有者。底层最后字节和结束同拍由适配器分离；无进展超时与 512 字节计数也由适配器负责。
- 错误码为十六进制：10 扇区失败，20 签名，21 BPB，23 自环，24 簇范围/非法链项，25 文件提前 EOC，26 遍历上限。多簇环靠 MAX_VISITED_CLUSTERS 限制（默认 8192），不实现复杂环检测。底层失败/超时的细分类应由 S3 保留适配器错误原因。
- 复位放弃任务，无完成通知。当前无单独取消端口；S3 加载中重扫需协调写入取消、模块复位及 SD 重新初始化。本阶段复位测试同时复位模拟 SD，不等于整机恢复验收。

## 实现范围

支持 LBA0 直接引导或四个 MBR 主分区项中首个 0B/0C 分区；512 字节扇区、1～128 的二次幂扇区/簇、1/2 份 FAT及活动 FAT 选择。扫描完整根目录扇区和簇链，跳过删除项、LFN、卷标、目录，接受只读普通文件。字段随字节流解析，无整扇区缓存。文件按 FAT 链读取，支持碎片和大 LBA。不支持 GPT、扩展分区、子目录、长文件名或写入。

## 实际验证

42 个素材场景通过；另完成 6 个无字节间隔场景和 2 个任务中复位场景，共 50 次运行，编译及仿真均为 0 errors / 0 warnings。逐项名称、预期错误和结果见 [证据](../../../../diagnostics/fat32/evidence/s2/results.txt) 与 [素材清单](../../../../diagnostics/fat32/evidence/s2/manifest.json)。

覆盖四个 MBR 槽、首个匹配分区、MBR 的 EB 跳转字节、活动/单 FAT、根簇非 2、跨扇区及跨簇目录、缺图和空目录、全部簇大小、连续/碎片链、LBA 200000、非整扇区与整扇区/整簇结尾、真实目录长度截断、提前 EOC、链损坏、读失败、重扫清空资源及复位恢复。

测试串接实际扇区适配器与现有 BMP 解码器，检查物理请求序列、全部文件字节与偏移，以及 3×91 BMP 的全部 RGB 像素和坐标。坏文件不得提交帧，末扇区收到字节后报告失败也不得提交。测试为稀疏模拟介质，未访问或修改实际 SD 卡；没有覆盖 S3 SDRAM 写请求握手和整机显示提交。

| TD 独立综合（EG4S20BG256） | LUT（Utilization） | 寄存器 | BRAM | DSP |
|---|---:|---:|---:|---:|
| fat32_volume_scanner | 1506 | 671 | 0 | 0 |
| fat32_file_streamer | 785 | 163 | 0 | 0 |

综合使用固定历史工程的器件配置，仅执行 opt_gate。两个顶层暴露内部总线，引脚分别为 470/283，超过封装 188；此处只检查模块资源，未执行整机布局布线，不代表整机资源或 Setup/Hold 通过。报告保存在同一证据目录。首次脚本查找错误报告名 demo_syn.area，已改为 demo_gate.area 并完成两模块综合；RTL 无此失败。

## 复现与下一步

```powershell
& diagnostics/fat32/run_core.ps1
& diagnostics/fat32/run_core.ps1 -Cases 0,5,27,34,40,41 -ByteGap 0
& diagnostics/fat32/run_core.ps1 -Cases 0 -ResetDuring 1
& diagnostics/fat32/run_core.ps1 -Cases 0 -ResetDuring 2
& diagnostics/fat32/run_core_synthesis.ps1 -BuildName fat32_s2_new
```

顺序运行仿真，避免共用工作库冲突。素材由 generate_core_fixtures.py 生成，完整输出在 diagnostics/output/fat32_core；综合快照在 diagnostics/output/fat32_s2_syn2。S3 实现 fat32_bmp_reader、头预检和紧凑列表，接入生产图片表及工程清单，再执行相关回归、完整 TD 和候选板测。