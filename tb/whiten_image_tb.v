`timescale 1ns/1ps

module whiten_image_tb;

    reg clk;
    reg rst;

    reg [7:0] input_pixel;
    reg       input_is_valid;

    reg [7:0] key_pixel;
    reg       key_is_valid;

    wire [7:0] output_pixel;
    wire       output_is_valid;

    // DUT
    whiten_stream DUT (
        .clk(clk),
        .rst(rst),

        .pixel_in(input_pixel),
        .pixel_valid(input_is_valid),

        .key_in(key_pixel),
        .key_valid(key_is_valid),

        .pixel_out(output_pixel),
        .pixel_out_valid(output_is_valid)
    );

    //----------------------------------------
    // Clock
    //----------------------------------------
    initial clk = 1;
    always #5 clk = ~clk;

    //----------------------------------------
    // File size (256x256 grayscale BMP ? 66KB)
    //----------------------------------------
    localparam File_Size = 70 * 1024;

    //----------------------------------------
    // Memory
    //----------------------------------------
    reg [7:0] bmpdata [0:File_Size-1];
    reg [7:0] keydata [0:File_Size-1];
    reg [7:0] result  [0:File_Size-1];

    //----------------------------------------
    // BMP Header Info
    //----------------------------------------
    integer bmp_size, bmp_start_pos, bmp_width, bmp_height, bmp_bpp;
    integer i, j;

    //----------------------------------------
    // READ IMAGE BMP
    //----------------------------------------
    task READ_IMAGE;
        integer file;
        begin
            file = $fopen("gray.bmp", "rb");
            if (file == 0) begin
                $display("Error: Cannot open gray.bmp");
                $finish;
            end

            $fread(bmpdata, file);
            $fclose(file);

            bmp_size      = {bmpdata[5], bmpdata[4], bmpdata[3], bmpdata[2]};
            bmp_start_pos = {bmpdata[13], bmpdata[12], bmpdata[11], bmpdata[10]};
            bmp_width     = {bmpdata[21], bmpdata[20], bmpdata[19], bmpdata[18]};
            bmp_height    = {bmpdata[25], bmpdata[24], bmpdata[23], bmpdata[22]};
            bmp_bpp       = {bmpdata[29], bmpdata[28]};

            $display("IMAGE BMP INFO:");
            $display("Size      : %d", bmp_size);
            $display("Offset    : %d", bmp_start_pos);
            $display("Width     : %d", bmp_width);
            $display("Height    : %d", bmp_height);
            $display("BPP       : %d", bmp_bpp);

            if (bmp_bpp != 8) begin
                $display("Error: Must be 8-bit grayscale BMP");
                $finish;
            end
        end
    endtask

    //----------------------------------------
    // READ KEY BMP
    //----------------------------------------
    task READ_KEY;
        integer file;
        begin
            file = $fopen("x_key.bmp", "rb");
            if (file == 0) begin
                $display("Error: Cannot open x_key.bmp");
                $finish;
            end

            $fread(keydata, file);
            $fclose(file);
        end
    endtask

    //----------------------------------------
    // WRITE OUTPUT BMP
    //----------------------------------------
    task WRITE_FILE;
        integer file, i;
        begin
            file = $fopen("result.bmp", "wb");

            // Write header
            for (i = 0; i < bmp_start_pos; i = i + 1)
                $fwrite(file, "%c", bmpdata[i]);

            // Write pixel data
            for (i = bmp_start_pos; i < bmp_size; i = i + 1)
                $fwrite(file, "%c", result[i]);

            $fclose(file);
            $display("? Output image written!");
        end
    endtask

    //----------------------------------------
    // MAIN SIMULATION
    //----------------------------------------
    initial begin
        rst = 1;
        input_is_valid = 0;
        key_is_valid   = 0;
        input_pixel    = 0;
        key_pixel      = 0;

        READ_IMAGE;
        READ_KEY;

        #20;
        rst = 0;

        j = bmp_start_pos;

        // Copy header
        for (i = 0; i < bmp_start_pos; i = i + 1)
            result[i] = bmpdata[i];

        //----------------------------------------
        // STREAM PIXELS + KEY
        //----------------------------------------
        for (i = bmp_start_pos; i < bmp_size; i = i + 1) begin
            @(posedge clk);

            input_pixel    <= bmpdata[i];
            key_pixel      <= keydata[i];

            input_is_valid <= 1;
            key_is_valid   <= 1;
        end

        @(posedge clk);
        input_is_valid <= 0;
        key_is_valid   <= 0;

        #100;
        WRITE_FILE;

        #10;
        $stop;
    end

    //----------------------------------------
    // STORE OUTPUT
    //----------------------------------------
    always @(posedge clk) begin
        if (rst)
            j <= bmp_start_pos;
        else if (output_is_valid) begin
            result[j] <= output_pixel;
            j <= j + 1;
        end
    end

endmodule
