# S2第三次构建

opt_timing ultra消除了SD域负端点，但原内存同域3个端点仍有−0.084ns最差裕量，属于未改frame_fifo_read路径。SDRAM接口仍64个负端点。本轮不修改旧帧缓存RTL，增加TD支持的post_place_opt high继续优化物理布局；RTL/SDC不变。构建脚本参数默认auto，旧调用不受影响。
