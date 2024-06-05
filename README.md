# Fast_Tiff_Write
A fast multi-image tiff writer for Matlab. Can write near the speed of fwrite and does not slow down. Supports uint8, uint16 and single precision dataformats. Both as single image or RGB.

Tiff files only support filesizes to a maximum of 4GB (2^32 bytes). Thanks to the work of [O.Hernandez](https://github.com/ohernanc) there is also a Fast-BigTiff-Writer. Please use this version when tiff-files must be bigger than 4 GB.

For Python there is [tiffwrite](https://pypi.org/project/tiffwrite/) that is fast and can write on the fly.

![Writing speed comparison](example.png?raw=true "Writing speed comparison")

The tifflib implentation [has been improved](https://github.com/rharkes/Fast_Tiff_Write/issues/7) over the years since this package came out.

[![View Multi-image Tiff Writer on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://nl.mathworks.com/matlabcentral/fileexchange/69965-multi-image-tiff-writer)
