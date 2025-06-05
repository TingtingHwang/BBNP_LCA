function results = alignment(Igroup,height,width)

numtiff=length(Igroup);

% 处理图像
for i=1:numtiff
    Igroup{i}=imresize(Igroup{i},[height,width],'nearest');
end
saveIgroup=Igroup;

% 设置背景点
bpoint=[1,1];
% 获取背景值
bgroup=cell(1,numtiff);
for i=1:numtiff
    bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
end


% 边界点对齐
for ii=1:height
    for jj=1:width
        for kk=1:numtiff
            if Igroup{kk}(ii,jj)==bgroup{kk}
                for ll=1:numtiff
                    saveIgroup{ll}(ii,jj)=bgroup{ll};
                end
                break;
            end
        end
    end
end


results=saveIgroup;

