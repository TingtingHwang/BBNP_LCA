% �������
function [Px,Xshift] = calc_prob(N,K,X,pMiu,pSigma,threshold,D)
    Px = zeros(N, K);
    for k = 1:K
        %
        Duptemp=repmat(pMiu(k, :), N, 1);
        Xshift = X- Duptemp;
        inv_pSigma = inv(pSigma(:, :, k)+diag(repmat(threshold,1,size(pSigma(:, :, k),1)))); % �����������
        tmp = sum((Xshift*inv_pSigma) .* Xshift, 2);
        coef = (2*pi)^(-D/2) * sqrt(det(inv_pSigma)); % det �󷽲���������ʽ  
        Px(:, k) = coef * exp(-0.5*tmp);
    end
end