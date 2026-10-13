module Chen4D (
    input  wire        clk,
    input  wire        rst,

    input  signed [31:0] m1, m2, m3, m4,
    input  signed [31:0] l1, l2, l3, l4,
    input  signed [31:0] o1, o2, o3, o4,
    input  signed [31:0] p1, p2, p3, p4,

    output reg  [7:0]  X_key,
    output reg  [7:0]  Y_key,
    output reg  [7:0]  Z_key,
    output reg  [7:0]  W_key,

    output reg         key_valid
);

    reg signed [31:0] X, Y, Z, W;

    reg [16:0] counter;   // count first 20k values for discarding

    wire signed [33:0] X_sum = 
          m1 
        + (m2 <<< 1)
        + (m3 <<< 1)
        + m4;

    wire signed [33:0] Y_sum = 
          l1 
        + (l2 <<< 1)
        + (l3 <<< 1)
        + l4;

    wire signed [33:0] Z_sum = 
          o1 
        + (o2 <<< 1)
        + (o3 <<< 1)
        + o4;

    wire signed [33:0] W_sum = 
          p1 
        + (p2 <<< 1)
        + (p3 <<< 1)
        + p4;

    // Divide by 6 
    wire signed [31:0] X_delta = X_sum / 6;
    wire signed [31:0] Y_delta = Y_sum / 6;
    wire signed [31:0] Z_delta = Z_sum / 6;
    wire signed [31:0] W_delta = W_sum / 6;
    
    // Remove sign
    wire [31:0] X_abs = X[31] ? -X : X;
    wire [31:0] Y_abs = Y[31] ? -Y : Y;
    wire [31:0] Z_abs = Z[31] ? -Z : Z;
    wire [31:0] W_abs = W[31] ? -W : W;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            X <= 0;
            Y <= 0;
            Z <= 0;
            W <= 0;
            counter <= 0;
            key_valid <= 0;
        end
        else begin

            X <= X + X_delta;
            Y <= Y + Y_delta;
            Z <= Z + Z_delta;
            W <= W + W_delta;

            counter <= counter + 1;

            if (counter >= 20000) begin
                key_valid <= 1;

                X_key <= X_abs[7:0];
                Y_key <= Y_abs[7:0];
                Z_key <= Z_abs[7:0];
                W_key <= W_abs[7:0];

            end
            else begin
                key_valid <= 0;
            end
        end
    end

endmodule