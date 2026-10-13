module m3_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] w,
    
    input signed [31:0] m2,
    input signed [31:0] l2,
    input signed [31:0] p2,
    
    output signed [31:0] m3_out
);
    
    wire signed [31:0] F_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] m2_shifted = m2 >>> 1;
    wire signed [31:0] l2_shifted = l2 >>> 1;
    wire signed [31:0] p2_shifted = p2 >>> 1;
    
    wire signed [31:0] x_plus_m2_shifted = x + m2_shifted;
    wire signed [31:0] y_plus_l2_shifted = y + l2_shifted;
    wire signed [31:0] w_plus_p2_shifted = w + p2_shifted;

    F_block F_block_inst(x_plus_m2_shifted, y_plus_l2_shifted, w_plus_p2_shifted, F_out);
    
    wire signed [63:0] h_times_f = H * F_out;
    
    assign m3_out = h_times_f  >>> 16;
    
endmodule