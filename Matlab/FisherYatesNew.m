
function Randomized_Image = FisherYatesNew(Whitened_Image, Y_key)
    % Fisher–Yates Image Encryption (Pixel + Block shuffle)
    [H0, W0] = size(Whitened_Image);
    block_size = 16;

    % Ensure dimensions are multiples of block size
    H = floor(H0/block_size) * block_size;
    W = floor(W0/block_size) * block_size;
    Whitened_Image = Whitened_Image(1:H, 1:W);

    Randomized_Image = zeros(H, W, 'uint8');
    num_blocks_y = H / block_size;
    num_blocks_x = W / block_size;
    total_blocks = num_blocks_y * num_blocks_x;

    % STEP 1: Pixel-level shuffling inside each block
    key_idx = block_size * block_size + 1; % skip first 256 values for block shuffle
    Temp_Image = zeros(H, W, 'uint8');

    for by = 1:block_size:H
        for bx = 1:block_size:W
            block = Whitened_Image(by:by+block_size-1, bx:bx+block_size-1);
            flat = reshape(block, 1, block_size*block_size);

            klen = length(Y_key);
            key_indices = mod(key_idx:key_idx+block_size*block_size-1, klen);
            key_indices(key_indices == 0) = klen;
            key_chunk = Y_key(key_indices);

            n = block_size * block_size;
            shuffled = flat;

            for i = n:-1:2
                kv = min(max(key_chunk(n - i + 1), 0), 0.9999999999);
                swap_pos = mod(uint32(floor(kv * 1e14)), i) + 1;

                tmp = shuffled(i);
                shuffled(i) = shuffled(swap_pos);
                shuffled(swap_pos) = tmp;
            end

            Temp_Image(by:by+block_size-1, bx:bx+block_size-1) = ...
                reshape(shuffled, block_size, block_size);
            key_idx = key_idx + block_size*block_size;
        end
    end

    % STEP 2: Block-level shuffling using first 256 key values
    block_key = Y_key(1:block_size*block_size);
    block_indices = 1:total_blocks;
    for i = total_blocks:-1:2
        kv = min(max(block_key(total_blocks - i + 1), 0), 0.9999999999);
        swap_pos = mod(uint32(floor(kv * 1e14)), i) + 1;

        tmp = block_indices(i);
        block_indices(i) = block_indices(swap_pos);
        block_indices(swap_pos) = tmp;
    end

    % STEP 3: Rearrange blocks according to shuffled indices
    for idx = 1:total_blocks
        orig_block_idx = idx - 1;
        orig_by = floor(orig_block_idx / num_blocks_x) * block_size + 1;
        orig_bx = mod(orig_block_idx, num_blocks_x) * block_size + 1;

        shuffled_block_idx = block_indices(idx) - 1;
        shuffled_by = floor(shuffled_block_idx / num_blocks_x) * block_size + 1;
        shuffled_bx = mod(shuffled_block_idx, num_blocks_x) * block_size + 1;

        Randomized_Image(orig_by:orig_by+block_size-1, orig_bx:orig_bx+block_size-1) = ...
            Temp_Image(shuffled_by:shuffled_by+block_size-1, shuffled_bx:shuffled_bx+block_size-1);
    end
end
