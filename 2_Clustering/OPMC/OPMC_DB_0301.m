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
% Tiffname={'Altitude','Aspect'};

% ���ø߿�
%30m 1400*2380, 100m 420*714, 500m 84*143, 1000m 42*71
%1000m
height=42;
width=71;

% ��ȡ
numtiff=length(Tiffname);

% ����ٲ��
Igroup=cell(1,numtiff);
for i=1:numtiff
    [Igroup{i},~]=geotiffread(['./Dataset/Raw_data_1000m/' Tiffname{i} '.tif']);
end
info = geotiffinfo(['./Dataset/Raw_data_1000m/' Tiffname{1} '.tif']);  % 读取tif数据的地理信息，为后面导出为tif数据提供地理信息
[temp,R]=geotiffread(['./Dataset/Raw_data_1000m/' Tiffname{1} '.tif']);
[height_src,width_src,~]=size(temp);

[labelmap,~]=geotiffread(['./Dataset/Raw_data_1000m/Manual.tif']);

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;
labelmap=reshape(labelmap,height*width,1);


%% OPMC Clustering Analysis
% Save data
    mkdir('./results_DB/');
    calculatedata=['./results_DB/', 'OPMC_DB_1000m','.xls'];
    
for tt=2:40
    % Number of specified classification categories
    Ncluster=tt; 
          
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
    
    %% ����DBI
    labels=Y;
    dtype=1;
    data=[X{1} X{2} X{3} X{4} X{5} X{6} X{7}];
    
    [DB,CH,KL,Han,st] = valid_internal_deviation(data,labels,dtype);
    % cluster validity indices based on deviation
    
    [nrow,nc] = size(data);
    labels = double(labels);
    k=max(labels);
    if dtype == 1
        [st,sw,sb,cintra,cinter] = valid_sumsqures(data,labels,k);
    else
        [st,sw,sb,cintra,cinter] = valid_sumpearson(data,labels,k);
    end
    ssw = trace(sw);
    ssb = trace(sb);
    
    if k > 1
        % Davies-Bouldin
        R = zeros(k);
        dbs=zeros(1,k);
        for i = 1:k
            for j = i+1:k
                if cinter(i,j) == 0
                    R(i,j) = 0;
                else
                    R(i,j) = (cintra(i) + cintra(j))/cinter(i,j);
                end
            end
            dbs(i) = max(R(i,:));
        end
        DB = mean(dbs(1:k-1));
        
        CH = ssb/(k-1);
    else
        CH =ssb;
        DB = NaN;
        Dunn = NaN;
    end
    
    CH = (nrow-k)*CH/ssw;    % Calinski-Harabasz
    Han = ssw;                        % component of Hartigan
    KL = (k^(2/nc))*ssw;         % component of Krzanowski-Lai
    
 
    
 
    %% Save varibles
%     % save varibles.mat
%     savedata=['./results_mat/','OPMC_500m_',num2str(Ncluster),'.mat'];
%     save(savedata)
    
%     % save varibles.tif
%     tif_results=imresize(results,[height_src,width_src],'nearest');
%     savenametif=['./results_tif/','OPMC_500m_',num2str(Ncluster),'.tif'];
%     geotiffwrite(savenametif,uint8(tif_results), R, 'GeoKeyDirectoryTag', info.GeoTIFFTags.GeoKeyDirectoryTag);
    
    
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
    xlswrite(calculatedata,Han, 'Sheet1', loc5);
   
end
