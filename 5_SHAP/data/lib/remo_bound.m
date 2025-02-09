function results = remo_bound(image)

[m,n,~]=size(image);

x_start=-1;
x_end=-1;
y_start=-1;
y_end=-1;

for i=1:m
    for j=1:n
        if (image(i,j)>0&&image(i,j)<255)||image(i,j)>255
                x_start=i;
            break
        end
    end
    if (x_start>0)
        break
    end
end

for i=1:m
    for j=1:n
        if (image(m-i+1,j)>0&&image(m-i+1,j)<255)||image(m-i+1,j)>255
                x_end=m-i+1;
            break
        end
    end
    if (x_end>0)
        break
    end
end

for i=1:n
    for j=1:m
        if (image(j,i)>0&&image(j,i)<255)||image(j,i)>255
                y_start=i;
            break
        end
    end
    if (y_start>0)
        break
    end
end

for i=1:n
    for j=1:m
        if (image(j,n-i+1)>0&&image(j,n-i+1)<255)||image(j,n-i+1)>255
                y_end=n-i+1;
            break
        end
    end
    if (y_end>0)
        break
    end
end

results=image(floor(x_start):floor(x_end),floor(y_start):floor(y_end),:);

end