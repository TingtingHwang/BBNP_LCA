close all;
clear all;
clc;
warning off;
addpath(genpath('./TIF/'));
addpath('./lib')

Tiffname={'STSC_LCT20','OPMC_LCT20'};
% Tiffname1={'Manual_LDUs'};

% Processing image dimensions
height=350;
width=595;
% height=700;
% width=1190;

% Number of Tiff files to process
numtiff=length(Tiffname);

% Read data
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./TIF/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./TIF/' Tiffname{1} '.tif']);  % Read geospatial information from the tif file for later export
[temp,R]=geotiffread(['./TIF/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

% Align images
Igroup=alignment(Igroup,height,width);

% Background data processing
% Set background point
bpoint=[1,1];
% Get background value
bgroup=cell(1,numtiff);
for i=1:numtiff
    bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
end

% Set background pixels to zero
for i=1:numtiff
    Igroup{i}(Igroup{i}==bgroup{i})=0;
end

% Convert data type
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

% Set feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize,numtiff);

% Initialize features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:numtiff
            feature(fea_ct,j)=Igroup{j}(i);
        end
    end
end

% Extract feature values for clustering
Y1=feature(:,1);
Y2=feature(:,2);

% Perform clustering evaluation
res = Clustering8Measure(Y1,Y2); % [ACC nmi Purity Fscore Precision Recall AR Entropy]

% Print results
fprintf('ACC:%12.6f \nnmi:%12.6f \nPurity:%12.6f \nFscore:%12.6f \nPrecision:%12.6f \nRecall:%12.6f \nAR:%12.6f \nEntropy:%12.6f \n',res);

% Save results to file
dlmwrite(['Results\STSC20_SOFM16.txt'],res,'delimiter','\t','precision','%.6f');
