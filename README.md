# Fast_Tiff_Write
A fast multi-image tiff writer for Matlab. Can write near the speed of fwrite and does not slow down.
Data can be opened in ImageJ, but somehow not by using the tiflib or imread functions of matlab. 
A workaround that allows fast tif-reading can be found in test_fTiff.m.

![Writing speed comparison](example.png?raw=true "Writing speed comparison")
