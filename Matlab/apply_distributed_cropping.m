%% === HELPER FUNCTION: Pixel-wise Distributed Cropping ===
function cropped_image = apply_distributed_cropping(cipher_image, crop_ratio)
    % Apply evenly distributed cropping attack
    
    [h, w] = size(cipher_image);
    total_pixels = h * w;
    
    % Calculate number of pixels to crop
    num_pixels_to_crop = round(total_pixels * crop_ratio);
    
    % Create a copy of the cipher image
    cropped_image = cipher_image;
    
    % Generate random pixel positions
    rng('shuffle'); % Use random seed for different patterns each time
    % rng(42); % Use fixed seed for reproducible results
    
    all_positions = randperm(total_pixels);
    positions_to_crop = all_positions(1:num_pixels_to_crop);
    
    % Convert linear indices to subscripts
    [rows, cols] = ind2sub([h, w], positions_to_crop);
    
    % Set selected pixels to 0 (black) - simulating data loss
    linear_indices = sub2ind([h, w], rows, cols);
    cropped_image(linear_indices) = 0;
end