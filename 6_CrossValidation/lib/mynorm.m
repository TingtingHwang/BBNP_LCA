function results = mynorm(image,h,w,mask)

image=single(image).*single(mask);

MaxV=max(image(mask==1));
MinV=min(image(mask==1));
results=(image-MinV)/(MaxV-MinV);
results=reshape(results,h*w,1);
end