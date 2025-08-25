`timescale 1ns/1ps
module cache (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        read_en,
    input  logic        write_en,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic        hit
);

    localparam NSETS       = 16;
    localparam OFFSET_BITS = 2;
    localparam INDEX_BITS  = 4;
    localparam TAG_BITS    = 32 - OFFSET_BITS - INDEX_BITS;
    localparam NWAYS       = 2;

    // Address decoding
    logic [TAG_BITS-1:0]    tag;
    logic [INDEX_BITS-1:0]  index;
    logic [OFFSET_BITS-1:0] offset;
    always_comb begin
        tag    = address[31:OFFSET_BITS+INDEX_BITS];
        index  = address[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
        offset = address[OFFSET_BITS-1:0];
    end

    // Cache storage
    logic [TAG_BITS-1:0]  cache_tag   [0:NWAYS-1][0:NSETS-1];
    logic [31:0]         cache_data  [0:NWAYS-1][0:NSETS-1];
    logic                valid       [0:NWAYS-1][0:NSETS-1];
    logic                lru         [0:NSETS-1];

    // Internal signals
    logic chosen_way;
    logic w0_hit, w1_hit;
    logic [31:0] data_out;

    // Combinatorial hit detection
    always_comb begin
        w0_hit = valid[0][index] && (cache_tag[0][index] == tag);
        w1_hit = valid[1][index] && (cache_tag[1][index] == tag);
        hit = w0_hit || w1_hit;
        data_out = w0_hit ? cache_data[0][index] : (w1_hit ? cache_data[1][index] : 32'b0);
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i, w;
            for (i = 0; i < NSETS; i++) begin
                lru[i] <= 0;
                for (w = 0; w < NWAYS; w++) begin
                    valid[w][i] <= 0;
                    cache_tag[w][i] <= 0;
                    cache_data[w][i] <= 0;
                end
            end
            read_data <= 0;
        end else if (read_en || write_en) begin
            if (hit) begin
                // Hit: update LRU and read/write data
                if (w0_hit) begin
                    lru[index] <= 1'b1; // Mark way1 as LRU
                    if (write_en) cache_data[0][index] <= write_data;
                end else begin
                    lru[index] <= 1'b0; // Mark way0 as LRU
                    if (write_en) cache_data[1][index] <= write_data;
                end
            end else begin
                // Miss: choose a way to replace
                if (!valid[0][index]) chosen_way = 0;
                else if (!valid[1][index]) chosen_way = 1;
                else chosen_way = lru[index]; // Evict LRU way
                // Update chosen way
                valid[chosen_way][index] <= 1;
                cache_tag[chosen_way][index] <= tag;
                if (read_en) begin
                    cache_data[chosen_way][index] <= address; // Simulate memory fetch
                end
                if (write_en) cache_data[chosen_way][index] <= write_data;
                // Update LRU: mark the other way as LRU
                lru[index] <= (chosen_way == 0) ? 1'b1 : 1'b0;
            end
            // Register read_data to match timing
            read_data <= data_out;
        end
    end

endmodule