close all;
clear all;
clc;
warning off;
addpath(genpath('./'));

addpath('./lib')

% Data name
data_name='BBNP';

% Tiff file names
Tiffname={'Altitude','Geology','Historic','Landcover','Landform','Soilscape','Vegetation'};

% Image dimensions
height=700;
width=1190;
rows=1;
cols=1;


tagstruct.ImageLength = height; % Image height
tagstruct.ImageWidth = width;  % Image width
 
% Photometric interpretation
tagstruct.Photometric = 1;
 
% Bits per sample: single precision floating point, 32-bit
tagstruct.BitsPerSample = 32;
% Number of bands per pixel
tagstruct.SamplesPerPixel = 7;
tagstruct.ExtraSamples = Tiff.ExtraSamples.AssociatedAlpha;
tagstruct.RowsPerStrip = 16;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
% Software used to generate the image
tagstruct.Software = 'MATLAB';
% Data type interpretation
tagstruct.SampleFormat = 3;


LongitudeAll = [263120 334550];
LatitudeAll = [200820 242820];

% Number of Tiff files
numtiff=length(Tiffname);

% Read data
Igroup=cell(1,numtiff);

for i=1:numtiff
    [Igroup{i},~]=geotiffread(['../../../1_Data/' Tiffname{i} '.tif']);
end

[tempmap,R]=geotiffread(['../../../1_Data/' Tiffname{1} '.tif']);

[labelmap]=imread(['BBNP_20_Cluster.tif']);

path=['dataset_' data_name num2str(rows) 'x' num2str(cols) '_7Channels'];


if exist(path)==0
    mkdir(path);
    mkdir([path '/train/']);
    mkdir([path '/train/samples/']);
    mkdir([path '/train/labels/']);
    mkdir([path '/test/']);
    mkdir([path '/test/samples/']);
    mkdir([path '/test/labels/']);
    mkdir([path '/val/']);
    mkdir([path '/val/samples/']);
    mkdir([path '/val/labels/']);
else
    disp('Directory already exists.');
end

Longitude = R.XWorldLimits;
Longitude = (Longitude-LongitudeAll(1))/(LongitudeAll(2)-LongitudeAll(1));
Latitude = R.YWorldLimits;
Latitude = (Latitude-LatitudeAll(1))/(LatitudeAll(2)-LatitudeAll(1));

Lon_Lat = [Longitude Latitude];

alignedIgroup=Igroup;
alignedIgroup{numtiff+1}=labelmap;
alignedIgroup=alignment(alignedIgroup,height,width);

Igroup=alignedIgroup(1:numtiff);
labelmap=alignedIgroup{numtiff+1};
labelmap(labelmap==labelmap(1,1))=0;

% Background data
% Set background point
bpoint=[1,1];
% Get background value
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
labelmap=double(labelmap);

% Generate mask
mask2D=zeros(height,width);
mask2D=mask2D+labelmap;
for i=1:numtiff
    mask2D=mask2D+Igroup{i};
end

mask2D(mask2D>0)=1;

% Normalize Data
norm_data= zeros(height,width,numtiff);

for i=1:numtiff
    image=single(Igroup{i}).*single(mask2D);
    MaxV=max(image(:));
    MinV=min(image(:));
    norm_data(:,:,i)=(image-MinV)/(MaxV-MinV);
end

t = Tiff([path '/test/samples/' data_name '.tif'],'w');
% Set Tiff object tags
t.setTag(tagstruct);
norm_data=single(norm_data); 
% Write data to file
t.write(norm_data);
% Close the file
t.close;


labelmatrix=uint8(labelmap);
imwrite(labelmatrix, [path '/test/labels/' data_name '.png']);

dlmwrite([path '/test/samples/' data_name '_Lon_Lat.txt'], Lon_Lat,'delimiter', '\t','precision','%.3f'); 


sample_height=height/rows;
sample_width=width/cols;

tagstruct.ImageLength = sample_height; % Image height
tagstruct.ImageWidth = sample_width;  % Image width

for ii=0:rows-1
    for jj=0:cols-1
        
        sample_data=norm_data(1+ii*sample_height:sample_height+ii*sample_height,1+jj*sample_width:sample_width+jj*sample_width,:);
        
        tempbool=sample_data>0;
        sum_data=sum(tempbool(:));

        if sum_data<50*9
            continue;
        end
        
        t = Tiff([path '/train/samples/' data_name '_' num2str(ii) '_' num2str(jj) '.tif'],'w');
        % Set Tiff object tags
        t.setTag(tagstruct); 
        % Write data
        t.write(sample_data);
        % Close file
        t.close;
        
        t = Tiff([path '/val/samples/' data_name '_' num2str(ii) '_' num2str(jj) '.tif'],'w');
        % Set Tiff object tags
        t.setTag(tagstruct); 
        % Write data
        t.write(sample_data);
        % Close file
        t.close;
        
        labelmatrix=labelmap(1+ii*sample_height:sample_height+ii*sample_height,1+jj*sample_width:sample_width+jj*sample_width,:);
        labelmatrix=uint8(labelmatrix);

        imwrite(labelmatrix, [path '/train/labels/' data_name '_' num2str(ii) '_' num2str(jj) '.png']);
        imwrite(labelmatrix, [path '/val/labels/' data_name '_' num2str(ii) '_' num2str(jj) '.png']);
         
        sample_Longitude_Start = Longitude(1) + (Longitude(2)-Longitude(1))/cols*(jj);
        sample_Longitude_End = Longitude(1) + (Longitude(2)-Longitude(1))/cols*(jj+1);

        sample_Latitude_Start = Latitude(1) + (Latitude(2)-Latitude(1))/rows*(ii);
        sample_Latitude_End = Latitude(1) + (Latitude(2)-Latitude(1))/rows*(ii+1);
        sample_Lon_Lat = [sample_Longitude_Start sample_Longitude_End sample_Latitude_Start sample_Latitude_End];
        dlmwrite([path '/train/samples/' data_name '_' num2str(ii) '_' num2str(jj) '_Lon_Lat.txt'], sample_Lon_Lat,'delimiter', '\t','precision','%.3f'); 
        dlmwrite([path '/val/samples/' data_name '_' num2str(ii) '_' num2str(jj) '_Lon_Lat.txt'], sample_Lon_Lat,'delimiter', '\t','precision','%.3f'); 
    end
end
