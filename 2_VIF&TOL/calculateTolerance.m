function tol = calculateTolerance(X)
% X: Input independent variable matrix, each column represents an independent variable

% Compute VIF values
vif = calculateVIF(X);

% Compute tolerance
tol = 1 ./ vif;
end
