function [NPCR, UACI] = npcr_uaci(orig_img, enc_img)
    orig_img = double(orig_img);
    enc_img  = double(enc_img);

    [rows, cols] = size(orig_img);
    N = rows * cols;

    % NPCR calculation
    D = orig_img ~= enc_img;   % 1 where pixels differ
    NPCR = sum(D(:)) / N * 100;

    % UACI calculation
    UACI = sum(abs(orig_img(:) - enc_img(:))) / (N * 255) * 100;
end
