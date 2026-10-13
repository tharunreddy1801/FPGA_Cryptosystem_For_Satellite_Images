module p2_block (
    input signed [31:0] y,
    input signed [31:0] z,
    input signed [31:0] w,
    
    input signed [31:0] l1,
    input signed [31:0] o1,
    input signed [31:0] p1,
    
    output signed [31:0] p2_out
);
    
    wire signed [31:0] S_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] l1_shifted = l1 >>> 1;
    wire signed [31:0] o1_shifted = o1 >>> 1;
    wire signed [31:0] p1_shifted = p1 >>> 1;
    
    wire signed [31:0] y_plus_l1_shifted = y + l1_shifted;
    wire signed [31:0] z_plus_o1_shifted = z + o1_shifted;
    wire signed [31:0] w_plus_p1_shifted = w + p1_shifted;

   S_block S_block_inst(y_plus_l1_shifted, z_plus_o1_shifted, w_plus_p1_shifted, S_out);
    
    wire signed [63:0] h_times_s = H * S_out;
    
    assign p2_out = h_times_s  >>> 16;
    
endmodule