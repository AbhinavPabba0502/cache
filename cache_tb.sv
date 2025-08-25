`timescale 1ns/1ps
module cache_tb;
    logic        clk, rst_n;
    logic        read_en, write_en;
    logic [31:0] address, write_data, read_data;
    logic        hit;

    cache dut (
        .clk(clk),
        .rst_n(rst_n),
        .read_en(read_en),
        .write_en(write_en),
        .address(address),
        .write_data(write_data),
        .read_data(read_data),
        .hit(hit)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        read_en = 0;
        write_en = 0;
        address = 0;
        write_data = 0;
        #10;
        rst_n = 1;

        // Test sequence
        // Read from 0x0 (miss)
        @(posedge clk);
        address = 32'h00000000;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b0) else $fatal("Expected miss at address 0x00000000");

        // Read again from 0x0 (hit)
        @(posedge clk);
        address = 32'h00000000;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b1) else $fatal("Expected hit at address 0x00000000");

        // Read from 0x40 (miss)
        @(posedge clk);
        address = 32'h00000040;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b0) else $fatal("Expected miss at address 0x00000040");

        // Read again from 0x40 (hit)
        @(posedge clk);
        address = 32'h00000040;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b1) else $fatal("Expected hit at address 0x00000040");

        // Read from 0x80 (miss, fills way1)
        @(posedge clk);
        address = 32'h00000080;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b0) else $fatal("Expected miss at address 0x00000080");

        // Read from 0x100 (miss, evicts 0x0)
        @(posedge clk);
        address = 32'h00000100;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b", $time, address, hit);
        assert(hit == 1'b0) else $fatal("Expected miss and eviction at address 0x00000100");

        // Read from 0x0 (miss due to eviction)
        @(posedge clk);
        address = 32'h00000000;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b", $time, address, hit);
        assert(hit == 1'b0) else $fatal("Expected miss at address 0x00000000 after eviction");

        // Write to 0x200 (miss, write-allocate)
        @(posedge clk);
        address = 32'h00000200;
        write_en = 1;
        write_data = 32'hDEADBEEF;
        @(negedge clk);
        write_en = 0;
        #1;
        $display("Time %0t: WRITE addr=0x%h, data=0x%h, hit=%0b", $time, address, write_data, hit);
        assert(hit == 1'b0) else $fatal("Expected write-allocate miss at address 0x00000200");

        // Read from 0x200 (hit)
        @(posedge clk);
        address = 32'h00000200;
        read_en = 1;
        @(negedge clk);
        read_en = 0;
        #1;
        $display("Time %0t: READ  addr=0x%h, hit=%0b, data_out=0x%h", $time, address, hit, read_data);
        assert(hit == 1'b1 && read_data == 32'hDEADBEEF) 
            else $fatal("Expected hit and data DEADBEEF at address 0x00000200");

        #10;
        $display("SIMULATION PASSED");
        $finish;
    end
endmodule