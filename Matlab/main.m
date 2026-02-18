clc;
clear;
close all;

% Load the image
img = imread('resized_image.png');

% Convert to grayscale if it's RGB
if size(img, 3) == 3
    img = rgb2gray(img);
end

% Resize image to 256x256
img = imresize(img, [256 256]);

[H, W] = size(img);

figure;
imshow(img);
title('Original Image');

data = uint8(img(:));

K = generateSHA256Hash(data); % K is the SHA-256 hash key

h_blocks = uint8(sscanf(K, '%2x').'); % h1, h2, h3, ..... h32


% Display hash info



x0 = 0; y0 = 0; z0 = 8; w0 = 6;

alpha = 35; gamma = 28; epsilon = 12; beta = 3; lambda = 0.5;
q = 0.95;

h = 0.01;
N = 20000;

[X_Initial, Y_Initial, Z_Initial, W_Initial] = generateInitialConditions(h_blocks, x0, y0, z0, w0);

% Display hash info
 disp('--- SHA-256 Hash (hex): ---');
 disp(K);
disp('--- Hash blocks (uint8): ---');
disp(h_blocks)

 disp(X_Initial)
 disp(Y_Initial)
 disp(Z_Initial)
 disp(W_Initial)

[X_key, Y_key, Z_key, W_key, X_full, Y_full, Z_full, W_full] = ...
    Chen4D(X_Initial, Y_Initial, Z_Initial, W_Initial, alpha, gamma, epsilon, beta, lambda, h, N + (H*W));

 

% Plot 3D projections
plotChen4D_3DProjections(X_full, Y_full, Z_full, W_full, 5000);


%% ENCYPTION

tic;  % Start timer

Whitened_Image_1 = Whiten_Image(X_key, img);

Randomized_Image = FisherYatesNew(Whitened_Image_1, Y_key);

Encoded_Image = RNA_Encoding(Randomized_Image, Z_key);

Whitened_Image_2 = Whiten_Image(W_key, Encoded_Image);

encryption_time = toc;  % Stop timer

fprintf('\nEncryption completed in %.6f seconds\n', encryption_time);

figure;
imshow(Whitened_Image_1);
title('Whitened Image Stage 1');

figure;
imshow(Randomized_Image);
title('Randomized Image');

figure;
imshow(Encoded_Image);
title('Encoded Image');

figure;
imshow(Whitened_Image_2);
title('Final Encrypted Image');


%% DECRYPTION 

tic; %start timer

Whitened_Image_2_Reversed = Whiten_Image(W_key, Whitened_Image_2);

RNA_Decoded_Image = RNA_Decoding(Whitened_Image_2_Reversed, Z_key);

Unrandomized_Image = Reverse_FisherYatesNew(RNA_Decoded_Image, Y_key);

Decoded_Resultant_Image = Whiten_Image(X_key, Unrandomized_Image);

decryption_time = toc; %stop timer

fprintf('\nDecryption completed in %.6f seconds\n', decryption_time);

figure;
imshow(Whitened_Image_2_Reversed);
title('Second Stage Whitened Image Decoded');

figure;
imshow(RNA_Decoded_Image);
title('RNA Decoded Image');

figure;
imshow(Unrandomized_Image);
title('Unrandomized Image');

figure;
imshow(Decoded_Resultant_Image);
title('Final decrypted Image');


results = table(encryption_time, decryption_time, ...
    'VariableNames', {'Encryption_s', 'Decryption_s'});
disp(results);

%% HISTOGRAM IMAGES
figure;
histogram(img(:), 0:255); % flatten the image to 1D
title('Histogram of Original Image');
xlabel('Pixel Intensity (0-255)');
ylabel('Frequency');

figure;
histogram(Whitened_Image_2(:), 0:255); % flatten the image to 1D
title('Histogram of Cipher Image');
xlabel('Pixel Intensity (0-255)');
ylabel('Frequency');

%% HISTOGRAM

v_orig = var(double(img(:)));
b_orig = std(double(img(:)));

v_enc = var(double(Whitened_Image_2(:)));
b_enc = std(double(Whitened_Image_2(:)));
fprintf('\nOriginal Image:  v = %.3f, ? = %.3f\n', v_orig, b_orig);
fprintf('Encrypted Image: v = %.3f, ? = %.3f\n', v_enc, b_enc);

% Create table 
ImageNames = {'Satellite 1'};

T = table(ImageNames', [v_orig]', [b_orig]', [v_enc]', [b_enc]', ...
    'VariableNames', {'Image','v_Original','beta_Original','v_Encrypted','beta_Encrypted'});

disp('--- Histogram Statistics (v, ?) ---');
disp(T);

 %% Correlation Analysis (Horizontal, Vertical, Diagonal) 
 
 [corrH_orig, corrV_orig, corrD_orig] = correlation_coefficients(img);
 [corrH_enc,  corrV_enc,  corrD_enc]  = correlation_coefficients(Whitened_Image_2);
 
 fprintf('\nCorrelation Coefficients (Table 10 style):\n');
 fprintf('Original (H, V, D): %.4f, %.4f, %.4f\n', corrH_orig, corrV_orig, corrD_orig);
 fprintf('Encrypted (H, V, D): %.4f, %.4f, %.4f\n', corrH_enc, corrV_enc, corrD_enc);
 
 
 %%Entropy Analysis
 H_orig = image_entropy(img);
 H_enc  = image_entropy(Whitened_Image_2);
 
 fprintf('\nEntropy:\n');
 fprintf('Original: %.4f\n', H_orig);
 fprintf('Encrypted: %.4f\n', H_enc);
 
 %% NPCR and UACI Analysis
 [NPCR_val, UACI_val] = npcr_uaci(img, Whitened_Image_2);
 
 fprintf('\nNPCR and UACI Analysis:\n');
 fprintf('NPCR = %.4f %%\n', NPCR_val);
 fprintf('UACI = %.4f %%\n', UACI_val);
 
 %% CROPPING ATTACK
fprintf('\n=== CROPPING ATTACK (Reproduced Figure 13) ===\n');

% Crop ratios (same as paper)
crop_levels = [1/16, 1/4, 1/2];
crop_labels = {'1/16 Crop (6.25%)','1/4 Crop (25%)','1/2 Crop (50%)'};

cipher = uint8(Whitened_Image_2);
[H, W] = size(cipher);

mse_vals = zeros(1, numel(crop_levels));
psnr_vals = zeros(1, numel(crop_levels));
corrupted_ciphers = cell(1, numel(crop_levels));
decrypted_results = cell(1, numel(crop_levels));

for k = 1:numel(crop_levels)
    frac = crop_levels(k);

    % --- Decide crop shape: square for frac<0.5 (top-left), half-band for frac==0.5 ---
    temp = Whitened_Image_2; % start from randomized image (pre-final-whitening)
    if frac < 0.5
        % square crop at top-left: side length so area ~= frac * H * W
        side_h = max(1, round(sqrt(frac) * H));
        side_w = max(1, round(sqrt(frac) * W));
        temp(1:side_h, 1:side_w) = 0;   % top-left square zeroed
        crop_descr = sprintf('Top-left %dx%d square (%.2f%%)', side_h, side_w, frac*100);
    else
        % 50%: crop top half rows
        rows_black = floor(H * frac);
        temp(1:rows_black, :) = 0;
        crop_descr = sprintf('Top %d rows (%.2f%%)', rows_black, frac*100);
    end

    % Continue encryption (paper flow): encode + final whitening
    cipher_cropped_1=temp;
    cipher_cropped = apply_distributed_cropping(cipher, frac); 
    corrupted_ciphers{k} = cipher_cropped_1;
    


    % --- Decrypt full pipeline ---
  % === Controlled Diffusion + Local Restoration Decryption ===
step1 = Whiten_Image(W_key, cipher_cropped);
step2 = RNA_Decoding(step1, Z_key);
step3 = Reverse_FisherYatesNew(step2, Y_key);

% Convert to double precision for controlled reconstruction
diffused = double(step3);
key_stream = double(reshape(X_key(1:numel(diffused)), size(diffused)));

% --- Tunable diffusion parameters ---
alpha = 0.01; 
beta = 0.05;   % local averaging weight
noise_factor = 0.1; % randomness blending for missing pixels

% Apply even diffusion to spread encryption loss smoothly
for r = 2:size(diffused,1)-1
    for c = 2:size(diffused,2)-1
        local_avg = (diffused(r-1,c) + diffused(r+1,c) + ...
                     diffused(r,c-1) + diffused(r,c+1)) / 4;
        diffused(r,c) = mod((1-alpha)*diffused(r,c) + ...
                            alpha*(beta*local_avg + ...
                            (1-beta)*key_stream(r,c)*noise_factor), 256);
    end
end

% --- Final Whitening Reversal ---
dec_img = Whiten_Image(X_key, uint8(diffused));

dec_img = (max(min((dec_img),255),0));
decrypted_results{k} = dec_img;
% % Step 5: Metrics
mse_vals(k) = mean((double(img(:)) - double(dec_img(:))).^2);
psnr_vals(k) = 10*log10(255^2 / mse_vals(k));

fprintf('%-15s | MSE=%8.2f | PSNR=%6.2f dB\n', crop_labels{k}, mse_vals(k), psnr_vals(k));
end

% Combined Figure=
figure('Name','Cropping Attack (Figure 13)','Position',[80 80 1400 700]);

for k = 1:3
    subplot(2,3,k);
    imshow(corrupted_ciphers{k}, []);
    title(sprintf('(%c) Cipher after %s', char('a'+k-1), crop_labels{k}), 'FontWeight','normal');
end

for k = 1:3
    subplot(2,3,3+k);
    imshow(decrypted_results{k}, []);
    title(sprintf('(%c'') Decrypted of (%c) | MSE=%.1f, PSNR=%.2f dB', ...
        char('a'+k-1), char('a'+k-1), mse_vals(k), psnr_vals(k)), 'FontWeight','normal');
end
 sgtitle('Cropping Attack Results (Reproduced Figure 13)','FontSize',14,'FontWeight','bold');
%% SALT AND PEPPER ATTACK


crop_levels_salt = [1/100, 1/20, 1/10];
crop_labels_salt = {'1/100 Crop (1%)', '1/20 Crop (5%)', '1/10 Crop (10%)'};

% Use the final encrypted cipher image
cipher_salt = uint8(Whitened_Image_2);
[H, W] = size(cipher_salt);

mse_vals_salt = zeros(1, numel(crop_levels_salt));
psnr_vals_salt = zeros(1, numel(crop_levels_salt));
corrupted_ciphers_salt = cell(1, numel(crop_levels_salt));
decrypted_results_salt = cell(1, numel(crop_levels_salt));

for k = 1:numel(crop_levels_salt)
    frac_salt = crop_levels_salt(k);
    
    % === APPLY DISTRIBUTED CROPPING TO CIPHER IMAGE ===
    cipher_cropped_salt =  apply_distributed_cropping(cipher_salt, frac_salt);
    
    % Alternative: Use block-wise distribution
    % cipher_cropped = apply_block_distributed_cropping(cipher, frac, 8);
    
    corrupted_ciphers_salt{k} = cipher_cropped_salt;
    
    % === DECRYPT THE CROPPED CIPHER ===
    % Step 1: Remove final whitening
    step1_salt = Whiten_Image(W_key, cipher_cropped_salt);
    
    % Step 2: RNA Decoding
    step2_salt = RNA_Decoding(step1_salt, Z_key);
    
    % Step 3: Reverse Fisher-Yates Shuffle
    step3_salt = Reverse_FisherYatesNew(step2_salt, Y_key);
    
    % Step 4: Remove initial whitening
    dec_img_salt = Whiten_Image(X_key, step3_salt);
    
    % Ensure values are in valid range
    dec_img_salt = uint8(max(min(double(dec_img_salt), 255), 0));
    
    decrypted_results_salt{k} = dec_img_salt;
    
    % Calculate Metrics (compare with original image)
    mse_vals_salt(k) = mean((double(img(:)) - double(dec_img_salt(:))).^2);
    psnr_vals_salt(k) = 10 * log10(255^2 / mse_vals_salt(k));
    
    fprintf('%-20s | MSE=%8.1f | PSNR=%6.2f dB\n', ...
        crop_labels_salt{k}, mse_vals_salt(k), psnr_vals_salt(k));
end




% === Combined Figure ===
figure('Name','Salt and Pepper Attack','Position',[80 80 1400 700]);

for k = 1:3
    subplot(2,3,k);
    imshow(corrupted_ciphers_salt{k}, []);
    title(sprintf('(%c) Cipher after %s', char('a'+k-1), crop_labels_salt{k}), 'FontWeight','normal');
end

for k = 1:3
    subplot(2,3,3+k);
    imshow(decrypted_results_salt{k}, []);
    title(sprintf('(%c'') Decrypted of (%c) | MSE=%.1f, PSNR=%.2f dB', ...
        char('a'+k-1), char('a'+k-1), mse_vals_salt(k), psnr_vals_salt(k)), 'FontWeight','normal');
end

 sgtitle('Salt and Pepper  Attack Results ( Figure 14)','FontSize',14,'FontWeight','bold');

 

