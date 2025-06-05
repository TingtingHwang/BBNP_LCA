function [results, minval] = trans_val_soil(image)

minv=min(image(image>=0));

minval=minv-2;

image(image<0)=minval;

results=image;


end