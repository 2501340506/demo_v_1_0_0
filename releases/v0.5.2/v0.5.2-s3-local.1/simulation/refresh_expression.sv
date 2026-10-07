`timescale 1ns/1ps
`include "global_def.v"
module tb_s3_refresh_expression;
  localparam integer CURRENT_PERIOD = `SDR_CLK_PERIOD;
  localparam integer CURRENT_REFRESH = `SELF_REFRESH_INTERVAL;
  localparam integer TARGET_PERIOD = (1000000000 / 40000000);
  localparam integer TARGET_REFRESH = (64000000 / TARGET_PERIOD / (2**`ROW_WIDTH));
  initial begin
    $display("CURRENT period_ns=%0d refresh_macro=%0d", CURRENT_PERIOD, CURRENT_REFRESH);
    $display("TARGET period_ns=%0d max_refresh_cycles=%0d", TARGET_PERIOD, TARGET_REFRESH);
    $display("CURRENT request_compare=%0d", (`SELF_REFRESH_INTERVAL-10));
    $finish;
  end
endmodule
