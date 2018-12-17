close all; clear all; clc;
img=imread('landOcean.jpg');
switch 'color'
    case 'gray'
        img = uint16(sum(img,3));
        filt = [0 1 0; 1 -4 1; 0 1 0];
        img2 = uint16(conv2(img, filt, 'same'));
        fTIF = Fast_Tiff('test.tif');
        fTIF = fTIF.WriteIMG(permute(img,[2,1,3]),0.125);
        fTIF = fTIF.WriteIMG(permute(img2,[2,1,3]),0.125);
        fTIF.close;
        
        %load image 1 (cannot use tiff library somehow; File is corrupt or image does not contain any readable strips.)
        I = imfinfo('test.tif');
        open_img=1;
        fid=fopen(I(open_img).Filename,'r','l');
        fseek(fid,I(open_img).StripOffsets,-1);
        data=fread(fid,I(open_img).StripByteCounts/2,'*uint16');
        data=reshape(data,[I(open_img).Width,I(open_img).Height]);
        imagesc(permute(data,[2,1,3]))
    case 'color'
        fTIF = Fast_Tiff('test.tif');
        fTIF = fTIF.WriteIMG(permute(img,[2,1,3]),0.125);
        fTIF.close;
        
        %load image 1  (cannot use tiff library somehow; File is corrupt or image does not contain any readable strips.)
        I = imfinfo('test.tif');
        open_img=1;
        fid=fopen(I(open_img).Filename,'r','l');
        fseek(fid,I(open_img).StripOffsets,-1);
        data=fread(fid,I(open_img).StripByteCounts,'*uint8');
        data=reshape(data,[I(open_img).Width,I(open_img).Height,3]);
        image(permute(data,[2,1,3]))
end