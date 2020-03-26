classdef Fast_BigTiff_Write  < handle
    %FAST_BIGTIFF_WRITE Aims to write big tiff data quickly on the fly
    %by writing the image data first, and end the file with IFD's
    
    %TIFF was published in 1986 by Aldus Corporation. Aldus merged with
    %Adobe Systems Incorporated on 1st of September  1994.
    %Following documents contain canonical TIFF specifications:
    % 1) Tiff Revison 6.0, published June 3, 1992 by Aldus Corporation
    % 2) Adobe PageMaker® 6.0 TIFF Technical Notes, published September 14, 1995 by Adobe Systems Incorporated
    % 3) Adobe Photoshop® TIFF Technical Notes, published March 22, 2002 by Adobe Systems Incorporated
    % 4) Adobe Photoshop® TIFF Technical Note 3, published April 3, 2005 by Adobe Systems Incorporated
    
    %Fast Big Tiff Write v2.1
    %by R.Harkes 26-03-2020
    %big tiff implementation by O.Hernandez 
    
    %This program is free software: you can redistribute it and/or modify
    %it under the terms of the GNU General Public License as published by
    %the Free Software Foundation, either version 3 of the License, or
    %(at your option) any later version.

    %This program is distributed in the hope that it will be useful,
    %but WITHOUT ANY WARRANTY; without even the implied warranty of
    %MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %GNU General Public License for more details.

    %You should have received a copy of the GNU General Public License
    %along with this program.  If not, see <https://www.gnu.org/licenses/>.
    
    properties (SetAccess = protected)
        Images_Written
        Closed
    end
    properties (SetAccess = protected, Hidden = true)
        TagList %TagList (store as list of uint32)
        imsize
        classname
        BytePerIm
        isRGB
        dataStart %start byte for each images
        dataEnd   %end byte for each image
    end
    properties (SetAccess = immutable, Hidden = true)
        filename
        fid
        pixelsize
        compression
        TagTypes
        DataTypes
        mylocation
    end
    
    methods
        function obj = Fast_BigTiff_Write(filename,pixelsize,compression)
            %FAST_TIFF Construct an instance of this class
            %pixelsize in (dots per centimeter)
            %   Detailed explanation goes here
            if nargin<2||isempty(pixelsize),pixelsize=1;end
            if nargin<3||isempty(compression),compression=0;end %no compression by default
            [p,~,~] = fileparts(mfilename('fullpath'));obj.mylocation=p;
            obj.filename        = filename;
            obj.pixelsize       = pixelsize; %pixels / cm
            obj.compression     = compression;
            obj.fid             = fopen(filename,'w','l');
            %set objects static values
            obj.DataTypes       = obj.TellDataTypes();
            obj.TagTypes        = obj.TellTagTypes();
            %write header
            obj.writeIFH(0);
            obj.TagList         = uint32([]);
            obj.dataStart       = uint64([]);
            obj.dataEnd         = uint64([]);
            obj.Images_Written  = 0;
            obj.Closed          = false;
        end
        function WriteIMG(obj,img)
            if obj.Closed,warning('Ignoring attempted write on closed image');return;end
            %assume equal images will be written with equal IFD's
            if isempty(obj.TagList) %construct the TagList from this img
                %store basic image information in the class
                obj.imsize      = size(img);
                obj.classname   = class(img);
                
                %find nr of bytes per sample and sampleformat
                switch obj.classname
                    case {'double'}
                        warning('converting to from 64-bit double precision to 32-bit single precision')
                        img=single(img);
                        obj.classname='single';
                        bps = 4;sf=3;
                    case {'single'}
                        bps = 4;sf=3;
                    case {'uint16'}
                        bps = 2;sf=1;
                    case {'uint8'}
                        bps = 1;sf=1;
                    otherwise
                        error('class not supported')
                end
                obj.BytePerIm = numel(img)*bps;
                
                %isRGB?
                if ndims(img)==3&&size(img,3)==3 %RGB
                    obj.isRGB = true;
                elseif ~ismatrix(img)
                    error('Only 2 dimension or RGB is allowed')
                end
                
                %construct the taglist (must be stored in ascending order)
                obj.TagList(1:5) = obj.TifTag(obj,'NewSubfileType','long',1,0);
                obj.TagList(6:10) = obj.TifTag(obj,'ImageWidth','long',1,size(img,1));
                obj.TagList(11:15) = obj.TifTag(obj,'ImageLength','long',1,size(img,2));
                if obj.compression ==0
                    obj.TagList(21:25) = obj.TifTag(obj,'Compression','short',1,1); %no compression
                else
                    obj.TagList(21:25) = obj.TifTag(obj,'Compression','short',1,8); %See document #3. 32946 is supported by libTiff as PKZIP-style Deflate encoding
                end
                if obj.isRGB %RGB
                    %three words (6 bytes) cannot be stored in the TagList so needs a pointer.
%                     pos = ftell(obj.fid);
%                     obj.writeWORD(bps*8);obj.writeWORD(bps*8);obj.writeWORD(bps*8);
%                     obj.TagList(10:12) = obj.TifTag(obj,'BitsPerSample','short',3,pos);

                    obj.TagList(16:20) = obj.TifTag(obj,'BitsPerSample','short',1,bps*8); %three values doesnt seem to work, so we just give it one
                    obj.TagList(26:30) = obj.TifTag(obj,'PhotometricInterpretation','short',1,2); %RGB
                    obj.TagList(36:40) = obj.TifTag(obj,'SamplesPerPixel','short',1,3);
                else
                    obj.TagList(16:20) = obj.TifTag(obj,'BitsPerSample','short',1,bps*8);
                    obj.TagList(26:30) = obj.TifTag(obj,'PhotometricInterpretation','short',1,1); %BlackIsZero
                    obj.TagList(36:40) = obj.TifTag(obj,'SamplesPerPixel','short',1,1);
                end
                obj.TagList(41:45) = obj.TifTag(obj,'RowsPerStrip','long',1,size(img,2)); %entire image is one strip
                %obj.TagList(46:50) = obj.TifTag(obj,'StripByteCounts','TIFF_LONG8',1,obj.BytePerIm); %nr bytes per image, varies with compression so is set at the end when closing the file
                %a rational is stored in BigTiff as two 32bit values.
                obj.TagList(51:55) = obj.TifTag(obj,'XResolution','rational',1,obj.getRat(obj.pixelsize)); 
                obj.TagList(56:60) = obj.TifTag(obj,'YResolution','rational',1,obj.getRat(obj.pixelsize)); 
                obj.TagList(61:65) = obj.TifTag(obj,'PlanarConfiguration','short',1,1); %1 chunky 2 planar
                obj.TagList(66:70) = obj.TifTag(obj,'ResolutionUnit','short',1,3);%pixels per cm
                obj.TagList(71:75) = obj.TifTag(obj,'SampleFormat','short',1,sf);
            else %check if the image is equal to the first image
                if ndims(img)~=length(obj.imsize),error('different image dimensions');end
                if ~all(size(img)==obj.imsize),error('different image size');end
                if ~strcmp(class(img),obj.classname),error('different image type');end
            end
            obj.dataStart(end+1)=ftell(obj.fid);%start of the image
            if obj.isRGB,img = permute(img,[3,1,2]);end %chunky is accepted by more readers than planar
            if obj.compression == 0
                fwrite(obj.fid,img,obj.classname);
            else
                fwrite(obj.fid,obj.zip_bytes(typecast(img(:),'uint8'),obj.compression),'int8');
            end
            obj.dataEnd(end+1) = ftell(obj.fid);
            obj.Images_Written = obj.Images_Written+1;
        end
        function close(obj)
            %write all IFDs
            IFDOffset = ftell(obj.fid);%IFDOffset
            for ct = 1:length(obj.dataStart)
                TL = obj.TagList;
                TL(31:35) = obj.TifTag(obj,'StripOffsets','TIFF_LONG8',1,obj.dataStart(ct));
                TL(46:50) = obj.TifTag(obj,'StripByteCounts','TIFF_LONG8',1,obj.dataEnd(ct)-obj.dataStart(ct));
                obj.writeQWORD(length(TL)/5); %nr of tags
                fwrite(obj.fid,TL,'uint32'); %write entire taglist
                if ct == length(obj.dataStart)
                    obj.writeQWORD(0); %no next IFD
                else
                    obj.writeQWORD(ftell(obj.fid)+8); %offset to next IFD
                end
            end
            %point the header to the first one
            obj.writeIFH(IFDOffset);
            fclose(obj.fid);
            obj.Closed = true;
        end
    end
    
    methods (Static, Access=private)
        function out = getRat(rational)
            [N,D]=rat(rational);
            N = uint32(N);D=uint32(D);
            out = uint64(N) + 2^32*uint64(D);
        end
        function [out] = zip_bytes(input,level) % uses DEFLATE, build into java via Zlib
            output      = java.io.ByteArrayOutputStream();
            compresser  = java.util.zip.Deflater(level,false);  %the nowrap parameter set to false
            outstrm     = java.util.zip.DeflaterOutputStream(output,compresser);
            outstrm.write(input);
            compresser.finish();
            outstrm.close();
            out=output.toByteArray();
            %out(2)=0;
        end
        function TT = TifTag(obj,TagId,DataType,DataCount,DataOffset) %20 bytes, 2 uint16s, 2 uint64s (or 5 uint32s)
            TT = zeros([1,5],'uint32');
            if ischar(TagId)
               TagId = find(ismember(obj.TagTypes(1,:),TagId));
               if isempty(TagId),error('unknown TagId');end
               TagId = obj.TagTypes{2,TagId};
            end
            if ischar(DataType)
                DataType = find(ismember(obj.DataTypes(1,:),DataType));
                if isempty(DataType),error('unknown datatype');end
                DataType = obj.DataTypes{2,DataType};
            end
            TT(1) = uint32(TagId) + 2^16 * uint32(DataType);
            TT(2:3)=typecast(uint64(DataCount),'uint32');
            TT(4:5)=typecast(uint64(DataOffset),'uint32');
        end
        function out = TellDataTypes()
            out = {'byte','ascii','short','long','rational','sbyte','undefine','sshort','slong','srational','float','double','TIFF_LONG8','TIFF_SLONG8','TIFF_IFD8'; ...
                    1    , 2     , 3     , 4    , 5        , 6     , 7        , 8      , 9     , 10        , 11    , 12     , 16         , 17          , 18};
        end
        function out = TellTagTypes()
            out = {'NewSubfileType', 'ImageWidth' , 'ImageLength' , 'BitsPerSample' , 'Compression' , 'PhotometricInterpretation' , 'StripOffsets' , 'SamplesPerPixel' , 'RowsPerStrip' , 'StripByteCounts' , 'XResolution' , 'YResolution' , 'PlanarConfiguration' , 'ResolutionUnit' , 'SampleFormat'; ...
                    254            , 256          , 257           , 258             , 259           , 262                         , 273            , 277               , 278            , 279               , 282           , 283           , 284                   , 296               , 339};
        end
    end
    
    methods(Access=private)
        function writeRat(obj,rational)
            [N,D]=rat(rational);
            obj.writeDWORD(N);
            obj.writeDWORD(D);
        end
        function writeIFH(obj,IFDOffset)
            % writeIFH Write the Image File Header
            fseek(obj.fid,0,-1);        %rewind
            obj.writeWORD('II');        %Byte Order Identifier (II litle, MM big)
            obj.writeWORD(43);          %Version
            obj.writeWORD(8);           %Bytesize of offsets. Always 8 in BigTIFF
            obj.writeWORD(0);           %Always 0. If there is some other value here, a reader should give up.
            obj.writeQWORD(IFDOffset);	%IFDOffset (will be overwritten when the file closes)
        end        
        function writeHWORD(obj,hword)   %word: 8 bit
            if ischar(hword)
                hword =  uint8(hword(1));
            end
            fwrite(obj.fid,uint8(hword),'uint8');
        end  
        function writeWORD(obj,word)   %word: 16 bit
            if ischar(word)
                word =  uint16(word(1))+...
                        uint16(word(2)) * 2^8;
            end
            fwrite(obj.fid,uint16(word),'uint16');
        end        
        function writeDWORD(obj,dword) %double word: 32bit
            if ischar(dword)
                dword = uint32(dword(1)) +...
                        uint32(dword(2)) * 2^8 +...
                        uint32(dword(3)) * 2^16 +...
                        uint32(dword(4)) * 2^24 ;
            end
            fwrite(obj.fid,uint32(dword),'uint32');
        end
        function writeQWORD(obj,qword) %double word: 64bit
            if ischar(qword)
                qword = uint64(qword(1)) +...
                        uint64(qword(2)) * 2^8 +...
                        uint64(qword(3)) * 2^16 +...
                        uint64(qword(4)) * 2^24 +...
                        uint64(qword(5)) * 2^32 +...
                        uint64(qword(6)) * 2^40 +...
                        uint64(qword(7)) * 2^48 +...
                        uint64(qword(8)) * 2^56 ;
            end
            fwrite(obj.fid,uint64(qword),'uint64');
        end
    end
end