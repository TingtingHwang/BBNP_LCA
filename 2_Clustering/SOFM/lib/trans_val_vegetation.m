function [results,maxval] = trans_val_vegetation(image)

maxv=max(image(image<255));

maxval=maxv+2;

image(image>=255)=maxval;

results=image;

end