function [documentPath, isLocalFile] = open_fmcwlidar_manual(deviceName, doOpen)
%OPEN_FMCWLIDAR_MANUAL 打开器件PDF手册或模块接口文档。
% [path,isLocal] = open_fmcwlidar_manual(deviceName,false)只解析路径，
% 不启动外部PDF阅读器，适合自动检查。

if nargin < 2
    doOpen = true;
end
validateattributes(deviceName, {'char','string'}, {'scalartext'});
validateattributes(doOpen, {'logical','numeric'}, {'scalar'});

repoRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(repoRoot);
manualRoot = fullfile(repoRoot, 'docs', 'manuals');
sourceRoot = fullfile(projectRoot, 'fmcw激光雷达器件选型', ...
    'fmcw激光雷达器件选型', '器件用户手册及选型分析');

switch lower(char(deviceName))
    case 'ldc220c'
        fileName = 'LDC2xxCx_User_Guide_doc-104799.pdf';
        sourcePath = fullfile(sourceRoot, '恒流源驱动', 'doc-104799.pdf');
        fallbackUrl = 'https://www.thorlabs.com/item.cfm?partnumber=LDC220C';
    case 'ted200c'
        fileName = 'TED200C_Operation_Manual_15986-D04.pdf';
        sourcePath = fullfile(sourceRoot, '温控', '15986-d04.pdf');
        fallbackUrl = 'https://www.thorlabs.com/item.cfm?partnumber=TED200C';
    case 'bnld1550'
        fileName = 'BNLD1550_100kHz_DFB_Datasheet.pdf';
        sourcePath = fullfile(sourceRoot, '激光器', ...
            '1550nm DFB 100KHz Narrow Linewidth Laser.pdf');
        fallbackUrl = 'https://www.boxoptronics.com/';
    case 'pdb450c'
        fileName = 'PDB4xx_Balanced_Detector_Manual_21709-D02.pdf';
        sourcePath = fullfile(sourceRoot, '平衡探测器', '21709-d02.pdf');
        fallbackUrl = 'https://www.thorlabs.com/item.cfm?partnumber=PDB450C';
    case {'mzi','adc','dac','fpga'}
        documentPath = fullfile(repoRoot, 'docs', 'DEVICE_INTERFACES.md');
        isLocalFile = true;
        openDocument(documentPath, doOpen);
        return;
    otherwise
        error('open_fmcwlidar_manual:UnknownDevice', ...
            'Unknown FMCW LiDAR device: %s', char(deviceName));
end

localManual = fullfile(manualRoot, fileName);
if isfile(localManual)
    documentPath = localManual;
    isLocalFile = true;
elseif isfile(sourcePath)
    documentPath = sourcePath;
    isLocalFile = true;
else
    documentPath = fallbackUrl;
    isLocalFile = false;
end
openDocument(documentPath, doOpen);
end

function openDocument(documentPath, doOpen)
if ~logical(doOpen)
    return;
end
if isfile(documentPath)
    if ispc
        winopen(documentPath);
    else
        web(['file:///' strrep(documentPath, '\', '/')], '-browser');
    end
else
    web(documentPath, '-browser');
end
end
