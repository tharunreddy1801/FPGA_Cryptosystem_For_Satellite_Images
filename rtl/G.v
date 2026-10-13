module G( 
    input signed [31:0] x,
    input signed [31:0] y,
    input signed [31:0] z,

    output signed [31:0] G_out
);
 
    // gamma = 28 (32-4)
    // eps = 12 (8+4)
    
    wire signed [31:0] gamma_times_x = (x <<< 5) - (x <<< 2);
    wire signed [31:0] epsilon_times_y = (y <<< 3) + (y <<< 2);
    
    wire signed [63:0] mult_full;
    wire signed [31:0] x_times_z;

    assign mult_full  = x * z;          // Q32.32
    assign x_times_z  = mult_full >>> 16;  // Q16.16
    
    assign G_out = gamma_times_x - x_times_z + epsilon_times_y;

endmodule 