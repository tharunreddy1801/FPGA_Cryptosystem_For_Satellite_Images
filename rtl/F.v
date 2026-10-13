module F_block (
    input  signed [31:0] x,
    input  signed [31:0] y,
    input  signed [31:0] w,
    output signed [31:0] F_out
);

    wire signed [31:0] y_minus_x;
    wire signed [31:0] alpha_times;

    assign y_minus_x = y - x;

    // 35 = 32 + 2 + 1
    assign alpha_times =
            (y_minus_x <<< 5) +   // ×32
            (y_minus_x <<< 1) +   // ×2
             y_minus_x;           // ×1

    assign F_out = alpha_times + w;

endmodule