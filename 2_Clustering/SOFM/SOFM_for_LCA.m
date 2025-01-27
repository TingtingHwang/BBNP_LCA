% 自组织映射神经网络的聚类
% 自组织特征映�? (SOFM) 

% x = simplecluster_dataset;
close all
clear all
addpath('./lib')
% Tiff名称
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};
% Tiffname={'Altitude','Aspect'};

% Tiffname={'Altitude','Aspect','Geology','Landcover','Landform','Relief', 'Slope','Soil','Vegetation'};

% 处理Tiff数量
numtiff=length(Tiffname);

% 读数�?
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./Dataset/Raw_data_30m/' Tiffname{i} '.tif']);
end
info = geotiffinfo([['./Dataset/Raw_data_30m/' Tiffname{i} '.tif']);  % 读取tif数据的地理信息，为后面导出为tif数据提供地理信息
[temp,R]=geotiffread(['./Dataset/Raw_data_30m/' Tiffname{i} '.tif']);
[height,width,~]=size(temp);

% 背景数据
backgrounddata=[15,15,15,15,15,15,15,0,255];
for i=1:numtiff
    Igroup{i}(Igroup{i}==backgrounddata(i))=0;
end

% 转换数据类型
for i=1:numtiff
    Igroup{i}=double(Igroup{i});
end

% Generate mask
mask2D=zeros(height,width);
for i=1:numtiff
    mask2D=mask2D+Igroup{i};
end
mask2D(mask2D>0)=1;
mask1D=reshape(mask2D,width*height,1);

% Normalized Data
norm_data=Igroup;
for i=1:numtiff
    norm_data{i}=mynorm(Igroup{i},height,width,mask2D);
end

% norm_data{1}=norm_data{1}+norm_data{2}+norm_data{3}+norm_data{4};
% norm_data{2}=norm_data{5}+norm_data{6}+norm_data{7}+norm_data{8}+norm_data{9};
% numtiff=2;

% Initialization weights
w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0];

% Set to feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize,numtiff);

% Initialization features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:numtiff
            feature(fea_ct,j)=w(j)*norm_data{j}(i);
        end
    end
end



%Get the number of data to store to number
[number, row]=size(feature);
feature=feature';

figure
plot(feature(1,:),feature(2,:),'+r')

width_SOM=2;
height_SOM=10;

net = selforgmap([height_SOM,width_SOM]);
net = configure(net,feature);
figure
plotsompos(net)
% net.trainParam.epochs = 1;
net = train(net,feature);
figure
plotsompos(net)
Y=net(feature);

% Reorganization
results=zeros(width*height,1);
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        label=Y(:,fea_ct);
        results(i)=find(label==1);
    end
end

results=reshape(results,height,width);



figure;
imagesc(results)
axis image
colormap('default')
colorbar
title('result')

color=rand(width_SOM*height_SOM*3,1);
figure
for i=1:10:featuresize
    label=Y(:,i);
    m = find(label==1)-1; 
    plot(feature(1,i),feature(2,i),'+','MarkerSize',8,'LineWidth',2,'Color',[color(round(3*m+1)) color(round(3*m+2)) color(round(3*m+3))]);%'MarkerSize',8,'LineWidth',2,
    hold on
end
