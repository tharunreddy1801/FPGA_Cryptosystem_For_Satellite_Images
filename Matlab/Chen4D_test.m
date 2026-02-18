function Chen4D_test()
    % Define example input values with correct types
    X_Initial = 1.0;         % double
    Y_Initial = 1.0;         % double
    Z_Initial = 1.0;         % double
    W_Initial = 1.0;         % double
    alpha = uint8(35);       % uint8
    gamma = uint8(3);        % uint8
    epsilon = uint8(12);     % uint8
    beta = uint8(8);         % uint8
    lambda = uint8(1);       % uint8 (or use double if you need 0.5)
    h = 0.001;               % double
    N = uint32(25000);       % uint32 (NOT uint8!)
    
    % Call the function
    [X_keys, Y_keys, Z_keys, W_keys, X_full, Y_full, Z_full, W_full] = Chen4D(...
        X_Initial, Y_Initial, Z_Initial, W_Initial, ...
        alpha, gamma, epsilon, beta, lambda, h, N);
end