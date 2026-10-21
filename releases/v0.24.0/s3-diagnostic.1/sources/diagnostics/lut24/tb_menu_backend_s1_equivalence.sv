`timescale 1ns/1ps
// v0.24 S1: original and reduced disaster_menu_backend under random stimulus.
// All outputs except directory are compared every cycle. directory feeds the
// reader only at a scan: compare it from scan_start until the scan is done.
// The environment keeps the production contract for parent_cluster: it
// changes only after a physical-scan invalidate, while menu entry is blocked
// (safe_menu_idle requires an idle scanner, and scans require !menu_owner).
module tb_menu_backend_s1_equivalence;
 parameter integer SEED=1, CYCLES=2000000, PARENT_CONTRACT=1;
 reg clk=0; always #5 clk=~clk;
 reg rst=1;
 reg enter=0,confirm=0,cancel=0; reg [1:0] focus=0;
 reg invalidate=0,native_thumb=0,application_error=0,storage_busy=0;
 reg parent_valid=0; reg [31:0] parent_cluster=0;
 reg [31:0] original_directory=0; reg original_publicity=0; reg [2:0] original_hazard=0; reg [1:0] original_app=0;
 reg reader_ready=1,scan_done=0,scan_error=0; reg [3:0] mapped_valid=0;
 reg [5:0] directory_valid=0; reg [191:0] directory_clusters=0;
 reg load_accept=0,load_result_valid=0,load_success=0,source_done=0,source_error=0;
 reg application_busy=0,scene_ready=0,display_committed=0,display_off=0;

`define BACKEND_PORTS(p) \
  .clk(clk),.rst(rst),.enter(enter),.confirm(confirm),.cancel(cancel),.focus(focus), \
  .invalidate(invalidate),.native_thumb(native_thumb),.application_error(application_error),.storage_busy(storage_busy), \
  .parent_valid(parent_valid),.parent_cluster(parent_cluster), \
  .original_directory(original_directory),.original_publicity(original_publicity),.original_hazard(original_hazard),.original_app(original_app), \
  .reader_ready(reader_ready),.scan_done(scan_done),.scan_error(scan_error),.mapped_valid(mapped_valid), \
  .directory_valid(directory_valid),.directory_clusters(directory_clusters), \
  .load_accept(load_accept),.load_result_valid(load_result_valid),.load_success(load_success),.source_done(source_done),.source_error(source_error), \
  .application_busy(application_busy),.scene_ready(scene_ready),.display_committed(display_committed),.display_off(display_off), \
  .owner(p``_owner),.ready(p``_ready),.discard(p``_discard),.menu_write(p``_menu_write), \
  .preview_mode(p``_preview_mode),.fallback_thumbnail(p``_fallback),.rejected(p``_rejected), \
  .scan_start(p``_scan_start),.directory(p``_directory),.publicity(p``_publicity),.hazard(p``_hazard), \
  .load_request(p``_load_request),.load_result_ready(p``_load_result_ready),.direct_load(p``_direct_load), \
  .load_index(p``_load_index),.write_slot(p``_write_slot),.valid(p``_valid), \
  .visible(p``_visible),.force_scene(p``_force_scene),.exit_done(p``_exit_done),.resume(p``_resume), \
  .selected_directory(p``_selected_directory),.selected_hazard(p``_selected_hazard),.force_target(p``_force_target)

`define BACKEND_WIRES(p) \
 wire p``_owner,p``_ready,p``_discard,p``_menu_write,p``_preview_mode,p``_fallback,p``_rejected,p``_scan_start; \
 wire [31:0] p``_directory,p``_selected_directory; wire p``_publicity; wire [2:0] p``_hazard,p``_selected_hazard; \
 wire p``_load_request,p``_load_result_ready,p``_direct_load; wire [1:0] p``_load_index,p``_write_slot,p``_force_target; \
 wire [3:0] p``_valid; wire p``_visible,p``_force_scene,p``_exit_done,p``_resume; \
 wire [127:0] p``_others={p``_owner,p``_ready,p``_discard,p``_menu_write,p``_preview_mode,p``_fallback,p``_rejected,p``_scan_start, \
  p``_publicity,p``_hazard,p``_load_request,p``_load_result_ready,p``_direct_load,p``_load_index,p``_write_slot,p``_valid, \
  p``_visible,p``_force_scene,p``_exit_done,p``_resume,p``_selected_directory,p``_selected_hazard,p``_force_target};

 `BACKEND_WIRES(r)
 `BACKEND_WIRES(n)
 disaster_menu_backend_reference ref_backend(`BACKEND_PORTS(r));
 disaster_menu_backend new_backend(`BACKEND_PORTS(n));

 integer seed=SEED;
 function integer urand(input integer n); begin urand=$unsigned($random(seed))%n; end endfunction
 function [31:0] cluster_value(input integer dummy);
  begin case(urand(6))0:cluster_value=0;1:cluster_value=$random(seed);default:cluster_value=2+urand(6);endcase end
 endfunction

 // Physical scan model: invalidate, then a later parent update; no entry meanwhile.
 integer phys=0; reg start_phys;
 // Directory comparison window: scan_start until the scan reports done.
 reg dir_window=0;
 integer cycles=0,mismatches=0,dir_checks=0,cache_hits=0,entries=0,confirms=0,recovers=0,restores=0,scene_scans=0;
 always @(negedge clk)begin
  if(!rst)begin
   cycles=cycles+1;
   if(r_others!==n_others)begin
    mismatches=mismatches+1;
    if(mismatches<=5)$display("MISMATCH t=%0t state=%0d diff=%h",$time,ref_backend.state,r_others^n_others);
   end
   if(r_scan_start || dir_window)begin
    dir_checks=dir_checks+1;
    if(r_directory!==n_directory)begin
     mismatches=mismatches+1;
     if(mismatches<=5)$display("DIRECTORY MISMATCH t=%0t state=%0d ref=%h new=%h",$time,ref_backend.state,r_directory,n_directory);
    end
   end
   if(ref_backend.state==25 && ref_backend.entry_cache_hit)cache_hits=cache_hits+1;
   if(ref_backend.state==25)entries=entries+1;
   if(ref_backend.state==15)confirms=confirms+1;
   if(ref_backend.state==23 && reader_ready && !storage_busy)recovers=recovers+1;
   if(ref_backend.state==14 && scan_done)restores=restores+1;
   if(ref_backend.state==5 && reader_ready && !r_scan_start)scene_scans=scene_scans+1;
  end
 end
 always @(posedge clk)begin
  if(r_scan_start)dir_window<=1;
  else if(scan_done && !r_scan_start)dir_window<=0;
 end

 always @(posedge clk)if(!rst)begin
  // Wide inputs: scan results change at scan completion.
  enter<=0;confirm<=0;cancel<=0;invalidate<=0;
  scan_done<=0;load_accept<=0;load_result_valid<=0;display_committed<=0;
  // safe_menu_idle excludes scan_request, so no scan accept meets an entry.
  start_phys=PARENT_CONTRACT && phys==0 && !r_owner && ref_backend.state==0 && !enter && urand(400)==0;
  if(PARENT_CONTRACT)begin
   if(start_phys)begin invalidate<=1;phys<=1+urand(50);end
   else if(phys>1)phys<=phys-1;
   else if(phys==1)begin parent_cluster<=cluster_value(0);parent_valid<=urand(5)!=0;phys<=0;end
  end else if(urand(300)==0)begin
   // Contract violation probe: change the parent without invalidating.
   parent_cluster<=cluster_value(0);parent_valid<=urand(5)!=0;
  end
  if(phys==0 && !start_phys && urand(60)==0)enter<=1;
  if(urand(25)==0)confirm<=1;
  if(urand(120)==0)cancel<=1;
  focus<=urand(4);
  native_thumb<=urand(2);application_error<=urand(30)==0;storage_busy<=urand(4)==0;
  original_directory<=urand(50)==0?cluster_value(0):original_directory;
  original_publicity<=urand(2);original_hazard<=urand(8);original_app<=urand(3);
  reader_ready<=urand(5)!=0;
  if(urand(12)==0)begin
   scan_done<=1;scan_error<=urand(15)==0;
   mapped_valid<=urand(3)==0?4'hf:$random(seed);
   directory_valid<=$random(seed);
   directory_clusters<={$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed)};
  end
  load_accept<=urand(4)==0;
  if(urand(8)==0)begin load_result_valid<=1;load_success<=urand(3)!=0;end
  source_done<=urand(10)==0;source_error<=urand(40)==0;
  application_busy<=urand(3)==0;scene_ready<=urand(2);
  display_committed<=urand(6)==0;display_off<=urand(4)==0;
 end

 initial begin
  repeat(4)@(posedge clk);rst<=0;
  repeat(CYCLES)@(posedge clk);
  $display("COVERAGE cycles=%0d dir_checks=%0d entries=%0d cache_hits=%0d confirms=%0d recovers=%0d restores=%0d scene_scans=%0d",
   cycles,dir_checks,entries,cache_hits,confirms,recovers,restores,scene_scans);
  if(mismatches!=0)$display("FAIL backend mismatches=%0d",mismatches);
  else if(entries<100 || cache_hits<20 || confirms<20 || recovers<10 || restores<20 || scene_scans<50 || dir_checks<1000)
   $display("FAIL backend coverage");
  else $display("PASS backend S1 equivalence");
  $finish;
 end
endmodule
