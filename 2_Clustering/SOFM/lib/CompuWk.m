function Wk=CompuWk(Data,MaxK)
[M,N]=size(Data);
% Ϊ�˼���Matlab�Դ���kmeans�㷨�������ȵ������������Ϊ1ʱ��Wk��
% ��ΪMatlab��kmeans�������ܼ��������Ϊ1�������
% Dr=0; %����Wk(1)
% for i=1:M
%     for j=i:M
%         Dr=Dr+norm(Data(i,:)-Data(j,:))^2;
%     end
% end
% Wk(1)=0.5*Dr/M;
iteration = 200;
for k=1:MaxK
    % ����Wk(2��MaxK)
    % labels=cmeans(Data,k);
    
    % ���ࣺ��ʼ�����������㣬��ʹ��Keams��������
    % �����ĳ�ʼ������
%     inicentroids=zeros(k,N,'double');
% 
%     for i=1:k
%         jett=1/k;
%         inicentroids(i,:)=jett*(i-1)+jett/2;
%     end
    inicentroids = Data(randperm(size(Data,1),1)',:);
    
    % K-meansѰ������ 
    [centroids, labels] = Kmeanspp(Data,inicentroids, k, iteration);
    Dr=zeros(1,k);
    for i=1:k
        Cr=[];
        for j=1:M
            if labels(j)==i
                Cr=[Cr;Data(j,:)];
            end
        end
        [CrM,~]=size(Cr);
        aver=mean(Cr);
        if CrM~=0
            for m=1:CrM
                    Dr(i)=Dr(i)+sum((Cr(m,:)-aver).^2);
            end
            Dr(i)=0.5*Dr(i)/CrM; 
        end
    end
    Wk(k)=sum(Dr);
end
end