function tol = calculateTolerance(X)
% X: 输入自变量矩阵，每一列代表一个自变量

% 计算VIF值
vif = calculateVIF(X);

% 计算容忍度
tol = 1 ./ vif;
end