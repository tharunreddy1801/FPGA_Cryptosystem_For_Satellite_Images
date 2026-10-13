module S (
    input  signed [31:0] y,
    input  signed [31:0] z,
    input  signed [31:0] w,
    output signed [31:0] S_out
);

    wire signed [63:0] mult_full;
    wire signed [31:0] y_times_z;

    assign mult_full  = y * z;        // Q32.32
    assign y_times_z  = mult_full >>> 16;  // Q16.16

    wire signed [31:0] lambda_times_w;
    assign lambda_times_w = w >>> 1;  // w*0.5

    assign S_out = y_times_z + lambda_times_w;

endmodule