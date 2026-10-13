module o1_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,
    
    output signed [31:0] o1_out
);
    
    wire signed [31:0] R_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16

    R_block R_block(x, y, z, R_out);
    
    wire signed [63:0] h_times_r = H * R_out;
    
    assign o1_out = h_times_r  >>> 16;
    
endmodule