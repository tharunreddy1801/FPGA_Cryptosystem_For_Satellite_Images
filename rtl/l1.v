module l1_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,
    
    output signed [31:0] l1_out
);
    
    wire signed [31:0] G_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16

    G_block G_block(x, y, z, G_out);
    
    wire signed [63:0] h_times_g = H * G_out;
    
    assign l1_out = h_times_g  >>> 16;
    
endmodule