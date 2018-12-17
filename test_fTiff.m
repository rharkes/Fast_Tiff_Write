close all; clear all; clc;
img=imread('landOcean.jpg');
filename = 'test.tif';
switch 'color'
    case 'gray'
        img = uint16(sum(img,3));
        img = img-min(img(:));
        img = img*(2^16/max(img(:)));
        filt = [0 1 0; 1 -4 1; 0 1 0];
        img2 = uint16(conv2(img, filt, 'same'));
        %write
        fTIF = Fast_Tiff(filename);
        fTIF = fTIF.WriteIMG(permute(img,[2,1,3]),0.125);
        fTIF = fTIF.WriteIMG(permute(img2,[2,1,3]),0.125);
        fTIF.close;
        %read
        I = imfinfo(filename);
        d=imread(filename,'Index',1,'Info',I);
        d(:,:,2)=imread(filename,'Index',2,'Info',I);
        figure(1);clf;
        subplot(1,2,1);imagesc(d(:,:,1));
        subplot(1,2,2);imagesc(d(:,:,2));
    case 'color'
        img2 = circshift(img,1,3);
        %write
        fTIF = Fast_Tiff(filename);
        fTIF = fTIF.WriteIMG(permute(img,[2,1,3]),0.125);
        fTIF = fTIF.WriteIMG(permute(img2,[2,1,3]),0.125);
        fTIF.close;
        %read
        I = imfinfo(filename);
        d=imread(filename,'Index',1,'Info',I);
        d(:,:,:,2)=imread(filename,'Index',2,'Info',I);
        figure(1);clf
        subplot(1,2,1);image(d(:,:,:,1));
        subplot(1,2,2);image(d(:,:,:,2));
end