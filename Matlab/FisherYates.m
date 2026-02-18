function Randomized_Image = FisherYates(Whitened_Image, Y_key)
    [H, W] = size(Whitened_Image);
    block_size = 16;
    Randomized_Image = zeros(H, W, 'uint8');
    key_idx = 1;
    
    % Process each 16x16 block
    for by = 1:block_size:H
        for bx = 1:block_size:W
            % Extract current block
            block = Whitened_Image(by:by+block_size-1, bx:bx+block_size-1);
            
            % Flatten the block to 1D array (256 pixels)
            flattened_block = reshape(block, 1, block_size*block_size);
            
            % Take 256 values from Y_key for this block
            key_chunk = Y_key(key_idx:key_idx+block_size*block_size-1);
            
            % Perform Fisher-Yates shuffle on this block
            shuffled_block = flattened_block;
            for i = block_size*block_size:-1:2
                % Map key value to valid swap position [1, i]
                swap_pos = mod(floor(key_chunk(block_size*block_size - i + 1) * 1e14), i) + 1;
                
                % Swap elements
                [shuffled_block(i), shuffled_block(swap_pos)] = swapValues(shuffled_block(i), shuffled_block(swap_pos));
            end
            
            % Reshape back to 16x16 and store in output image
            Randomized_Image(by:by+block_size-1, bx:bx+block_size-1) = ...
                reshape(shuffled_block, block_size, block_size);
            
            % Advance key index for next block
            key_idx = key_idx + block_size*block_size;
        end
    end
end