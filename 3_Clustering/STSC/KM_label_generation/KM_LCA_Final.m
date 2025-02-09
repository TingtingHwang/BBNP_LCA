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
% Tiff名字
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};

% 设置高宽
height=1400;
width=2380;

% 读取
numtiff=length(Tiffname);

% 组合再拆解
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['../../../1_Data/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['../../../1_Data/' Tiffname{1} '.tif']);  % 璇诲彇tif鏁版嵁鐨勫湴鐞嗕俊鎭紝涓哄悗闈㈠鍑轰负tif鏁版嵁鎻愪緵鍦扮悊淇℃伅
[temp,R]=geotiffread(['../../../1_Data/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

[labelmap,~]=geotiffread(['../../../1_Data/Manual.tif']);

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;
labelmap=reshape(labelmap,height*width,1);


%% KM Clustering Analysis
% Generate mask
% mask2D=I1+I2+I3+I4+I5+I6;
% mask2D(mask2D>254)=0;
% mask2D(mask2D>0)=1;
% mask1D=reshape(mask2D,width*height,1);


% Save data
    mkdir('./results_CVI/');
    calculatedata=['./results_CVI/', 'KM_CVI','.xls'];
    
for tt=2:50
    % Number of specified classification categories
    Ncluster=tt; 
    
    % 鑳屾櫙鏁版嵁
    % 璁剧疆鑳屾櫙鐐?
    bpoint=[1,1];
    % 鑾峰彇鑳屾櫙鍊?
    bgroup=cell(1,numtiff);
    for i=1:numtiff
        bgroup{i}=Igroup{i}(bpoint(1),bpoint(2));
    end
    
    for i=1:numtiff
        Igroup{i}(Igroup{i}==bgroup{i})=0;
    end
    
    % 杞崲鏁版嵁绫诲瀷
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
    [~,dim]=size(norm_data);
    

    %% k-means Clustering analysis  
    % Initialization weights
    w=[1.0,1.0,1.0,1.0,1.0,1.0,1.0];
    
    % 定以特征大小
    featuresize=sum(mask1D(:)==1);
    feature=zeros(featuresize,dim);
     
    % 初始化特征
    fea_ct=0;
    for i=1:width*height
        if mask1D(i)==1
            fea_ct=fea_ct+1;
            for j=1:dim
                feature(fea_ct,j)=w(j)*norm_data{j}(i);
            end
        end
    end
    
    
    %获取数据的个数存至number
    [number, row]=size(feature);
    
    
    % 分类：初始化中心引导点，再使用Keams方法聚类
    % 引导的初始化中心
    inicentroids=zeros(Ncluster,dim,'double');
    
    for i=1:Ncluster
        jett=1/(Ncluster);
        inicentroids(i,:)=jett*(i-1)+jett/2;
    end
    
    % K-means寻找中心
    iteration = 200;
    [centroids, indexC] = Kmeanspp(feature,inicentroids, Ncluster, iteration);
    
    
     %% 重组
    % Reorganization
    results=zeros(width*height,1);
    fea_ct=0;
    for i=1:width*height
        if mask1D(i)==1
            fea_ct=fea_ct+1;
            results(i)=indexC(fea_ct);
        end
    end

    results=reshape(results,height,width);
%     figure
%     imshow(results)
%     results=medfilt2(results,[3,3]);
    
%% SC,DB,CH,KL
    labels=indexC;
    dtype=1;
    data=feature;
   
   [indx,ssw,sw,sb]=valid_clusterIndex(data,labels)
   
   [nr,nc]=size(data);
   k=max(labels);
   [st,sw,sb,S,Sinter] = valid_sumsqures(data,labels,k);
   ssw=trace(sw);
   ssb=trace(sb);
   
   Sil = silhouette(data,labels);
   Sil = mean(Sil);             % mean Silhouette
   
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
   
   indx=[Sil DB CH KL]'; 

 
    %% Save varibles
    % save varibles.mat
%     savedata=['./results_mat/','KM_30m_',num2str(Ncluster),'.mat'];
%     save(savedata)

    
    % save varibles.tif
    tif_results=imresize(results,[height_src,width_src],'nearest');
    savenametif=['./results_tif/','KM_LCT_',num2str(Ncluster),'.tif'];
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
    xlswrite(calculatedata,Sil, 'Sheet1', loc5);
   
end 
