function [corr_h, corr_v, corr_d] = correlation_coefficients(img)
    img = double(img);
    [rows, cols] = size(img);

    % Sample size (to avoid using all pixels for speed)
    N = 5000;
    xh = zeros(N,1); yh = zeros(N,1);
    xv = zeros(N,1); yv = zeros(N,1);
    xd = zeros(N,1); yd = zeros(N,1);

    for k = 1:N
        r = randi([1 rows-1]);
        c = randi([1 cols-1]);

        % Horizontal neighbors
        xh(k) = img(r,c);
        yh(k) = img(r,c+1);

        % Vertical neighbors
        xv(k) = img(r,c);
        yv(k) = img(r+1,c);

        % Diagonal neighbors
        xd(k) = img(r,c);
        yd(k) = img(r+1,c+1);
    end

    % Compute correlation coefficients
    corr_h = corrcoef(xh, yh); corr_h = corr_h(1,2);
    corr_v = corrcoef(xv, yv); corr_v = corr_v(1,2);
    corr_d = corrcoef(xd, yd); corr_d = corr_d(1,2);
end
