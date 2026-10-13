module p1_block (
    input signed [31:0] y,
    input signed [31:0] z,
    input signed [31:0] w,
    
    output signed [31:0] p1_out
);
    
    wire signed [31:0] S_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16

    S_block S_block(y, z, w, S_out);
    
    wire signed [63:0] h_times_s;
    assign h_times_s  = H * S_out;
    
    assign p1_out = h_times_s  >>> 16;
    

endmodule