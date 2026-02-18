function cropped_image = apply_block_distributed_cropping(cipher_image, crop_ratio, block_size)
    % Apply cropping in small distributed blocks
    
    if nargin < 3
        block_size = 8; % Default block size
    end
    
    [h, w] = size(cipher_image);
    cropped_image = cipher_image;
    
    % Calculate total blocks
    num_blocks_h = floor(h / block_size);
    num_blocks_w = floor(w / block_size);
    total_blocks = num_blocks_h * num_blocks_w;
    
    % Calculate number of blocks to crop
    num_blocks_to_crop = round(total_blocks * crop_ratio);
    
    % Randomly select blocks
    rng('shuffle'); % Random seed
    all_block_indices = randperm(total_blocks);
    blocks_to_crop = all_block_indices(1:num_blocks_to_crop);
    
    % Crop selected blocks
    for i = 1:num_blocks_to_crop
        block_idx = blocks_to_crop(i) - 1; % Convert to 0-based
        block_row = floor(block_idx / num_blocks_w) * block_size + 1;
        block_col = mod(block_idx, num_blocks_w) * block_size + 1;
        
        % Calculate block boundaries
        row_end = min(block_row + block_size - 1, h);
        col_end = min(block_col + block_size - 1, w);
        
        % Set block to black (simulating data loss)
        cropped_image(block_row:row_end, block_col:col_end) = 0;
    end
end