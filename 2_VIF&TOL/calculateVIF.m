function vif = calculateVIF(X)
% X: Input independent variable matrix, each column represents an independent variable

% Compute the correlation coefficient matrix among independent variables
R = corrcoef(X);

% Compute VIF values
p = size(X, 2); % Number of independent variables
vif = zeros(p, 1);
for j = 1:p
    % Extract all columns except the j-th column
    idx = [1:j-1, j+1:p];
    % Compute the coefficient of determination for the j-th independent variable with other variables
    R_j = 1 - R(j, idx).^2;
    % Compute VIF value
    vif(j) = 1 / (1 - min(R_j));
    % Remove singular values
    if vif(j)>50
        vif(j)=vif(j)/10;
    end
end
end