function result = run_fmcw_fpga_algorithm_simulink(doPlot, chirpCount)
%RUN_FMCW_FPGA_ALGORITHM_SIMULINK 运行整数FPGA控制器与光电被控对象。
% result = run_fmcw_fpga_algorithm_simulink(true, 6)

if nargin < 1
    doPlot = true;
end
if nargin < 2
    chirpCount = 6;
end
validateattributes(chirpCount, {'numeric'}, ...
    {'scalar','integer','>=',2,'<=',20});

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
startup_fmcwlidar_sil();
p = fmcw_transmitter_parameters();
% 第一阶段宽带方案：保持50 ns MZI，以3 MHz拍频验证3 GHz扫频。
p.waveform.bandwidthHz = 3e9;
p.waveform.slopeHzPerS = p.waveform.bandwidthHz / ...
    p.waveform.chirpDurationS;
simTs = p.waveform.sampleTimeS;
chirpSamples = round(p.waveform.chirpDurationS / simTs);
prechargeSamples = 2000;
updateSamples = chirpSamples;
idleSamples = 23000;
periodSamples = chirpSamples + updateSamples + idleSamples + prechargeSamples;
totalSamples = prechargeSamples + chirpSamples + ...
    (chirpCount - 1) * periodSamples;
timeS = (0:totalSamples-1).' * simTs;
resetSignal = false(totalSamples, 1);
resetSignal(1) = true;
simFpgaReset = timeseries(resetSignal, timeS);
simFpgaStopTime = timeS(end);
simTemperatureSetpointC = p.waveform.temperatureC;

assignin('base', 'simTs', simTs);
assignin('base', 'simFpgaReset', simFpgaReset);
assignin('base', 'simFpgaStopTime', simFpgaStopTime);
assignin('base', 'simTemperatureSetpointC', simTemperatureSetpointC);

modelName = 'FMCW_FPGA_Algorithm_Sim';
modelPath = fullfile(repoRoot, 'models', [modelName '.slx']);
if ~isfile(modelPath)
    build_fmcw_fpga_algorithm_simulink();
end
load_system(modelPath);
simulationOutput = sim(modelName, 'ReturnWorkspaceOutputs', 'on');

probeNames = { ...
    'fpgaDacCode','fpgaChirpStart','fpgaChirpActive', ...
    'fpgaLutWriteEnable','fpgaPhaseErrorHz','fpgaControllerState', ...
    'fpgaChirpNumber','fpgaFault','fpgaDacVoltageV','driveCurrentA', ...
    'laserFrequencyHz','mziRfVoltageV','fpgaAdcCode','withinLimits'};
for k = 1:numel(probeNames)
    probe = simulationOutput.(probeNames{k});
    result.(probeNames{k}) = squeeze(probe.Data);
end
result.timeS = simulationOutput.fpgaDacCode.Time;
result.parameters = p;
result.modelPath = modelPath;
result.simulationOutput = simulationOutput;
result.chirpCount = chirpCount;

active = logical(result.fpgaChirpActive);
chirpNumbers = double(result.fpgaChirpNumber);
edge = p.fpga.phaseEstimatorEdgeSamples;
desiredFrequencyHz = linspace(p.laser.referenceFrequencyHz - ...
    p.waveform.bandwidthHz / 2, p.laser.referenceFrequencyHz + ...
    p.waveform.bandwidthHz / 2, chirpSamples).';
result.chirpRmsErrorHz = zeros(chirpCount, 1);
result.chirpPeakErrorHz = zeros(chirpCount, 1);
result.chirpSweepBandwidthHz = zeros(chirpCount, 1);
result.chirpSampleIndices = cell(chirpCount, 1);
for chirpIndex = 1:chirpCount
    sampleIndices = find(active & chirpNumbers == chirpIndex);
    if numel(sampleIndices) ~= chirpSamples
        error('run_fmcw_fpga_algorithm_simulink:ChirpLength', ...
            'Chirp %d has %d samples; expected %d.', ...
            chirpIndex, numel(sampleIndices), chirpSamples);
    end
    result.chirpSampleIndices{chirpIndex} = sampleIndices;
    frequencyErrorHz = result.laserFrequencyHz(sampleIndices) - ...
        desiredFrequencyHz;
    valid = edge + 1:chirpSamples - edge;
    frequencyErrorHz = frequencyErrorHz - mean(frequencyErrorHz(valid));
    result.chirpRmsErrorHz(chirpIndex) = ...
        sqrt(mean(frequencyErrorHz(valid).^2));
    result.chirpPeakErrorHz(chirpIndex) = max(abs(frequencyErrorHz(valid)));
    frequencyHz = result.laserFrequencyHz(sampleIndices);
    result.chirpSweepBandwidthHz(chirpIndex) = ...
        frequencyHz(end) - frequencyHz(1);
end
result.firstChirpRmsErrorHz = result.chirpRmsErrorHz(1);
result.finalChirpRmsErrorHz = result.chirpRmsErrorHz(end);
result.linearityImprovement = result.firstChirpRmsErrorHz / ...
    result.finalChirpRmsErrorHz;
result.dacCodeMin = min(result.fpgaDacCode);
result.dacCodeMax = max(result.fpgaDacCode);
result.adcCodeMin = min(result.fpgaAdcCode);
result.adcCodeMax = max(result.fpgaAdcCode);
result.allWithinLimits = all(logical(result.withinLimits));
result.anyFault = any(logical(result.fpgaFault));
result.theoreticalRangeResolutionM = p.laser.speedOfLightMPerS / ...
    (2 * p.waveform.bandwidthHz);
result.mziBeatFrequencyHz = p.waveform.slopeHzPerS * p.mzi.delayS;

if doPlot
    open_system(modelName);
    figure('Name', 'FMCW FPGA algorithm simulation');
    tiledlayout(5, 1);

    nexttile;
    stairs(result.timeS * 1e3, result.fpgaControllerState, '.-');
    ylabel('State');
    grid on;

    nexttile;
    plot(result.timeS * 1e3, result.fpgaDacVoltageV * 1e3);
    ylabel('DAC (mV)');
    grid on;

    nexttile;
    hold on;
    for chirpIndex = 1:chirpCount
        indices = result.chirpSampleIndices{chirpIndex};
        localTimeUs = (0:chirpSamples-1).' * simTs * 1e6;
        plot(localTimeUs, ...
            (result.laserFrequencyHz(indices) - ...
            p.laser.referenceFrequencyHz) / 1e9);
    end
    hold off;
    ylabel('Detuning (GHz)');
    grid on;

    nexttile;
    plot(1:chirpCount, result.chirpRmsErrorHz / 1e6, 'o-');
    ylabel('RMS error (MHz)');
    grid on;

    nexttile;
    lastIndices = result.chirpSampleIndices{end};
    plot((0:chirpSamples-1).' * simTs * 1e6, ...
        double(result.fpgaAdcCode(lastIndices)));
    xlabel('Chirp time (us)');
    ylabel('ADC code');
    grid on;
end
end
