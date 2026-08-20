function blkStruct = slblocks
%SLBLOCKS 注册FMCW LiDAR SIL独立Simulink模块库。

Browser.Library = 'FMCWLidar_SIL_Library';
Browser.Name = 'FMCW LiDAR SIL';
Browser.IsFlat = 0;
blkStruct.Browser = Browser;
end
