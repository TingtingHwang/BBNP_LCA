clear all;
close all;

OPMC1=xlsread('BBNP_CVI',1,'B2:B30');
SOFM1=xlsread('BBNP_CVI',1,'C2:C30');
KM1=xlsread('BBNP_CVI',1,'D2:D30');

OPMC2=xlsread('BBNP_CVI',1,'H2:H30');
SOFM2=xlsread('BBNP_CVI',1,'I2:I30');
KM2=xlsread('BBNP_CVI',1,'J2:J30');


figure('color',[1 1 1]);% Set the display background to white

% Figure 1
subplot(2,1,1);
x=2:1:30;% Data on the x-axis, the first value represents the start, the second value represents the interval, and the third value represents the end
xlim([0 30])
y=0.30:0.05:0.45;
ylim([0.30 0.45])
line(x,OPMC1,'Color',[0.21,0.76,0.79],'Marker','o','lineWidth',0.7,'Markersize',4);
line(x,SOFM1,'Color',[0.84,0.1,0.11],'Marker','+','lineWidth',0.7,'Markersize',4);
line(x,KM1,'Color',[0.545098039215686,0,0.545098039215686],'Marker','^','lineWidth',0.7,'Markersize',4);
% legend('OPMC','SOFM','KM');
% xlabel('Clusters');
ylabel('SC');
% title('Silhouette Coefficient Analysis');
grid minor;% Add grid
zongxian1=OPMC1;
zongxian1(:)=20;

% set(gcf,'Position',[100 100 900 600])
% set(gca,'Position',[0.5 0.1 0.7 0.5]) % Set border width  


% Figure 2
subplot(2,1,2);
x=2:1:30;% Data on the x-axis, the first value represents the start, the second value represents the interval, and the third value represents the end
xlim([0 30])
y=0.9:0.2:2.0;
ylim([0.9 2.0])
line(x,OPMC2,'Color',[0.21,0.76,0.79],'Marker','o','lineWidth',0.7,'Markersize',4);
line(x,SOFM2,'Color',[0.84,0.1,0.11],'Marker','+','lineWidth',0.7,'Markersize',4);
line(x,KM2,'Color',[0.545098039215686,0,0.545098039215686],'Marker','^','lineWidth',0.7,'Markersize',4);
xlabel('Clusters');
ylabel('DB');
% title('Davies¨CBouldin Index Analysis');
grid minor;% Add grid%title('RKHS-DA AND SLDARKHS-DA');



% set(gca,'Position',[0.1 0.1 0.7 0.5]) % Set border width   
% legend('OPMC','SOFM','KM','Orientation','horizontal','location','SouthOutside');% Legend and annotation


% Save the figure
hold off;
set(gcf,'Units','Inches');
pos = get(gcf,'Position');
set(gcf,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
filename = 'CVI for 3 Models'; % Set export filename
print(gcf,filename,'-dpdf','-r0')


