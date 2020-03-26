%% WARNING THIS WILL CREATE A 5GB TIFF
clear all; close all; clc;
goal = 5*2^30;
IM=imread('landOcean.jpg');
IM = uint16(sum(IM,3));
IM = IM-min(IM(:));
IM = IM*(2^15/max(IM(:)));
IM = IM';

B = numel(IM)*2;
N = ceil(goal/B);

fTIF = Fast_BigTiff_Write('testBig.tiff',1,0);
tic
msg = 0;
for ct = 1:N
    fprintf(1,repmat('\b',[1,msg]));
    msg = fprintf(1,'%.0f/%.0f',ct,N);
    %noise = uint16(2000+randn(size(IM))*1000);
    %fTIF.WriteIMG(IM+noise);
    fTIF.WriteIMG(IM);
end
fTIF.close;
t=toc;
fprintf(1,repmat('\b',[1,msg]));
fprintf(1,'\nWrite %.0f bytes in %.0f seconds\n',B*N,t);
fprintf(1,'Write speed: %.0f MB/s \n',(B*N)/(2^20*t));