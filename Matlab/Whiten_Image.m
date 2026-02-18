function Whitened_Image = Whiten_Image(X_key, Input_Image)
    [H, W] = size(Input_Image);
    block_size = 16;
    Whitened_Image = zeros(H, W, 'uint8');
    key_idx = 1;
    
    % Process each 16x16 block
    for by = 1:block_size:H
        for bx = 1:block_size:W
            % Extract current block
            block = Input_Image(by:by+block_size-1, bx:bx+block_size-1);
            
            % Flatten the block to 1D array (256 pixels)
            flattened_block = reshape(block, 1, block_size*block_size);
            
            % Take 256 values from X_key for this block
            key_chunk = X_key(key_idx:key_idx+block_size*block_size-1);
            
            % Perform XOR operation on this block
            whitened_block = bitxor(flattened_block, key_chunk);
            
            % Reshape back to 16x16 and store in output image
            Whitened_Image(by:by+block_size-1, bx:bx+block_size-1) = ...
                reshape(whitened_block, block_size, block_size);
            
            % Advance key index for next block
            key_idx = key_idx + block_size*block_size;
        end
    end
end