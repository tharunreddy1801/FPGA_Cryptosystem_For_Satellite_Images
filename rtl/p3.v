module p3_block (
    input signed [31:0] y,
    input signed [31:0] z,
    input signed [31:0] w,
    
    input signed [31:0] l2,
    input signed [31:0] o2,
    input signed [31:0] p2,
    
    output signed [31:0] p3_out
);
    
    wire signed [31:0] S_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] l2_shifted = l2 >>> 1; // divide by 2
    wire signed [31:0] o2_shifted = o2 >>> 1;
    wire signed [31:0] p2_shifted = p2 >>> 1;
    
    wire signed [31:0] y_plus_l2_shifted = y + l2_shifted;
    wire signed [31:0] z_plus_o2_shifted = z + o2_shifted;
    wire signed [31:0] w_plus_p2_shifted = w + p2_shifted;

   S_block S_block_inst(y_plus_l2_shifted, z_plus_o2_shifted, w_plus_p2_shifted, S_out);
    
    wire signed [63:0] h_times_s = H * S_out;
    
    assign p3_out = h_times_s  >>> 16;
    
endmodule