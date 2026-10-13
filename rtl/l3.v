module l3_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,
    
    input signed [31:0] m2,
    input signed [31:0] l2,
    input signed [31:0] o2,
    
    output signed [31:0] l3_out
);
    
    wire signed [31:0] G_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] m2_shifted = m2 >>> 1;
    wire signed [31:0] l2_shifted = l2 >>> 1;
    wire signed [31:0] o2_shifted = o2 >>> 1;
    
    wire signed [31:0] x_plus_m2_shifted = x + m2_shifted;
    wire signed [31:0] y_plus_l2_shifted = y + l2_shifted;
    wire signed [31:0] z_plus_o2_shifted = z + o2_shifted;

   G_block G_block_inst(x_plus_m2_shifted, y_plus_l2_shifted, z_plus_o2_shifted, G_out);
    
    wire signed [63:0] h_times_g = H * G_out;
    
    assign l3_out = h_times_g  >>> 16;
    
endmodule