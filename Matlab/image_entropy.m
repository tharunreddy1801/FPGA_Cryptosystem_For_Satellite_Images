function H = image_entropy(img)
    counts = imhist(img);
    p = counts / sum(counts);       % probability distribution
    p(p==0) = [];                   % remove zeros
    H = -sum(p .* log2(p));
end
