function [X0, Y0, Z0, W0] = generateInitialConditions(SHA256_KeyBlocks, x0, y0, z0, w0)
    
    X0 = SHA256_KeyBlocks(1);
    for i = 2:8
        X0 = bitxor(X0, SHA256_KeyBlocks(i));
    end

    Y0 = SHA256_KeyBlocks(9);
    for i = 10:16
        Y0 = bitxor(Y0, SHA256_KeyBlocks(i));
    end

    Z0 = SHA256_KeyBlocks(17);
    for i = 18:24
        Z0 = bitxor(Z0, SHA256_KeyBlocks(i));
    end

    W0 = SHA256_KeyBlocks(25);
    for i = 26:32
        W0 = bitxor(W0, SHA256_KeyBlocks(i));
    end

    X0 = bitshift(X0, -8) + x0;
    Y0 = bitshift(Y0, -8) + y0;
    Z0 = bitshift(Z0, -8) + z0;
    W0 = bitshift(W0, -8) + w0;

end