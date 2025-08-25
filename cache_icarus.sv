`timescale 1ns/1ps
module cache (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        read_en,
    input  wire        write_en,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data,
    output wire        hit
);

    // Parameters
    localparam NSETS       = 16;
    localparam OFFSET_BITS = 2;
    localparam INDEX_BITS  = 4;
    localparam TAG_BITS    = 32 - OFFSET_BITS - INDEX_BITS;
    localparam NWAYS       = 2;

    // Address decoding
    wire [TAG_BITS-1:0]   tag;
    wire [INDEX_BITS-1:0] index;
    wire [OFFSET_BITS-1:0] offset;

    assign tag    = address[31:OFFSET_BITS+INDEX_BITS];
    assign index  = address[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    assign offset = address[OFFSET_BITS-1:0];

    // Storage
    reg  [TAG_BITS-1:0] cache_tag  [0:NWAYS-1][0:NSETS-1];
    reg  [31:0]         cache_data [0:NWAYS-1][0:NSETS-1];
    reg                 valid      [0:NWAYS-1][0:NSETS-1];
    reg                 lru        [0:NSETS-1];

    // Internal
    reg        w0_hit, w1_hit;
    reg [31:0] data_out;
    reg        chosen_way;  // 0 or 1

    // Combinational hit detection
    always @* begin
        w0_hit   = valid[0][index] && (cache_tag[0][index] == tag);
        w1_hit   = valid[1][index] && (cache_tag[1][index] == tag);
        data_out = w0_hit ? cache_data[0][index] :
                   (w1_hit ? cache_data[1][index] : 32'b0);
    end

    assign hit = w0_hit | w1_hit;

    integer i, w;

    // Sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NSETS; i = i + 1) begin
                lru[i] <= 1'b0;
                for (w = 0; w < NWAYS; w = w + 1) begin
                    valid[w][i]      <= 1'b0;
                    cache_tag[w][i]  <= {TAG_BITS{1'b0}};
                    cache_data[w][i] <= 32'b0;
                end
            end
            read_data <= 32'b0;
        end else if (read_en || write_en) begin
            if (w0_hit || w1_hit) begin
                // Hit path
                if (w0_hit) begin
                    lru[index] <= 1'b1; // way1 becomes LRU
                    if (write_en) cache_data[0][index] <= write_data;
                end else begin
                    lru[index] <= 1'b0; // way0 becomes LRU
                    if (write_en) cache_data[1][index] <= write_data;
                end
            end else begin
                // Miss path
                if (!valid[0][index])      chosen_way = 1'b0;
                else if (!valid[1][index]) chosen_way = 1'b1;
                else                        chosen_way = lru[index]; // evict LRU

                valid[chosen_way][index]     <= 1'b1;
                cache_tag[chosen_way][index] <= tag;

                if (read_en)  cache_data[chosen_way][index] <= address;    // simulate memory fetch
                if (write_en) cache_data[chosen_way][index] <= write_data;

                // mark the other way as LRU
                lru[index] <= (chosen_way == 1'b0) ? 1'b1 : 1'b0;
            end

            // align timing
            read_data <= data_out;
        end
    end
endmodule
