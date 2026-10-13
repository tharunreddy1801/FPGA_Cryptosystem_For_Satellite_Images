module l4_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,
    
    input signed [31:0] m3,
    input signed [31:0] l3,
    input signed [31:0] o3,
    
    output signed [31:0] l4_out
);
    
    wire signed [31:0] G_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] x_plus_m3 = x + m3;
    wire signed [31:0] y_plus_l3 = y + l3;
    wire signed [31:0] z_plus_o3 = z + o3;

   G_block G_block_inst(x_plus_m3, y_plus_l3, z_plus_o3, G_out);
    
    wire signed [63:0] h_times_g = H * G_out;
    
    assign l4_out = h_times_g  >>> 16;
    
endmodule