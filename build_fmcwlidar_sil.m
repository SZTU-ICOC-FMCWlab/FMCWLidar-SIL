function artifacts = build_fmcwlidar_sil()
%BUILD_FMCWLIDAR_SIL 生成器件库和3 GHz FPGA联合SIL模型。

repoRoot = startup_fmcwlidar_sil();
artifacts.library = build_fmcwlidar_sil_library();
artifacts.closedLoopModel = build_fmcw_fpga_algorithm_simulink();

fprintf('FMCW LiDAR SIL library: %s\n', artifacts.library);
fprintf('3 GHz closed-loop model: %s\n', artifacts.closedLoopModel);

if exist('sl_refresh_customizations', 'file') == 2
    sl_refresh_customizations;
end

assert(startsWith(artifacts.library, repoRoot));
assert(startsWith(artifacts.closedLoopModel, repoRoot));
end
