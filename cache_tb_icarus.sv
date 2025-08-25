`timescale 1ns/1ps
module cache_tb;
    reg         clk, rst_n;
    reg         read_en, write_en;
    reg  [31:0] address, write_data;
    wire [31:0] read_data;
    wire        hit;

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

    // 10ns clock
    always #5 clk = ~clk;

    task check(input bit cond, input [1023:0] msg);
        begin
            if (!cond) begin
                $display("FATAL: %s", msg);
                $finish;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; read_en = 0; write_en = 0; address = 0; write_data = 0;
        #12; rst_n = 1;

        // READ 0x0 (miss)
        @(posedge clk); address = 32'h0000_0000; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check(hit == 1'b0, "Expected miss at 0x00000000");

        // READ 0x0 (hit)
        @(posedge clk); address = 32'h0000_0000; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check(hit == 1'b1, "Expected hit at 0x00000000");

        // READ 0x40 (miss)
        @(posedge clk); address = 32'h0000_0040; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check(hit == 1'b0, "Expected miss at 0x00000040");

        // READ 0x40 (hit)
        @(posedge clk); address = 32'h0000_0040; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check(hit == 1'b1, "Expected hit at 0x00000040");

        // READ 0x80 (miss)
        @(posedge clk); address = 32'h0000_0080; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check(hit == 1'b0, "Expected miss at 0x00000080");

        // READ 0x100 (miss, evict)
        @(posedge clk); address = 32'h0000_0100; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b", address, hit);
        check(hit == 1'b0, "Expected miss at 0x00000100");

        // READ 0x0 (should be miss after eviction)
        @(posedge clk); address = 32'h0000_0000; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b", address, hit);
        check(hit == 1'b0, "Expected miss at 0x00000000 after eviction");

        // WRITE 0x200 (write-allocate)
        @(posedge clk); address = 32'h0000_0200; write_en = 1; write_data = 32'hDEAD_BEEF;
        @(negedge clk); write_en = 0; #1;
        $display("WRITE 0x%h data=0x%h hit=%0b", address, write_data, hit);
        check(hit == 1'b0, "Expected write-allocate miss at 0x00000200");

        // READ 0x200 (hit with data)
        @(posedge clk); address = 32'h0000_0200; read_en = 1;
        @(negedge clk); read_en = 0; #1;
        $display("READ 0x%h hit=%0b data=0x%h", address, hit, read_data);
        check((hit == 1'b1) && (read_data == 32'hDEAD_BEEF), "Expected hit+DEAD_BEEF at 0x00000200");

        #10;
        $display("SIMULATION PASSED");
        $finish;
    end
endmodule
