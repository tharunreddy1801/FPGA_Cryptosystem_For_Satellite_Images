function Decoded_Image = RNA_Decoding(Encoded_Image, Z_Key)
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

    [H, W] = size(Encoded_Image);
    Decoded_Image = zeros(H, W, 'uint8');
    key_idx = 1;

    fprintf('\n===== RNA Decoding Debug Output =====\n');

    for row = 1:H
        for col = 1:W
            enc_byte = Encoded_Image(row,col);
            key_byte = Z_Key(key_idx);
            key_idx = key_idx + 1;
            if key_idx > numel(Z_Key)
                key_idx = 1;
            end

            enc_bits = de2bi(enc_byte, 8, 'left-msb');
            key_bits = de2bi(key_byte, 8, 'left-msb');

            % Extract rule and operation indices
            S1_Key_1 = key_bits(6:8);
            S1_Key_2 = key_bits(6:8);
            S2_Key   = key_bits(4:5);
            rule_idx_s1_1 = bi2de(S1_Key_1,'left-msb') + 1;
            rule_idx_s1_2 = bi2de(S1_Key_2,'left-msb') + 1;
            rule_idx_s2   = bi2de(S2_Key,'left-msb') + 1;

            % Split into 4 × 2-bit groups
            enc_groups = reshape(enc_bits, 2, []).';
            key_groups = reshape(key_bits, 2, []).';

            % Select mapping rules
            rule_plain = Rules_LUT(rule_idx_s1_1,:);
            rule_key   = Rules_LUT(rule_idx_s1_2,:);

            % Map to RNA bases
            enc_rna_seq = rule_plain(bi2de(enc_groups,'left-msb') + 1);
            key_rna_seq = rule_key(bi2de(key_groups,'left-msb') + 1);

            % Reverse the RNA operation
            plain_rna_seq = repmat(' ',1,4);
            for k = 1:4
                switch rule_idx_s2
                    case 1, plain_rna_seq(k) = rnaSub(enc_rna_seq(k), key_rna_seq(k)); % inverse of Add
                    case 2, plain_rna_seq(k) = rnaAdd(enc_rna_seq(k), key_rna_seq(k)); % inverse of Sub
                    case 3, plain_rna_seq(k) = rnaXor(enc_rna_seq(k), key_rna_seq(k)); % self-inverse
                    case 4, plain_rna_seq(k) = rnaXnor(enc_rna_seq(k), key_rna_seq(k));% self-inverse
                end
            end
              bits8=[];
            % Map bases ? bits using same plain rule
            for b = 1:4
                  base_char = char(plain_rna_seq(b));
                  idx = find(rule_plain == base_char) - 1;
                  if isempty(idx)
                     base_order = ['A','C','G','U'];
                     idx = find(base_order == base_char) - 1;
                  end
                    bits8 = [bits8, de2bi(idx,2,'left-msb')];
           end


            Decoded_Image(row,col) = uint8(bi2de(bits8, 'left-msb'));
        end
    end

    fprintf('===== RNA Decoding Complete =====\n');
end

%% --- Universal RNA operation functions (rule-independent) ---
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
    res = bases(bitxor(i, j) + 1);
end

% function res = rnaXnor(p, k)
%     bases = ['A','C','G','U'];
%     i = find(bases == p) - 1;
%     j = find(bases == k) - 1;
%     res = bases(bitcmp(bitxor(i, j),2) + 1); % 2-bit XNOR
% end
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