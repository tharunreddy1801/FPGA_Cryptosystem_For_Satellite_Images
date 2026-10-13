module m4_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] w,
    
    input signed [31:0] m3,
    input signed [31:0] l3,
    input signed [31:0] p3,
    
    output signed [31:0] m4_out
);
    
    wire signed [31:0] F_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16
    
    wire signed [31:0] x_plus_m3 = x + m3;
    wire signed [31:0] y_plus_l3 = y + l3;
    wire signed [31:0] w_plus_p3 = w + p3;

    F_block F_block_inst(x_plus_m3, y_plus_l3, w_plus_p3, F_out);
    
    wire signed [63:0] h_times_f = H * F_out;
    
    assign m4_out = h_times_f  >>> 16;
    
endmodule