function plotChen4D_3DProjections(X, Y, Z, W, num_points)
    % Plot 3D projections of the 4D Chen system
    % Inputs:
    %   X, Y, Z, W - chaotic sequences from Chen4D
    %   num_points - number of points to plot
    
    if nargin < 5
        num_points = min(5000, length(X));
    end
    
    % Use only a subset for visualization (too many points slow down rendering)
    idx = 1:num_points;
    
    % Create figure with 2x2 subplot layout
    figure('Name', '4D Chen System - 3D Projections', 'Position', [100, 100, 1200, 1000]);
    
    % Plot 1: X-Y-Z projection
    subplot(2, 2, 1);
    plot3(Y(idx), X(idx), Z(idx), 'LineWidth', 0.5, 'Color', [0.2 0.4 0.8]);
    grid on;
    xlabel('Y', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('X', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('Z', 'FontSize', 12, 'FontWeight', 'bold');
    title('X-Y-Z Projection', 'FontSize', 14);
    view(45, 30);
    axis tight;
    
    % Plot 2: X-Y-W projection
    subplot(2, 2, 2);
    plot3(Y(idx), X(idx), W(idx), 'LineWidth', 0.5, 'Color', [0.8 0.2 0.4]);
    grid on;
    xlabel('Y', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('X', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('W', 'FontSize', 12, 'FontWeight', 'bold');
    title('X-Y-W Projection', 'FontSize', 14);
    view(45, 30);
    axis tight;
    
    % Plot 3: X-Z-W projection
    subplot(2, 2, 3);
    plot3(Z(idx), X(idx), W(idx), 'LineWidth', 0.5, 'Color', [0.2 0.8 0.4]);
    grid on;
    xlabel('Z', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('X', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('W', 'FontSize', 12, 'FontWeight', 'bold');
    title('X-Z-W Projection', 'FontSize', 14);
    view(45, 30);
    axis tight;
    
    % Plot 4: Y-Z-W projection
    subplot(2, 2, 4);
    plot3(Z(idx), Y(idx), W(idx), 'LineWidth', 0.5, 'Color', [0.8 0.6 0.2]);
    grid on;
    xlabel('Z', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Y', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('W', 'FontSize', 12, 'FontWeight', 'bold');
    title('Y-Z-W Projection', 'FontSize', 14);
    view(45, 30);
    axis tight;
    
    sgtitle('4D Hyperchaotic Chen System - 3D Projections', 'FontSize', 16, 'FontWeight', 'bold');
end