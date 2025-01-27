function [pMiu, pPi, pSigma] = init_params(centroids,K,D,X,N)
%K表示种类，D表示特征维度，X表示输入特征，N表示样本数量
    pMiu = centroids;  % 均值，也就是K类的中心
    pPi = zeros(1, K); % 概率
    pSigma = zeros(D, D, K); %协方差矩阵，每个都是 D*D

    % hard assign x to each centroids 
    % (X - pMiu)^2 = X^2 + pMiu^2 - 2*X*pMiu
    distmat = repmat(sum(X.*X, 2), 1, K) + repmat(sum(pMiu.*pMiu, 2)', N, 1) - 2*X*pMiu';
    [~, labels] = min(distmat, [], 2);

    for k=1:K   %初始化参数
        Xk = X(labels == k, :);
        pPi(k) = size(Xk, 1)/N;
        pSigma(:, :, k) = cov(Xk);
    end
end