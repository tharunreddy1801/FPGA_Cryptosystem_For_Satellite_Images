function hash = generateSHA256Hash(plaintext)
    % This function generates a SHA-256 hash from the given plaintext.
    
    % Convert the plaintext to a uint8 array
    data = uint8(plaintext);
    
    % Create a SHA-256 hash object
    hashObj = java.security.MessageDigest.getInstance('SHA-256');
    
    % Update the hash object with the data
    hashObj.update(data);
    
    % Generate the hash
    hashBytes = hashObj.digest();
    
    % Convert the hash bytes to a hexadecimal string
    hash = sprintf('%.2x', typecast(hashBytes, 'uint8'));
end