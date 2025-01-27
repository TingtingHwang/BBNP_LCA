% clear all
close all;
clear all;
clc;
warning off;
addpath(genpath('./'));
addpath(genpath('./eval/'));

addpath('./lib')
addpath('./valid')


%% Read data
% Tiff����
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};

% ���ø߿�
%30m 1400*2380, 100m 420*714, 500m 84*143, 1000m 42*71
%500m
height=1400;
width=2380;

% ��ȡ
numtiff=length(Tiffname);

% ����ٲ��
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./Dataset/Raw_data_30m/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./Dataset/Raw_data_30m/' Tiffname{1} '.tif']);  % 读取tif数据的地理信息，为后面导出为tif数据提供地理信息
[temp,R]=geotiffread(['./Dataset/Raw_data_30m/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

[labelmap,~]=geotiffread(['./Dataset/Raw_data_30m/Manual.tif']);

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;
labelmap=reshape(labelmap,height*width,1);

%%
% 背景数据
% 设置背景�?
bpoint=[1,1];
% 获取背景�?
bgroup=cell(1,numtiff);
for i=1:numtiff
    bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
end

for i=1:numtiff
    Igroup{i}(Igroup{i}==bgroup{i})=0;
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

% Initialization weights
w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0];

% Set to feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize,numtiff);
labels=zeros(featuresize,1);

% Initialization features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:numtiff
            feature(fea_ct,j)=w(j)*Igroup{j}(i);
        end
        labels(fea_ct)=labelmap(i);
    end
end


m_viewnum=10;
m_X=cell(m_viewnum,1);

[experts]=xlsread('Multi-view_7.xlsx', 'Sheet1', 'B2:H11');

for i=1:length(m_X)
    expert=experts(i,:);
    index=find(expert==1);
    m_temp=feature(:, index);
    m_X{i}=m_temp;
end


feature=m_X{1};
for i=2:length(m_X)
    feature=[feature,m_X{i}];
end


%Get the number of data to store to number
[number, row]=size(feature);
feature=feature';

figure
plot(feature(1,:),feature(2,:),'+r')

width_SOM=7;
height_SOM=3;

net = selforgmap([height_SOM,width_SOM]);
net = configure(net,feature);
figure
plotsompos(net)
% net.trainParam.epochs = 1;
tic;
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
        res_labels=Y(:,fea_ct);
        results(i)=find(res_labels==1);
    end
end


[~,idx]=max(Y);

% res = Clustering8Measure(labels,idx'); % [ACC nmi Purity Fscore Precision Recall AR Entropy]
% m_time  = toc;
% fprintf('Res:%12.6f %12.6f %12.6f %12.6f \tTime:%12.6f \n',[res(1) res(2) res(3) res(4) m_time]);



results=reshape(results,height,width);

results=medfilt2(results,[3,3]);
figure;
imagesc(results)
axis image
colormap('default')
colorbar
title('result')


resPath='./results_tif/';
tif_results=imresize(results,[height_src,width_src],'nearest');
savenametif=[resPath 'SOFM_30m_med33_21.tif'];
geotiffwrite(savenametif,uint8(tif_results), R, 'GeoKeyDirectoryTag', info.GeoTIFFTags.GeoKeyDirectoryTag);


figure;
labelmap=reshape(labelmap,height,width);
imagesc(labelmap)
axis image
colormap('default')
colorbar
title('labels')
% save varibles1.mat
% color=rand(width_SOM*height_SOM*3,1);
% figure
% for i=1:10:featuresize
%     res_labels=Y(:,i);
%     m = find(res_labels==1)-1; 
%     plot(feature(1,i),feature(2,i),'+','MarkerSize',8,'LineWidth',2,'Color',[color(round(3*m+1)) color(round(3*m+2)) color(round(3*m+3))]);%'MarkerSize',8,'LineWidth',2,
%     hold on
% end
