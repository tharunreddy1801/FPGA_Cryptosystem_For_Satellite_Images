module m2_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] w,
    
    input signed [31:0] m1,
    input signed [31:0] l1,
    input signed [31:0] p1,
    
    output signed [31:0] m2_out
);
    
    wire signed [31:0] F_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] m1_shifted = m1 >>> 1;
    wire signed [31:0] l1_shifted = l1 >>> 1;
    wire signed [31:0] p1_shifted = p1 >>> 1;
    
    wire signed [31:0] x_plus_m1_shifted = x + m1_shifted;
    wire signed [31:0] y_plus_l1_shifted = y + l1_shifted;
    wire signed [31:0] w_plus_p1_shifted = w + p1_shifted;

    F_block F_block_inst(x_plus_m1_shifted, y_plus_l1_shifted, w_plus_p1_shifted, F_out);
    
    wire signed [63:0] h_times_f = H * F_out;
    
    assign m2_out = h_times_f  >>> 16;
    
endmodule