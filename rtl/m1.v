module m1_block (
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] w,
    
    output signed [31:0] m1_out
);
    
    wire signed [31:0] F_out;
    
    localparam signed [31:0] H = 32'sd655;   // 0.01 in Q16.16

    F_block F_block(x, y, w, F_out);
    
    wire signed [63:0] h_times_f = H * F_out;
    
    assign m1_out = h_times_f  >>> 16;
    
endmodule