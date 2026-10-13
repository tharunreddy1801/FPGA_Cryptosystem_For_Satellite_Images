module p4_block (
    input signed [31:0] y,
    input signed [31:0] z,
    input signed [31:0] w,
    
    input signed [31:0] l3,
    input signed [31:0] o3,
    input signed [31:0] p3,
    
    output signed [31:0] p4_out
);
    
    wire signed [31:0] S_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] y_plus_l3 = y + l3;
    wire signed [31:0] z_plus_o3 = z + o3;
    wire signed [31:0] w_plus_p3 = w + p3;

   S_block S_block_inst(y_plus_l3, z_plus_o3, w_plus_p3, S_out);
    
    wire signed [63:0] h_times_s = H * S_out;
    
    assign p4_out = h_times_s  >>> 16;
    
endmodule