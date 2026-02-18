% Detailed verification test
clc;
fprintf('=== RNA Encoding/Decoding Verification ===\n\n');

% Test with a very small known image
test_img = uint8([128, 255, 0, 64; 192, 32, 96, 160]);
fprintf('Original image:\n');
disp(test_img);

% Generate a simple key
test_key = uint8(randi([0 255], 1, 8));

% Encode
fprintf('\n--- Encoding ---\n');
encoded_img = RNA_Encoding(test_img, test_key);
fprintf('Encoded image:\n');
disp(encoded_img);

% Decode
fprintf('\n--- Decoding ---\n');
decoded_img = RNA_Decoding(encoded_img, test_key);
fprintf('Decoded image:\n');
disp(decoded_img);

% Compare
fprintf('\n--- Verification ---\n');
if isequal(test_img, decoded_img)
    fprintf('? SUCCESS: Perfect reconstruction!\n');
else
    fprintf('? FAILED: Images do not match\n');
    fprintf('Difference matrix:\n');
    disp(double(test_img) - double(decoded_img));
end