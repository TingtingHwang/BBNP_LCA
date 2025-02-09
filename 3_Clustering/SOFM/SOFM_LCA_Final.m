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

%% SOFM  Clustering Analysis
% Save data
    mkdir('./results_CVI/');
    calculatedata=['./results_CVI/', 'SOFM_CVI','.xls'];
    
for tt=2:30
    Ncluster=tt;
    
    fprintf('\niter: %d', tt);
    
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
    
    width_SOM=2;
    height_SOM=8;
    
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
    
    [~,idx]=max(Y);
    
    % Reorganization
    results=zeros(width*height,1);
    fea_ct=0;
    for i=1:width*height
        if mask1D(i)==1
            fea_ct=fea_ct+1;
            results(i)=idx(fea_ct);
        end
    end
    results=reshape(results,height,width);
    
    results=medfilt2(results,[3,3]);
        
    
           
    
    %% SC,DB,CH,KL
    labels=idx;
    dtype=1;
    data=feature';
   
   [indx,ssw,sw,sb]=valid_clusterIndex(data,labels)
   
   % clustering validation indices
   % Kaijun WANG, sunice9@yahoo.com, May 2005, Oct. 2006
   
   [nr,nc]=size(data);
   k=max(labels);
   [st,sw,sb,S,Sinter] = valid_sumsqures(data,labels,k);
   ssw=trace(sw);
   ssb=trace(sb);
   
   SC = silhouette(data,labels);
   SC = mean(SC);             % mean Silhouette
   
   if k>1
       CH = ssb/(k-1);           % Calinski-Harabasz
       %Fish=ssb/ssw; % Fisher;  Han=log10(1/Fish); % Hantigan
       
       % Davies-Bouldin
       R = NaN * zeros(k);
       dbs=zeros(1,k);
       for i = 1:k
           for j = i+1:k
               R(i,j) = (S(i) + S(j))/Sinter(i,j);
           end
           dbs(i) = max(R(i,:));
       end
       db=dbs(isfinite(dbs));    % Davies-Bouldin for all clusters
       DB = mean(db);             % mean Davies-Bouldin
       
   else
       CH =ssb;
       DB=NaN;
       %Fish=NaN;  Han=0;
   end
   
   CH = (nr-k)*CH/ssw;        % Calinski-Harabasz
   KL=(k^(2/nc))*ssw;          % Krzanowski and Lai
   
   indx=[SC DB CH KL]'; 
 
    %% Save varibles
    % save varibles.mat
%     savedata=['./results_mat/','SOFM_30m_',num2str(Ncluster),'.mat'];
%     save(savedata)
    
    % save varibles.tif
    tif_results=imresize(results,[height_src,width_src],'nearest');
    savenametif=['./results_tif/','SOFM_LCA_',num2str(Ncluster),'.tif'];
    geotiffwrite(savenametif,uint8(tif_results), R, 'GeoKeyDirectoryTag', info.GeoTIFFTags.GeoKeyDirectoryTag);
    
    
    %% Write in data
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


