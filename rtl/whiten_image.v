module whiten_stream (
    input  wire clk,
    input  wire rst,

    // Input stream
    input  wire [7:0] pixel_in,
    input  wire       pixel_valid,

    // Key stream
    input  wire [7:0] key_in,
    input  wire       key_valid,

    // Output stream
    output reg  [7:0] pixel_out,
    output reg        pixel_out_valid
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_out       <= 0;
            pixel_out_valid <= 0;
        end else begin
            // Process only when both inputs are valid
            if (pixel_valid && key_valid) begin
                pixel_out       <= pixel_in ^ key_in;
                pixel_out_valid <= 1;
            end else begin
                pixel_out_valid <= 0;
            end
        end
    end

endmodule