module R ( 
    input  signed [31:0] x,
    input  signed [31:0] y,
    input  signed [31:0] z,
    output signed [31:0] R_out
);

    wire signed [63:0] mult_full;
    wire signed [31:0] x_times_y;
    wire signed [31:0] beta_times_z;

    assign mult_full   = x * y;         
    assign x_times_y   = mult_full >>> 16;  // Q16.16

    assign beta_times_z = z + (z <<< 1);    // 3*z

    assign R_out = x_times_y - beta_times_z;

endmodule