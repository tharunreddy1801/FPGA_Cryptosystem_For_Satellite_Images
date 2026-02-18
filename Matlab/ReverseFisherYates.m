function Restored_Image = ReverseFisherYates(Randomized_Image, Y_key)
    [H, W] = size(Randomized_Image);
    block_size = 16;
    Restored_Image = zeros(H, W, 'uint8');
    key_idx = 1;

    % Process each 16x16 block (same order as encryption)
    for by = 1:block_size:H
        for bx = 1:block_size:W
            % Extract current block
            block = Randomized_Image(by:by+block_size-1, bx:bx+block_size-1);

            % Flatten the block
            flattened_block = reshape(block, 1, block_size*block_size);

            % Take the same key chunk used in encryption
            key_chunk = Y_key(key_idx:key_idx+block_size*block_size-1);

            % ----------- Reverse Fisher–Yates Shuffle -----------
            % Must undo swaps in reverse order of encryption
            for i = 2:block_size*block_size
                % Recompute same swap position
                swap_pos = mod(floor(key_chunk(block_size*block_size - i + 1) * 1e14), i) + 1;

                % Undo swap
                [flattened_block(i), flattened_block(swap_pos)] = swapValues(flattened_block(i), flattened_block(swap_pos));
            end

            % Reshape back to 16×16
            Restored_Image(by:by+block_size-1, bx:bx+block_size-1) = ...
                reshape(flattened_block, block_size, block_size);

            % Move key index forward
            key_idx = key_idx + block_size*block_size;
        end
    end
end