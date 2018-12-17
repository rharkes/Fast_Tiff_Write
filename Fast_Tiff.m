classdef Fast_Tiff  < handle
    %FAST_TIFF Aims to write tiff data quickly on the fly
    %by writing the image data first, and end the file with IFD's
    %based on http://www.fileformat.info/format/tiff/egff.htm
    
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
        StripOffsets %offsets to all images
    end
    properties (SetAccess = immutable, Hidden = true)
        filename
        fid
        TagTypes
        DataTypes
    end
    
    methods
        function obj = Fast_Tiff(filename)
            %FAST_TIFF Construct an instance of this class
            %   Detailed explanation goes here
            obj.filename = filename;
            obj.fid = fopen(filename,'w','l');
            %set objects static values
            obj.DataTypes = obj.TellDataTypes();
            obj.TagTypes = obj.TellTagTypes();
            %write header
            obj.writeIFH(0);
            obj.TagList = uint32([]);
            obj.StripOffsets = uint32([]);
            obj.Images_Written=0;
            obj.Closed = false;
        end
        function WriteIMG(obj,img,pixelsize)
            if obj.Closed,warning('Ignoring attempted write on closed image');return;end
            if nargin<3||isempty(pixelsize),pixelsize=1;end
            %assume equal images will be written with equal IFD's
            if isempty(obj.TagList) %construct the TagList from this img
                %find nr of bytes per sample
                switch class(img)
                    case {'uint16'}
                        bps = 2; %bytes per sample
                    case {'uint8'}
                        bps = 1; 
                    otherwise
                        error('class not supported')
                end
                
                %store basic image information in the class
                obj.imsize=size(img);
                obj.BytePerIm = numel(img)*bps;
                obj.classname = class(img);
                
                %construct the taglist
                obj.TagList(1:3) = obj.TifTag(obj,'NewSubfileType','long',1,0);
                obj.TagList(4:6) = obj.TifTag(obj,'ImageWidth','long',1,size(img,1));
                obj.TagList(7:9) = obj.TifTag(obj,'ImageLength','long',1,size(img,2));
                obj.TagList(13:15) = obj.TifTag(obj,'Compression','short',1,1); %no compression
                %obj.TagList(19:21) = obj.TifTag(obj,'StripOffsets','long',1,0); %this will be put in when the file is closed
                if ismatrix(img) %uint8 or uint16
                    obj.TagList(10:12) = obj.TifTag(obj,'BitsPerSample','short',1,bps*8);
                    obj.TagList(16:18) = obj.TifTag(obj,'PhotometricInterpretation','short',1,1); %BlackIsZero
                    obj.TagList(22:24) = obj.TifTag(obj,'SamplesPerPixel','short',1,1);
                elseif ndims(img)==3&&size(img,3)==3 %RGB
                    %three words (6 bytes) cannot be stored in the TagList
                    %so needs a pointer.
                    pos = ftell(obj.fid);
                    obj.writeWORD(8);obj.writeWORD(8);obj.writeWORD(8);
                    obj.TagList(10:12) = obj.TifTag(obj,'BitsPerSample','short',3,pos);
                    obj.TagList(16:18) = obj.TifTag(obj,'PhotometricInterpretation','short',1,2); %RGB
                    obj.TagList(22:24) = obj.TifTag(obj,'SamplesPerPixel','short',1,3);
                    obj.TagList(40:42) = obj.TifTag(obj,'PlanarConfiguration','short',1,1); %1 chunky 2 planar
                    obj.isRGB = true;
                else
                    error('Only 2 or 3 dimensions allowed')
                end
                obj.TagList(25:27) = obj.TifTag(obj,'RowsPerStrip','long',1,size(img,2)); %entire image is one strip
                obj.TagList(28:30) = obj.TifTag(obj,'StripByteCounts','long',1,obj.BytePerIm); %nr bytes per image
                %a rational cannot be stored in the TagList itself, so it
                %needs a pointer.
                pos = ftell(obj.fid);
                obj.writeRat(pixelsize);
                obj.TagList(31:33) = obj.TifTag(obj,'XResolution','rational',1,pos); 
                obj.TagList(34:36) = obj.TifTag(obj,'YResolution','rational',1,pos); 
                obj.TagList(37:39) = obj.TifTag(obj,'ResolutionUnit','short',1,1);
            else %check if the image is equal to the first image
                if ndims(img)~=length(obj.imsize),error('different image');end
                if ~all(size(img)==obj.imsize),error('different image');end
                if ~strcmp(class(img),obj.classname),error('different image');end
            end
            obj.StripOffsets(end+1)=ftell(obj.fid);%start of the image
            if obj.isRGB,img = permute(img,[3,1,2]);end %chunky is accepted more than planar
            fwrite(obj.fid,img,obj.classname);
            obj.Images_Written = obj.Images_Written+1;
        end
        function close(obj)
            %write all IFDs
            IFDOffset = ftell(obj.fid);%IFDOffset
            for ct = 1:length(obj.StripOffsets)
                TL = obj.TagList;
                TL(19:21) = obj.TifTag(obj,'StripOffsets','long',1,obj.StripOffsets(ct));
                obj.writeWORD(length(TL)/3); %nr of tags
                fwrite(obj.fid,TL,'uint32');
                if ct == length(obj.StripOffsets)
                    obj.writeDWORD(0); %no next IFD
                else
                    obj.writeDWORD(ftell(obj.fid)+4); %offset to next IFD
                end
            end
            %point the header to the first one
            obj.writeIFH(IFDOffset);
            fclose(obj.fid);
            obj.Closed = true;
        end
    end
    
    methods (Static, Access=private)
        function TT = TifTag(obj,TagId,DataType,DataCount,DataOffset) %12 bytes, 3 uint32s
            TT = zeros([1,3],'uint32');
            if ischar(TagId)
               TagId = find(ismember(obj.TagTypes(1,:),TagId));
               if isempty(TagId),error('unknown TagId');end
               TagId = obj.TagTypes{2,TagId};
            end
            TT(1) = uint32(TagId);
            if ischar(DataType)
                DataType = find(ismember(obj.DataTypes(1,:),DataType));
                if isempty(DataType),error('unknown datatype');end
                DataType = obj.DataTypes{2,DataType};
            end 
            TT(1) = TT(1) + 2^16 * uint32(DataType); 
            TT(2) = uint32(DataCount);
            TT(3) = uint32(DataOffset);
        end
        function out = TellDataTypes()
            out = {'byte','ascii','short','long','rational','sbyte','undefine','sshort','slong','srational','float','double'; ...
                    1    , 2     , 3     , 4    , 5        , 6     , 7        , 8      , 9     , 10        , 11    , 12};
        end
        function out = TellTagTypes()
            out = {'NewSubfileType', 'ImageWidth' , 'ImageLength' , 'BitsPerSample' , 'Compression' , 'PhotometricInterpretation' , 'StripOffsets' , 'SamplesPerPixel' , 'RowsPerStrip' , 'StripByteCounts' , 'XResolution' , 'YResolution' , 'ResolutionUnit' , 'PlanarConfiguration'; ...
                    254            , 256          , 257           , 258             , 259           , 262                         , 273            , 277               , 278            , 279               , 282           , 283             , 296            , 284};
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
            fseek(obj.fid,0,-1); %rewind
            obj.writeWORD('II'); %Byte Order Identifier (II litle, MM big)
            obj.writeWORD(42);   %Version
            obj.writeDWORD(IFDOffset);   %IFDOffset (will be overwritten when the file closes)
        end        
        function writeWORD(obj,word)   %word: 16 bit
            if ischar(word)
                word = uint16(word(1))+2^8 * uint16(word(2));
            end
            fwrite(obj.fid,uint16(word),'uint16');
        end        
        function writeDWORD(obj,dword) %double word: 32bit
            if ischar(dword)
                dword = uint32(dword(1))+2^8 * uint32(word(2))+2^16 * uint32(word(3))+2^24 * uint32(word(4));
            end
            fwrite(obj.fid,uint32(dword),'uint32');
        end
    end
end