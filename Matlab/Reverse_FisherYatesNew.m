
function Original_Image = Reverse_FisherYatesNew(Randomized_Image, Y_key)
    % Fisher–Yates Image Decryption (Reverse of FisherYatesNew)
    [H0, W0] = size(Randomized_Image);
    block_size = 16;

    % Crop image to exact multiple of block size
    H = floor(H0/block_size) * block_size;
    W = floor(W0/block_size) * block_size;
    Randomized_Image = Randomized_Image(1:H, 1:W);

    num_blocks_y = H / block_size;
    num_blocks_x = W / block_size;
    total_blocks = num_blocks_y * num_blocks_x;

    % STEP 1: Reverse block-level shuffling
    block_key = Y_key(1:block_size*block_size);
    block_order = 1:total_blocks;
    for i = total_blocks:-1:2
        kv = min(max(block_key(total_blocks - i + 1), 0), 0.9999999999);
        swap_pos = mod(uint32(floor(kv * 1e14)), i) + 1;

        tmp = block_order(i);
        block_order(i) = block_order(swap_pos);
        block_order(swap_pos) = tmp;
    end

    % Build reverse lookup table
    reverse_order = zeros(1, total_blocks);
    for j = 1:total_blocks
        reverse_order(block_order(j)) = j;
    end

    Temp_Image = zeros(H, W, 'uint8');
    for orig_block_num = 1:total_blocks
        shuffled_position = reverse_order(orig_block_num);

        shuffled_idx = shuffled_position - 1;
        shuffled_by = floor(shuffled_idx / num_blocks_x) * block_size + 1;
        shuffled_bx = mod(shuffled_idx, num_blocks_x) * block_size + 1;

        orig_idx = orig_block_num - 1;
        orig_by = floor(orig_idx / num_blocks_x) * block_size + 1;
        orig_bx = mod(orig_idx, num_blocks_x) * block_size + 1;

        Temp_Image(orig_by:orig_by+block_size-1, orig_bx:orig_bx+block_size-1) = ...
            Randomized_Image(shuffled_by:shuffled_by+block_size-1, shuffled_bx:shuffled_bx+block_size-1);
    end

    % STEP 2: Reverse pixel-level Fisher–Yates shuffle inside each block
    Original_Image = zeros(H, W, 'uint8');
    key_idx = block_size * block_size + 1;

    for by = 1:block_size:H
        for bx = 1:block_size:W
            block = Temp_Image(by:by+block_size-1, bx:bx+block_size-1);
            shuffled_pixels = reshape(block, 1, block_size*block_size);

            klen = length(Y_key);
            key_indices = mod(key_idx:key_idx+block_size*block_size-1, klen);
            key_indices(key_indices == 0) = klen;
            key_chunk = Y_key(key_indices);

            n = block_size * block_size;
            swaps = zeros(n-1, 2, 'uint32');
            for i = n:-1:2
                kv = min(max(key_chunk(n - i + 1), 0), 0.9999999999);
                swap_pos = mod(uint32(floor(kv * 1e14)), i) + 1;
                swaps(n - i + 1, :) = uint32([i, swap_pos]);
            end

            original_pixels = shuffled_pixels;
            for k = (n-1):-1:1
                i = swaps(k, 1);
                j = swaps(k, 2);
                tmp = original_pixels(i);
                original_pixels(i) = original_pixels(j);
                original_pixels(j) = tmp;
            end

            Original_Image(by:by+block_size-1, bx:bx+block_size-1) = ...
                reshape(original_pixels, block_size, block_size);

            key_idx = key_idx + block_size*block_size;
        end
    end

    % Final cleanup & clipping to [0,255]
    Original_Image = double(Original_Image);
    Original_Image = max(min(Original_Image, 255), 0);
    Original_Image = uint8(Original_Image);

end
