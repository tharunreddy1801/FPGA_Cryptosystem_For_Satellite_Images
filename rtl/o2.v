module o2_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,
    
    input signed [31:0] m1,
    input signed [31:0] l1,
    input signed [31:0] o1,
    
    output signed [31:0] o2_out
);
    
    wire signed [31:0] R_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] m1_shifted = m1 >>> 1;
    wire signed [31:0] l1_shifted = l1 >>> 1;
    wire signed [31:0] o1_shifted = o1 >>> 1;
    
    wire signed [31:0] x_plus_m1_shifted = x + m1_shifted;
    wire signed [31:0] y_plus_l1_shifted = y + l1_shifted;
    wire signed [31:0] z_plus_o1_shifted = z + o1_shifted;

   R_block R_block_inst(x_plus_m1_shifted, y_plus_l1_shifted, z_plus_o1_shifted, R_out);
    
    wire signed [63:0] h_times_r = H * R_out;
    
    assign o2_out = h_times_r  >>> 16;
    
endmodule