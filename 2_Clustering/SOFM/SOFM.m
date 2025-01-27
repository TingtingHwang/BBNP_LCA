% 自组织映射神经网络的聚类
% 自组织特征映射 (SOFM) 

% x = simplecluster_dataset;
close all
clear all
addpath('./lib')
% Tiff名称
Tiffname={'Altitude','Aspect','Geology','Historic','Landcover','Landform','Slope','Soilscaped','Vegetation'};

% Tiffname={'Altitude','Aspect','Geology','Landcover','Landform','Relief', 'Slope','Soil','Vegetation'};

% 处理Tiff数量
numtiff=length(Tiffname);

% 读数据
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./RAW_data_9/RAW_data_9/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./RAW_data_9/RAW_data_9/' Tiffname{1} '.tif']);  % 读取tif数据的地理信息，为后面导出为tif数据提供地理信息
[temp,R]=geotiffread(['./RAW_data_9/RAW_data_9/' Tiffname{1} '.tif']);
[height,width,~]=size(temp);

% 背景数据
backgrounddata=[15,15,15,15,15,15,15,0,255];
for i=1:numtiff
    Igroup{i}(Igroup{i}==backgrounddata(i))=0;
end

%转换数据类型
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



% Initialization weights
w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0];

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


width=3;
height=4;
points_num = 1000;
X = rands(2, points_num);
figure
plot(X(1,:),X(2,:),'+r')
net = selforgmap([1,width*height]);
net = configure(net,X);
figure
plotsompos(net)
% net.trainParam.epochs = 1;
net = train(net,X);
figure
plotsompos(net)
Y=net(X);

% coArray=['y','m','c','r','g','b','w','k'];%初始颜色数组 
%        
%  
% liArray=['o','x','+','*','-',':','-.','--','.'];%初始线条数组 

color=rand(width*height*3,1);

figure
for i=1:points_num
    label=Y(:,i);
    m = find(label==1)-1; 
    plot(X(1,i),X(2,i),'+','MarkerSize',8,'LineWidth',2,'Color',[color(round(3*m+1)) color(round(3*m+2)) color(round(3*m+3))]);
    hold on
end
