clc; clear; close all;

% --- Generate sample input data ---
H = 256; W = 256;                  % Image dimensions
Randomized_Image = randi([0 1], H, W, 'uint8');  % Random binary image (1-bit pixels)
Z_Key = randi([0 1], 1, H*W);    % Random binary key of same total length

% --- Call your encoding function ---
Encoded_Image = RNA_Encoding(Randomized_Image, Z_Key);

decoded = RNA_Decoding(Encoded_Image, Z_Key);

isequal(decoded, Encoded_Image)