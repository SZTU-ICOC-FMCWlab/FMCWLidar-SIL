function repoRoot = startup_fmcwlidar_sil()
%STARTUP_FMCWLIDAR_SIL 将FMCWLidar-SIL源码、脚本和模型加入路径。

repoRoot = fileparts(mfilename('fullpath'));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'src', 'devices'));
addpath(fullfile(repoRoot, 'src', 'control'));
addpath(fullfile(repoRoot, 'scripts'));
addpath(fullfile(repoRoot, 'models'));

if exist('sl_refresh_customizations', 'file') == 2
    sl_refresh_customizations;
end
end
