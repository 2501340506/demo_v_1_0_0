`timescale 1ns/1ps
// Contiguous raw sectors, generated independently of the DUT's byte counter.
// Each image begins on an integral sector, with distinguishable B/G/R bytes.
module sim_bmp_sectors #(
    parameter integer WIDTH=640, HEIGHT=480, IMAGES=4, BYTE_GAP=2
)(
    input clk, rst, request,
    input [31:0] address,
    input [3:0] bad_headers,
    output reg [7:0] data=0,
    output reg valid=0, sector_end=0,
    output reg busy=0
);
    localparam integer FILE_BYTES=54+WIDTH*HEIGHT*3;
    localparam integer SECTORS=(FILE_BYTES+511)/512;
    integer pos, base, image_id, b, gap;
    reg bad;
    function [7:0] byte_at(input integer offset, input integer id, input bad_image);
        integer p;
        begin
            byte_at=0;
            case(offset)
                0: byte_at=bad_image ? 8'h58 : 8'h42;
                1: byte_at=8'h4d;
                2,3,4,5: byte_at=FILE_BYTES >> (8*(offset-2));
                10: byte_at=54;
                14: byte_at=40;
                18,19,20,21: byte_at=WIDTH >> (8*(offset-18));
                22,23,24,25: byte_at=HEIGHT >> (8*(offset-22));
                26: byte_at=1;
                28: byte_at=24;
                default: if(offset>=54 && offset<FILE_BYTES) begin
                    p=(offset-54)/3;
                    case((offset-54)%3)
                        0: byte_at=p+id;
                        1: byte_at=(p/WIDTH)+8'h35;
                        2: byte_at=(p%WIDTH)+8'h91;
                    endcase
                end
            endcase
        end
    endfunction
    initial forever begin
        @(negedge clk);
        valid=0; sector_end=0;
        if(!rst && request) begin
            busy=1;
            image_id=address/SECTORS;
            base=(address%SECTORS)*512;
            bad=(image_id<IMAGES) ? bad_headers[image_id] : 1;
            for(b=0;b<512 && !rst;b=b+1) begin
                data=(image_id<IMAGES) ? byte_at(base+b,image_id,bad) : 0;
                valid=1; @(negedge clk); valid=0;
                for(gap=1;gap<BYTE_GAP;gap=gap+1) @(negedge clk);
            end
            if(!rst) begin sector_end=1; @(negedge clk); end
            sector_end=0; busy=0;
            // Request is level-held until end; do not duplicate that transaction.
            @(negedge clk);
        end
    end
endmodule
