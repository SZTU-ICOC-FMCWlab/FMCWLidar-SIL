function p = fmcw_transmitter_parameters()
%FMCW_TRANSMITTER_PARAMETERS 发射端器件参数和明确的建模假设。
% 数据源：LDC2xxCx User Guide、TED200C 操作手册、PDB440/450 手册，
% 以及 BNLD-1550-11HSM-FA1 激光器手册。

p.laser = bnld1550_parameters();

% LDC220C：实际使用的 2 A 型号。
p.currentDriver.model = 'LDC220C';
p.currentDriver.currentMinA = 0;
p.currentDriver.currentMaxA = 2.0;
p.currentDriver.complianceVoltageMinV = 4;
p.currentDriver.resolutionA = 100e-6;
p.currentDriver.accuracyA = 2e-3;
p.currentDriver.noiseRmsA = 15e-6;
p.currentDriver.rippleRmsA = 5e-6;
p.currentDriver.transientMaxA = 2e-3;
p.currentDriver.drift24hMaxA = 100e-6;
p.currentDriver.temperatureCoefficientMaxPerC = 50e-6;
p.currentDriver.modulationInputMinV = -10;
p.currentDriver.modulationInputMaxV = 10;
p.currentDriver.modulationInputResistanceOhm = 10e3;
p.currentDriver.modulationBandwidthHz = 50e3;
p.currentDriver.modulationGainNominalAPerV = 200e-3;
p.currentDriver.modulationGainTolerance = 0.05;
p.currentDriver.monitorGainVPerA = 5;
p.currentDriver.softStartTimeS = 0.2;

% 仿真中用 +3% 增益误差验证 MZI 闭环标定；位于手册 ±5% 范围内。
p.currentDriver.modelGainError = 0.03;
p.currentDriver.modelModulationGainAPerV = ...
    p.currentDriver.modulationGainNominalAPerV * ...
    (1 + p.currentDriver.modelGainError);

% TED200C + 激光器内置 10 kOhm NTC。
p.temperatureController.model = 'TED200C';
p.temperatureController.tecCurrentMaxA = 2;
p.temperatureController.complianceVoltageMinV = 6;
p.temperatureController.outputPowerMaxW = 12;
p.temperatureController.currentNoiseRippleTypicalA = 1e-3;
p.temperatureController.thermistorRangeMinOhm = 10;
p.temperatureController.thermistorRangeMaxOhm = 20e3;
p.temperatureController.thermistorResolutionOhm = 1;
p.temperatureController.thermistorAccuracyOhm = 10;
p.temperatureController.thermistorStability24hOhm = 0.5;
p.temperatureController.tuneInputMinV = -10;
p.temperatureController.tuneInputMaxV = 10;
p.temperatureController.thermistorTuneGainOhmPerV = 2e3;
p.temperatureController.monitorGainVPerOhm = 500e-6;
p.temperatureController.inputBandwidthMaxHz = 1; % 手册规定 TUNE IN <<1 Hz
p.temperatureController.referenceSetpointC = 25;
p.temperatureController.referenceThermistorOhm = 10e3;

% 手册未给激光组件热时间常数和 NTC B 值。2 s 仅用于系统级慢温漂仿真，
% 不能用于 TEC PID 参数整定；25 degC 以外温度需补充 NTC B 值或 R(T) 曲线。
p.temperatureController.modelThermalTimeConstantS = 2;
p.temperatureController.modelTemperatureNoiseRmsC = 1e-3;

% MZI 频率鉴别器。50 ns 产生 1 MHz 拍频（1 GHz/50 us 线性扫频），
% 在 PDB450C 的 4 MHz（10^5 V/A 档）带宽内，并提供 50 个条纹。
p.mzi.delayS = 50e-9;
p.mzi.fiberGroupIndex = 1.468;
p.mzi.pathImbalanceM = 299792458 / p.mzi.fiberGroupIndex * p.mzi.delayS;
p.mzi.visibility = 0.98;
p.mzi.insertionTransmission = 0.90;
p.mzi.biasPhaseRad = 0;

% 抽取约 15 uW 进入 MZI；兼顾 10^5 V/A 档与当前 2 Vpp ADC 量程。
p.mzi.tapPowerRatio = 1e-4;

% PDB450C（InGaAs，1550 nm），选择 10^5 V/A 增益档并接 50 Ohm ADC。
% 该档 RF 带宽 4 MHz，满足 1 MHz MZI 拍频；更高增益档带宽不足。
p.detector.model = 'PDB450C';
p.detector.wavelengthMinM = 800e-9;
p.detector.wavelengthMaxM = 1700e-9;
p.detector.responsivityAPerW = 1.0;
p.detector.selectedGainVPerA = 1e5;
p.detector.bandwidthHz = 4e6;
p.detector.cmrrMinDb = 25;
p.detector.cmrrTypicalDb = 30;
p.detector.transimpedanceHighZVPerA = p.detector.selectedGainVPerA;
p.detector.loadOhm = 50;
p.detector.transimpedanceLoadedVPerA = ...
    p.detector.transimpedanceHighZVPerA / 2;
p.detector.outputSwingLoadedV = 4.6 / 2;
p.detector.cwSaturationAtLowestGainW = 4.5e-3;
p.detector.cwDifferentialSaturationW = min( ...
    p.detector.cwSaturationAtLowestGainW, ...
    p.detector.outputSwingLoadedV / ...
    (p.detector.transimpedanceLoadedVPerA * p.detector.responsivityAPerW));
p.detector.damagePowerPerDiodeW = 20e-3;
p.detector.monitorBandwidthHz = 1e6;
p.detector.monitorSaturationPowerW = 1e-3;

% FMCW 与 FPGA/DAC/ADC 默认值。
p.waveform.bandwidthHz = 1e9;
p.waveform.chirpDurationS = 50e-6;
p.waveform.slopeHzPerS = p.waveform.bandwidthHz / p.waveform.chirpDurationS;
p.waveform.sampleRateHz = 100e6;
p.waveform.sampleTimeS = 1 / p.waveform.sampleRateHz;
p.waveform.referenceCurrentA = p.laser.operatingCurrentTypicalA;
p.waveform.temperatureC = 25;
p.fpga.iterations = 6;
p.fpga.learningGain = 0.65;
p.fpga.dacBits = 16;
p.fpga.dacFullScaleV = 2.0;
p.fpga.adcBits = 14;
p.fpga.adcFullScaleV = 2.0;
p.fpga.phaseEstimatorEdgeSamples = 300;

% 可实现性下限：这些误差不会被无噪声的确定性 ILC 仿真反映。
p.feasibility.driverTimeConstantS = 1 / ...
    (2 * pi * p.currentDriver.modulationBandwidthHz);
p.feasibility.laserSensitivityHzPerA = abs( ...
    p.laser.modelCurrentTuningHzPerMilliamp * 1e3);
p.feasibility.driverNoiseEquivalentFrequencyRmsHz = ...
    p.currentDriver.noiseRmsA * p.feasibility.laserSensitivityHzPerA;
p.feasibility.driverRippleEquivalentFrequencyRmsHz = ...
    p.currentDriver.rippleRmsA * p.feasibility.laserSensitivityHzPerA;
p.feasibility.dacLsbV = p.fpga.dacFullScaleV / (2^p.fpga.dacBits - 1);
p.feasibility.dacLsbEquivalentFrequencyHz = p.feasibility.dacLsbV * ...
    p.currentDriver.modulationGainNominalAPerV * ...
    p.feasibility.laserSensitivityHzPerA;
p.feasibility.voltageFor100kHzCorrectionV = 100e3 / ...
    (p.currentDriver.modulationGainNominalAPerV * ...
    p.feasibility.laserSensitivityHzPerA);
p.feasibility.temperatureSensitivityHzPerC = ...
    p.laser.speedOfLightMPerS / p.laser.centerWavelengthM^2 * ...
    p.laser.wavelengthTemperatureCoefficientMPerDegC;
end
