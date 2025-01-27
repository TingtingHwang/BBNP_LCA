function labels=cmeans(data,c)
[M,N] = size(data);
labels = zeros(M,1); % data labels
CenterPre = data(1:c,:);
CenterNow = zeros(c,N);
dist= zeros(M,c); %距离矩阵
w = zeros(M,c);
while 1
    for i = 1:M 
        for j= 1:c
            dist(i,j) = sum((data(i,:) - CenterPre(j,:)).^2);
        end   
    end 
    for i = 1:M 
        %更新分类情况
        k=1;
        for j = 1:c-1
            if dist(i,k) > dist(i,j+1)
                k = j+1;
            end
        end
        w(i,k) = 1;
        CenterNow(k,:) = CenterNow(k,:) + data(i,:);
    end
    for i = 1:c 
        %计算新的类心
        k =sum(w(:,i));
        if k ~= 0
            CenterNow(i,:) = CenterNow(i,:)/k;
        end
    end
    if norm(CenterPre-CenterNow)<0.01 
        %两次聚类后的类心相等，退出聚类
        break;
    end
    CenterPre = CenterNow; 
    %更新临时变量
    CenterNow(:) =0;
    w(:) =0;
end
for i=1:M 
    %更新labels
    for j=1:c
        if w(i,j)==1
            labels(i)=j;
        end
    end
end