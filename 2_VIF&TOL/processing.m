close all;
clear all;
clc;
warning off;
addpath(genpath('../'));
addpath('./lib')

% Tiff names
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};

datasetpath='1_Data/';

% Process height and width
height=round(1400);
width=round(2380);

% Process the number of Tiff files
numtiff=length(Tiffname);

% Read data
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread([datasetpath Tiffname{i} '.tif']);
end

alignedIgroup=Igroup;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);

% Background data
% Set background point
bpoint=[1,1];
% Get background values
bgroup=cell(1,numtiff);
for i=1:numtiff
    bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
end

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

% Normalize Data
norm_data=Igroup;
for i=1:numtiff
    norm_data{i}=mynorm(Igroup{i},height,width,mask2D);
end

% Initialize weights
w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0];

% Set feature size
featuresize=sum(mask1D(:)==1);
feature=zeros(featuresize,numtiff);

% Initialize features
fea_ct=0;
for i=1:width*height
    if mask1D(i)==1
        fea_ct=fea_ct+1;
        for j=1:numtiff
            % feature(fea_ct,j)=w(j)*norm_data{j}(i);
            feature(fea_ct,j)=w(j)*Igroup{j}(i);
        end
    end
end

X=feature;
% Compute VIF
vif = calculateVIF(X);
% Compute TOL
tol = 1 ./ vif;
disp("VIF");
disp(vif);
disp("TOL");
disp(tol);