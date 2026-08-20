function p = bnld1550_parameters()
%BNLD1550_PARAMETERS BNLD-1550-11HSM-FA1 手册参数与模型默认值。
% 单位统一为 SI；原始手册单位保留在字段注释中。
%
% 手册来源：1550nm DFB 100KHz Narrow Linewidth Laser，
% Ref. S001.2023.11.30。

p.speedOfLightMPerS = 299792458;

% 光学特性（25 degC 激光器温度）
p.centerWavelengthM = 1550e-9;          % 典型值；范围 1545~1555 nm
p.centerWavelengthMinM = 1545e-9;
p.centerWavelengthMaxM = 1555e-9;
p.referenceFrequencyHz = p.speedOfLightMPerS / p.centerWavelengthM;
p.outputPowerMinW = 100e-3;             % 手册最小值 100 mW
p.outputPowerTypicalW = 150e-3;         % 手册典型值 150 mW
p.linewidthMaxHz = 100e3;                % FWHM，手册规定 <100 kHz
p.sideModeSuppressionMinDb = 40;
p.opticalIsolationMinDb = 40;

% 激光二极管电气参数
p.thresholdCurrentMaxA = 50e-3;
p.operatingCurrentTypicalA = 650e-3;
p.operatingCurrentMaxA = 800e-3;
p.forwardCurrentAbsoluteMaxA = 900e-3;
p.operatingVoltageMaxV = 2.5;

% 频率/温度调谐
p.currentTuningMinHzPerMilliamp = 0.2e9;
p.currentTuningMaxHzPerMilliamp = 0.4e9;
p.wavelengthTemperatureCoefficientMPerDegC = 0.1e-9;
p.laserTemperatureMinDegC = 15;
p.laserTemperatureReferenceDegC = 25;
p.laserTemperatureMaxDegC = 35;
p.endOfLifeWavelengthDriftMaxM = 0.1e-9;

% 监测光电二极管
p.monitorResponsivityMinAPerW = 1e-3;    % 1 uA/mW = 1e-3 A/W
p.monitorResponsivityMaxAPerW = 30e-3;   % 30 uA/mW = 30e-3 A/W

% TEC、热敏电阻与环境极限（用于控制器/保护模型，不用于光场动态）
p.tecSetTemperatureMinDegC = 15;
p.tecSetTemperatureMaxDegC = 35;
p.thermistorCurrentMaxA = 0.5e-3;
p.thermistorResistanceTypicalOhm = 10e3;
p.thermistorResistanceMinOhm = 9.5e3;
p.thermistorResistanceMaxOhm = 10.5e3;
p.tecCurrentAtWorstCaseMaxA = 1.5;
p.tecVoltageAtWorstCaseMaxV = 3.5;
p.tecDeltaTMaxDegC = 50;
p.tecVoltageAbsoluteMaxV = 4.8;
p.tecCurrentAbsoluteMaxA = 2.5;
p.caseTemperatureMinDegC = -40;
p.caseTemperatureMaxDegC = 85;

% 光纤
p.fiberType = 'PM1550';
p.pigtailLengthM = 1.0;
p.connectorType = 'FC/APC';

% 模型默认值。以下三项不是手册典型值，均为显式建模假设。
p.modelLinewidthHz = p.linewidthMaxHz;   % 保守使用最差线宽
p.modelCurrentTuningHzPerMilliamp = ...
    (p.currentTuningMinHzPerMilliamp + p.currentTuningMaxHzPerMilliamp) / 2;
p.modelCurrentTuningSign = -1;           % 假设增大电流使光频率下降；手册未给符号
p.modelMonitorResponsivityAPerW = ...
    (p.monitorResponsivityMinAPerW + p.monitorResponsivityMaxAPerW) / 2;
p.modelSlopeEfficiencyWPerA = p.outputPowerTypicalW / ...
    (p.operatingCurrentTypicalA - p.thresholdCurrentMaxA);
p.modelPowerSaturationW = p.outputPowerTypicalW;
end
