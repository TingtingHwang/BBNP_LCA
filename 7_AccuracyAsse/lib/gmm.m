function [Px, model] = gmm(X, K_or_centroids,center)
% ============================================================
% Expectation-Maximization iteration implementation of
% Gaussian Mixture Model.
%
% PX = GMM(X, K_OR_CENTROIDS)
% [PX MODEL] = GMM(X, K_OR_CENTROIDS)
%
%  - X: N-by-D data matrix.
%  - K_OR_CENTROIDS: either K indicating the number of
%       components or a K-by-D matrix indicating the
%       choosing of the initial K centroids.
%
%  - PX: N-by-K matrix indicating the probability of each
%       component generating each point.
%  - MODEL: a structure containing the parameters for a GMM:
%       MODEL.Miu: a K-by-D matrix.
%       MODEL.Sigma: a D-by-D-by-K matrix.
%       MODEL.Pi: a 1-by-K vector.
% ============================================================
% 退出迭代阈值
threshold = 1e-5;
% D表示数据的维度，N表示样本的个数
[N, D] = size(X);
% % isscalar 判断是否为标量
% if isscalar(K_or_centroids)
%     K = K_or_centroids;
%     rndp = randperm(N);
%     centroids = X(rndp(1:K), :);
%     %centroids = X(center(1:K), :);
% else  % 矩阵，给出每一类的初始化
%     K = size(K_or_centroids, 1);
%     centroids = K_or_centroids;
% end

K=K_or_centroids;
centroids=center;

% initial values
[pMiu, pPi, pSigma] = init_params(centroids,K,D,X,N);

Lprev = -inf;
while true
    %% Estiamtion Step
    Px = calc_prob(N,K,X,pMiu,pSigma,threshold,D);

    % new value for pGamma
    pGamma = Px .* repmat(pPi, N, 1);
    pGamma = pGamma ./ repmat(sum(pGamma, 2), 1, K);

    %% Maximization Step
    % new value for parameters of each Component
    Nk = sum(pGamma, 1);
    pMiu = diag(1./Nk) * pGamma' * X;
    pPi = Nk/N;
    for kk = 1:K
        Xshift = X-repmat(pMiu(kk, :), N, 1);
        pSigma(:, :, kk) = (Xshift' * (diag(pGamma(:, kk)) * Xshift)) / Nk(kk);
    end

    %% check for convergence
    L = sum(log(Px*pPi'));
    if L-Lprev < threshold
        break;
    end
    Lprev = L;
end
model = [];
model.Miu = pMiu;
model.Sigma = pSigma;
model.Pi = pPi;
end