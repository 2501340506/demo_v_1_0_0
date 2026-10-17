 integer i,b0,d0,errors=0;
 initial begin
 for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;end
 setup();cycles(10);rst=0;settled(1);wait(dut.cache_valid==15);b0=boots;d0=dirs;
 // Rescan held during app switch is canceled until release, even after READY.
 fork
  toggle_app();
  begin wait(busy);k2=0;cycles(2200);k2=1;cycles(100);end
 join
 settled(2);wait(dut.cache_valid==15);cycles(300);
 if(boots!=b0 || dirs!=d0 || dut.rescan_pending)$fatal(1,"rescan leaked through application switch");
 // A fresh press after READY performs physical rescan and reselects startup app.
 k2=0;cycles(2100);k2=1;cycles(100);wait(boots>b0);wait(busy);wait(!busy);settled(1);wait(dut.cache_valid==15);
 // Actual read failure after cache invalidation, followed by retry.
 fail_lba=16;persistent_fail=1;toggle_app();settled(2);toggle_app();wait(error);cycles(300);
 if(!busy || app!=2)$fatal(1,"read fault did not preserve committed identity");
 persistent_fail=0;fail_lba=-1;short4();wait(busy);wait(!busy);settled(1);wait(dut.cache_valid==15);
 if(boots<=b0 || !visible)$fatal(1,"recovery coverage");
 $display("PASS M5 recovery: switch-time rescan canceled/rearmed, physical rescan, read failure and retry; boots=%0d commits=%0d",boots,commits);$finish;
 end
 initial begin #500000000;$fatal(1,"M5 recovery watchdog app=%d busy=%b error=%b state=%d",app,busy,error,dut.g_application.application.state);end
endmodule
