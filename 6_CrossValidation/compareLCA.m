  
close all;
clear all;
clc;
warning off;
addpath(genpath('./TIF/'));
addpath('./lib')

% for number=5:30

% mm_name = ['SOFM_30m_med33_' num2str(number)];
% Tiff名称
Tiffname={'YGSwinClustering_4000','SOFM_30m_med33_LCT16'};
% Tiffname1={'Manual_LDUs'};

% 处理长宽
height=350;
width=595;
% height=700;
% width=1190;

% 处理Tiff数量
numtiff=length(Tiffname);

% 读数�?
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./TIF/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./TIF/' Tiffname{1} '.tif']);  % 读取tif数据的地理信息，为后面导出为tif数据提供地理信息
[temp,R]=geotiffread(['./TIF/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);


Igroup=alignment(Igroup,height,width);

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


% Set to feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize,numtiff);

% Initialization features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:numtiff
            feature(fea_ct,j)=Igroup{j}(i);
        end
    end
end


Y1=feature(:,1);
Y2=feature(:,2);

res = Clustering8Measure(Y1,Y2); % [ACC nmi Purity Fscore Precision Recall AR Entropy]

fprintf('ACC:%12.6f \nnmi:%12.6f \nPurity:%12.6f \nFscore:%12.6f \nPrecision:%12.6f \nRecall:%12.6f \nAR:%12.6f \nEntropy:%12.6f \n',res);

dlmwrite(['YGSC_4000_SOFM16.txt'],res,'delimiter','\t','precision','%.6f');
