function Encoded_Image = RNA_Encoding(Randomized_Image, Z_Key)
    %=== RNA Mapping Rules Lookup Table ===
    Rules_LUT = [
        'A','C','G','U';     % Rule 1
        'A','G','C','U';     % Rule 2
        'U','C','G','A';     % Rule 3
        'U','G','C','A';     % Rule 4
        'C','A','U','G';     % Rule 5
        'G','A','U','C';     % Rule 6
        'C','U','A','G';     % Rule 7
        'G','U','A','C'      % Rule 8
    ];    

    [H, W] = size(Randomized_Image);
    Encoded_Image = zeros(H, W, 'uint8');

    key_idx = 1; % pointer into Z_Key

    fprintf('\n===== RNA Encoding Debug Output =====\n');

    for row = 1:H
        for col = 1:W
            plain_byte = Randomized_Image(row,col);
            key_byte   = Z_Key(key_idx);
            key_idx = key_idx + 1;
            if key_idx > numel(Z_Key)
                key_idx = 1;
            end

            % Convert to 8-bit binary
            plain_bits = de2bi(plain_byte, 8, 'left-msb');
            key_bits   = de2bi(key_byte,   8, 'left-msb');

            % Split key bits for rule & operation
            S1_Key_1 = key_bits(6:8);  % Rule index for plaintext
            S1_Key_2 = key_bits(6:8);  % Rule index for key
            S2_Key   = key_bits(4:5);  % Operation

            rule_idx_s1_1 = bi2de(S1_Key_1,'left-msb') + 1;
            rule_idx_s1_2 = bi2de(S1_Key_2,'left-msb') + 1;
            rule_idx_s2   = bi2de(S2_Key,'left-msb') + 1;

            % Split 8 bits into four 2-bit groups
            plain_groups = reshape(plain_bits, 2, []).';
            key_groups   = reshape(key_bits,   2, []).';

            % Select rules
            rule_plain = Rules_LUT(rule_idx_s1_1,:);
            rule_key   = Rules_LUT(rule_idx_s1_2,:);

            % Encode each 2-bit group into RNA symbols
            plain_encoded = rule_plain(bi2de(plain_groups,'left-msb') + 1);
            key_encoded   = rule_key(bi2de(key_groups,'left-msb') + 1);

            % Apply operation (rule-independent)
            result = repmat(' ',1,4);
            for k = 1:4
                switch rule_idx_s2
                    case 1, result(k) = rnaAdd(plain_encoded(k), key_encoded(k));
                    case 2, result(k) = rnaSub(plain_encoded(k), key_encoded(k));
                    case 3, result(k) = rnaXor(plain_encoded(k), key_encoded(k));
                    case 4, result(k) = rnaXnor(plain_encoded(k), key_encoded(k));
                end
            end

            % Convert result RNA bases back to bits using the same plain rule
           % Convert result bases back to bits
bits8 = [];
for b = 1:4
    base_char = char(result(b));
    idx = find(rule_plain == base_char) - 1;
    if isempty(idx)
        base_order = ['A','C','G','U'];
        idx = find(base_order == base_char) - 1;
    end
    bits8 = [bits8, de2bi(idx,2,'left-msb')];
end

Encoded_Image(row,col) = uint8(bi2de(bits8, 'left-msb'));
        end
    end

    fprintf('===== RNA Encoding Complete =====\n');
end

%% --- RNA Universal Operation Functions ---
function res = rnaAdd(p, k)
    bases = ['A','C','G','U'];
    i = find(bases == p) - 1;
    j = find(bases == k) - 1;
    res = bases(mod(i + j, 4) + 1);
end

function res = rnaSub(p, k)
    bases = ['A','C','G','U'];
    i = find(bases == p) - 1;
    j = find(bases == k) - 1;
    res = bases(mod(i - j, 4) + 1);
end

function res = rnaXor(p, k)
    bases = ['A','C','G','U'];
    i = find(bases == p) - 1;
    j = find(bases == k) - 1;
    res = bases(bitxor(i,j) + 1);
end

%function res = rnaXnor(p, k)
   % bases = ['A','C','G','U'];
    %i = find(bases == p) - 1;
    %j = find(bases == k) - 1;
    %res = bases(uint8(bitcmp(bitxor(i,j),2) + 1)); % 2-bit XNOR
%end
function res = rnaXnor(p, k)
    bases = ['A','C','G','U'];
    i = find(bases == p) - 1;
    j = find(bases == k) - 1;
    % XNOR: NOT(XOR) for 2-bit values
    xor_result = bitxor(i, j);
    % For 2-bit XNOR, we need to flip only the lower 2 bits
    % XNOR(i,j) = 3 - XOR(i,j) for 2-bit values (0-3 range)
    xnor_result = bitxor(xor_result, 3);  % XOR with 11 binary = flip lower 2 bits
    res = bases(xnor_result + 1);
end
