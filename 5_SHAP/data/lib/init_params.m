function [pMiu, pPi, pSigma] = init_params(centroids,K,D,X,N)
%K��ʾ���࣬D��ʾ����ά�ȣ�X��ʾ����������N��ʾ��������
    pMiu = centroids;  % ��ֵ��Ҳ����K�������
    pPi = zeros(1, K); % ����
    pSigma = zeros(D, D, K); %Э�������ÿ������ D*D

    % hard assign x to each centroids 
    % (X - pMiu)^2 = X^2 + pMiu^2 - 2*X*pMiu
    distmat = repmat(sum(X.*X, 2), 1, K) + repmat(sum(pMiu.*pMiu, 2)', N, 1) - 2*X*pMiu';
    [~, labels] = min(distmat, [], 2);

    for k=1:K   %��ʼ������
        Xk = X(labels == k, :);
        pPi(k) = size(Xk, 1)/N;
        pSigma(:, :, k) = cov(Xk);
    end
end