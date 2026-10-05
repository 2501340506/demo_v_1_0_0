# S2第二次构建

place hfn_opt_effort high及opt_timing high后，SD域仍1个−0.098ns端点，内存同域出现2个负端点（最差−0.199ns）。不交付该构建；保持RTL/约束不变，下一轮将官方支持的opt_timing设为ultra，脚本改为显式TimingOptimization枚举，默认medium兼容旧调用。
