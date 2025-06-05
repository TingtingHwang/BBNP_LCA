close all;
clear all;
clc;
warning off;
addpath(genpath('./'));

addpath('./lib')

% Tiff names
Tiffname={'Altitude','Geology','Historic', 'Landcover','Landform','Soilscape','Vegetation'};
ClusterResultName='STSC_LCT20';

% Process height and width
height=70;
width=119;

% Number of Tiff files
numtiff=length(Tiffname);

% Read data
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./data/RAW_data/' Tiffname{i} '.tif']);
end

[ClusterResult,~]=geotiffread(['./data/ClusterResult/' ClusterResultName '.tif']);

datalength=numtiff+1;
alignedIgroup=Igroup;
alignedIgroup{datalength}=ClusterResult;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:datalength);

% Background data
% Set background point
bpoint=[1,1];
% Get background values
bgroup=cell(1,numtiff);
for i=1:datalength
    bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
end

% Set background to 0
for i=1:datalength
    Igroup{i}(Igroup{i}==bgroup{i})=0;
end

% Convert data type
for i=1:datalength
    Igroup{i}=double(Igroup{i});
end

% Generate mask
mask2D=zeros(height,width);
for i=1:datalength
    mask2D=mask2D+Igroup{i};
end
mask2D(mask2D>0)=1;
mask1D=reshape(mask2D,width*height,1);

% Set feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize, datalength);

% Initialize features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:datalength
            feature(fea_ct,j)=Igroup{j}(i);
        end
    end
end

Train_data_x=feature(:,1:numtiff);
Train_data_y=feature(:,datalength);

save("Train_data_STSC.mat","Train_data_x","Train_data_y")
