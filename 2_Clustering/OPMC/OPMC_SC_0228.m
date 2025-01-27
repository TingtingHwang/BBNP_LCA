% clear all
close all;
clear all;
clc;
warning off;
addpath(genpath('./'));
addpath(genpath('./eval/'));

addpath('./lib')


%% Read data
% Tiff名字
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};
% Tiffname={'Altitude','Aspect'};

% 设置高宽
%30m 1400*2380, 100m 420*714, 500m 84*143, 1000m 42*71
%30m
height=84;
width=143;

% 读取
numtiff=length(Tiffname);

% 组合再拆解
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./Dataset/Raw_data_500m/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./Dataset/Raw_data_500m/' Tiffname{1} '.tif']);  % 璇诲彇tif鏁版嵁鐨勫湴鐞嗕俊鎭紝涓哄悗闈㈠鍑轰负tif鏁版嵁鎻愪緵鍦扮悊淇℃伅
[temp,R]=geotiffread(['./Dataset/Raw_data_500m/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

[labelmap,~]=geotiffread(['./Dataset/Raw_data_500m/Manual.tif']);

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;
labelmap=reshape(labelmap,height*width,1);


%% OPMC Clustering Analysis
% % Save data
%     mkdir('./results_SC/');
%     calculatedata=['./results_SC/', 'OPMC_30m','.xls'];
    
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
    
    %Get the number of data to store to number
    [m_sample, row]=size(feature);
    
    m_viewnum=10;
    m_X=cell(m_viewnum,1);
    
    [experts]=xlsread('Multi-view_7.xlsx', 'Sheet1', 'B2:H11');
    
    for i=1:length(m_X)
        expert=experts(i,:);
        index=find(expert==1);
        m_temp=feature(:, index);
        %     randIndex = randperm(size(m_temp,2));
        %     m_temp=m_temp(:,randIndex);
        m_X{i}=m_temp';
    end
    
    % take Handwritten for an example
    data_name = 'lanscape_clustering';
    fprintf('\ndata_name: %s', data_name);
    
    %% pre-process, all algs do so
    X=m_X;
    gt = labels;
    %k = length(unique(gt));
    k = tt;
    V = length(X);
    
    %% specific to each alg
    alg_name = 'OPMC';
    iters = 10;  %100
    
    % normalize data
    for v=1:V
        X{v} = zscore(X{v})';
    end
    
%     for iter=1:iters
%         tic;
%         [Y, C, W, beta, obj] = opmc(X, k);
%         ts = toc;
%         %     val = my_eval_y(Y, gt);
%         %     loss = obj(end);
%         %     save(['./res/', data_name, '_OPMC_res_', num2str(iter), '.mat'], 'data_name', 'Y', 'C', 'W', 'beta', 'val', 'obj', 'ts', 'loss');
%         fprintf('\niter: %d, time: %.2f', iter, ts);
%     end

    [Y, C, W, beta, obj] = opmc(X, k);
    fprintf('\niter: %d', tt);
    
    % get res (corresponding to the minimal loss)
    % vals = cell(iters, 1);
    % tses = zeros(iters, 1);
    % losses = zeros(iters, 1);
    %
    % for iter=1:iters
    %     load(['./res/', data_name, '_OPMC_res_', num2str(iter), '.mat'])
    %     vals{iter} = val';
    %     tses(iter) = ts;
    %     losses(iter) = loss;
    % end
    %
    % [~, ind] = min(losses);
    % fprintf('\nsel.. loss: %.4f, acc: %.4f, nmi: %.4f, pur: %.4f, ts: %.2f', losses(ind), vals{ind}(1), vals{ind}(2), vals{ind}(3), tses(ind));
    %
    
    
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
    
    
    
    % aa=find(results==11)
    
    % results=medfilt2(results,[3,3]);
    % figure;
    % imagesc(results)
    % axis image
    % colormap('default')
    % colorbar
    % title('OPMC_30m_','num2str(Ncluster)')
    
    %% 计算DBI
    cluster_result=Y;
    % 假设你的聚类结果存储在一个名为cluster_result的矩阵中，每个数据点占据一行
    % 假设你的数据点有n个特征，m个数据点
    % 假设你的距离矩阵存储在一个名为distance_matrix的矩阵中
%     n = size(cluster_result, 2); % 特征数量
%     m = size(cluster_result, 1); % 数据点数量
    
    n = size(cluster_result, 2); % 特征数量
    m = size(cluster_result, 1); % 数据点数量
    
    % 计算每个数据点与其最近邻的距离
    distance_matrix = clusterdata(cluster_result);
    
    % 计算DB指标
    index = daviesbouldin(distance_matrix, cluster_result);
    fprintf('DB指标的值为：%f\n', index);
    
    %% Calculating SC
%     indexC=Y;
%     allS=0;
%     for i=1:featuresize
%         pointA=feature(i,:);
%         pointL=length(pointA);
%         class=indexC(i);
%         dismeanin=0;
%         incount=0;
%         dismeanout=0;
%         outcount=0;
%         for j=1:featuresize 
%             pointB=feature(j,:);
%             if indexC(j)==class
%                 temp=0;
%                 for k=1:pointL
%                     temp=temp+(pointA(k)-pointB(k))^2;
%                 end
%                 temp=sqrt(temp);
%                 dismeanin=dismeanin+temp;
%                 incount=incount+1;
%             else
%                 temp=0;
%                 for k=1:pointL
%                     temp=temp+(pointA(k)-pointB(k))^2;
%                 end
%                 temp=sqrt(temp);
%                 dismeanout=dismeanout+temp;
%                 outcount=outcount+1;
%             end
%         end
% 
%         dismeanin=dismeanin/incount;
%         dismeanout=dismeanout/outcount;
% 
%         singleS=(dismeanout-dismeanin)/max(dismeanout, dismeanin);
%         allS=allS+singleS;
%     end
% 
%     SIC=allS/featuresize;
%     
%     % Reorganization
%     results=zeros(width*height,1);
%     fea_ct=0;
%     for i=1:width*height
%         if mask1D(i)==1
%             fea_ct=fea_ct+1;
%             results(i)=indexC(fea_ct);
%         end
%     end
% 
%     results=reshape(results,width,height);
%     
%     fprintf('\niter: %d', SIC);
 
    %% Save varibles
%     % save varibles.mat
    savedata=['./results_mat/','OPMC_500m_',num2str(Ncluster),'.mat'];
    save(savedata)
%     save(savedata,'results','indexC','SIC');   
    
    % save varibles.tif
    tif_results=imresize(results,[height_src,width_src],'nearest');
    savenametif=['./results_tif/','OPMC_500m_',num2str(Ncluster),'.tif'];
    geotiffwrite(savenametif,uint8(tif_results), R, 'GeoKeyDirectoryTag', info.GeoTIFFTags.GeoKeyDirectoryTag);
    
    
    %% Write in data
%     loc1=['A' num2str(tt+1) ':A' num2str(tt+1)];
%     loc2=['B' num2str(tt+1) ':B' num2str(tt+1)];
%     
%     xlswrite(calculatedata,tt, 'Sheet1', loc1);
%     xlswrite(calculatedata,SIC, 'Sheet1', loc2);
%     
   
end
