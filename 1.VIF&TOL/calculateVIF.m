function vif = calculateVIF(X)
% X: 输入自变量矩阵，每一列代表一个自变量

% 计算自变量之间的相关系数矩阵
R = corrcoef(X);

% 计算VIF值
p = size(X, 2); % 自变量个数
vif = zeros(p, 1);
for j = 1:p
    % 提取除了第j列之外的所有列
    idx = [1:j-1, j+1:p];
    % 计算第j个自变量与其他自变量的决定系数
    R_j = 1 - R(j, idx).^2;
    % 计算VIF值
    vif(j) = 1 / (1 - min(R_j));
end
end