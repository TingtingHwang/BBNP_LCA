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
% Tiff file names
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};

% Set height and width
height=1400;
width=2380;

% Read data
numtiff=length(Tiffname);

% Combine and then separate
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['../../1_Data/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['../../1_Data/' Tiffname{1} '.tif']);  % Read geospatial information of tif data for later exporting
[temp,R]=geotiffread(['../../1_Data/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

[labelmap,~]=geotiffread(['../../1_Data/Manual.tif']);

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;
labelmap=reshape(labelmap,height*width,1);


% OPMC Clustering Analysis
% Save data
mkdir('./results_CVI/');
calculatedata=['./results_CVI/', 'OPMC_CVI','.xls'];
%% Iterative calculation
for tt=2:30
    % Number of specified classification categories
    Ncluster=tt; 
          
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
    
    % Normalized Data
    norm_data=Igroup;
    for i=1:numtiff
        norm_data{i}=mynorm(Igroup{i},height,width,mask2D);
    end
    
    % Initialization weights
    w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0];
    
    % Set feature size
    featuresize=sum(mask1D(:)==1);
    feature=zeros(featuresize,numtiff);
    labels=zeros(featuresize,1);
    
    % Initialize features
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
    
    % Get the number of data points
    [m_sample, row]=size(feature);
    
    m_viewnum=10;
    m_X=cell(m_viewnum,1);
    
    [experts]=xlsread('Multi-view_7.xlsx', 'Sheet1', 'B2:H11');
    
    for i=1:length(m_X)
        expert=experts(i,:);
        index=find(expert==1);
        m_temp=feature(:, index);
        m_X{i}=m_temp';
    end
    
    data_name = 'lanscape_clustering';
    fprintf('\ndata_name: %s', data_name);
    
    %% Pre-processing, required for all algorithms
    X=m_X;
    gt = labels;
    k = tt;
    V = length(X);
    
    %% Algorithm-specific settings
    alg_name = 'OPMC';
    iters = 10;  
    
    % Normalize data
    for v=1:V
        X{v} = zscore(X{v})';
    end
    
    [Y, C, W, beta, obj] = opmc(X, k);
    fprintf('\niter: %d', tt);
    
    % Reorganization
    results=zeros(width*height,1);
    fea_ct=0;
    for i=1:width*height
        if mask1D(i)==1
            fea_ct=fea_ct+1;
            results(i)=Y(fea_ct);
        end
    end
    
    results=reshape(results,height,width);
    results=medfilt2(results,[3,3]);
    
   % SC
   labels=Y;
   dtype=1;
   data=[X{1} X{2} X{3} X{4} X{5} X{6} X{7}];
   
   [indx,ssw,sw,sb]=valid_clusterIndex(data,labels);
   
   % Clustering validation indices
   [nr,nc]=size(data);
   k=max(labels);
   [st,sw,sb,S,Sinter] = valid_sumsqures(data,labels,k);
   ssw=trace(sw);
   ssb=trace(sb);
   
   SC = silhouette(data,labels);
   SC = mean(SC); 
   
   if k>1
       CH = ssb/(k-1);
       
       % Davies-Bouldin Index
       R = NaN * zeros(k);
       dbs=zeros(1,k);
       for i = 1:k
           for j = i+1:k
               R(i,j) = (S(i) + S(j))/Sinter(i,j);
           end
           dbs(i) = max(R(i,:));
       end
       db=dbs(isfinite(dbs));
       DB = mean(db); 
       
   else
       CH =ssb;
       DB=NaN;
   end
   
   CH = (nr-k)*CH/ssw; 
   KL=(k^(2/nc))*ssw; 
   
   indx=[SC DB CH KL]';
   
   % Write results into the file
   loc1=['A' num2str(tt+1) ':A' num2str(tt+1)];
   loc2=['B' num2str(tt+1) ':B' num2str(tt+1)];
   loc3=['C' num2str(tt+1) ':C' num2str(tt+1)];
   loc4=['D' num2str(tt+1) ':D' num2str(tt+1)];
   loc5=['E' num2str(tt+1) ':E' num2str(tt+1)];
   
   xlswrite(calculatedata,tt, 'Sheet1', loc1);
   xlswrite(calculatedata,DB, 'Sheet1', loc2);
   xlswrite(calculatedata,CH, 'Sheet1', loc3);
   xlswrite(calculatedata,KL, 'Sheet1', loc4);
   xlswrite(calculatedata,SC, 'Sheet1', loc5);
end