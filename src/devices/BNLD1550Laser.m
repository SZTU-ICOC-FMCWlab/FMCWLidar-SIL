classdef BNLD1550Laser < matlab.System
    %BNLD1550LASER BNLD-1550-11HSM-FA1 的离散复包络模型。
    %
    % 可直接用于 Simulink 的 MATLAB System 模块。输入依次为：
    %   driveCurrentA  - 激光器驱动电流，A
    %   temperatureC  - 激光器结温/TEC 控制温度，degC
    %   sampleTimeS   - 仿真采样周期，s
    %   phaseNoiseUnit- N(0,1) 白噪声样本；置零可关闭随机相位噪声
    %   resetPhase    - true 时把复包络相位复位为零
    %
    % 输出依次为：
    %   opticalField  - 以 1550 nm 中心频率为参考的复包络，单位 sqrt(W)
    %   opticalPowerW - 光功率，W
    %   frequencyHz   - 绝对光频率，Hz
    %   wavelengthM   - 瞬时波长，m
    %   monitorCurrentA - 内置监测 PD 电流，A
    %   phaseRad      - 复包络相位，rad
    %   withinOperatingRange - 是否处于手册工作电流和激光器温度范围内
    %
    % 线宽采用 Lorentzian 模型：相位是 Wiener 过程，单步标准差为
    % sqrt(2*pi*linewidth*sampleTime)。本模型不直接采样约 193 THz 光载波，
    % 从而避免无意义的超高 Simulink 采样率。

    properties (Nontunable)
        CenterWavelengthM = 1550e-9
        ReferenceTemperatureC = 25
        ReferenceCurrentA = 650e-3
        ThresholdCurrentA = 50e-3
        MaximumOperatingCurrentA = 800e-3
        MinimumOperatingTemperatureC = 15
        MaximumOperatingTemperatureC = 35
        MaximumModeledPowerW = 150e-3
        SlopeEfficiencyWPerA = 0.25
        LinewidthHz = 100e3
        CurrentTuningHzPerMilliamp = 0.3e9
        CurrentTuningSign = -1
        WavelengthTemperatureCoefficientMPerC = 0.1e-9
        MonitorResponsivityAPerW = 15.5e-3
    end

    properties (DiscreteState)
        PhaseRad
    end

    properties (Constant, Access = private)
        SpeedOfLightMPerS = 299792458
    end

    methods (Access = protected)
        function setupImpl(obj, ~, ~, ~, ~, ~)
            obj.PhaseRad = 0;
        end

        function resetImpl(obj)
            obj.PhaseRad = 0;
        end

        function [opticalField, opticalPowerW, frequencyHz, wavelengthM, ...
                monitorCurrentA, phaseRad, withinOperatingRange] = stepImpl( ...
                obj, driveCurrentA, temperatureC, sampleTimeS, ...
                phaseNoiseUnit, resetPhase)

            currentForPowerA = max(driveCurrentA, 0);
            opticalPowerW = obj.SlopeEfficiencyWPerA * ...
                max(currentForPowerA - obj.ThresholdCurrentA, 0);
            opticalPowerW = min(opticalPowerW, obj.MaximumModeledPowerW);

            temperatureShiftedWavelengthM = obj.CenterWavelengthM + ...
                obj.WavelengthTemperatureCoefficientMPerC * ...
                (temperatureC - obj.ReferenceTemperatureC);
            temperatureShiftedFrequencyHz = obj.SpeedOfLightMPerS / ...
                temperatureShiftedWavelengthM;

            currentDetuningHz = obj.CurrentTuningSign * ...
                obj.CurrentTuningHzPerMilliamp * 1e3 * ...
                (driveCurrentA - obj.ReferenceCurrentA);
            frequencyHz = temperatureShiftedFrequencyHz + currentDetuningHz;
            wavelengthM = obj.SpeedOfLightMPerS / frequencyHz;

            referenceFrequencyHz = obj.SpeedOfLightMPerS / obj.CenterWavelengthM;
            basebandFrequencyHz = frequencyHz - referenceFrequencyHz;

            if resetPhase
                obj.PhaseRad = 0;
            else
                deterministicPhaseStep = 2 * pi * basebandFrequencyHz * sampleTimeS;
                randomPhaseStep = sqrt(2 * pi * obj.LinewidthHz * sampleTimeS) * ...
                    phaseNoiseUnit;
                obj.PhaseRad = mod(obj.PhaseRad + deterministicPhaseStep + ...
                    randomPhaseStep + pi, 2 * pi) - pi;
            end

            phaseRad = obj.PhaseRad;
            opticalField = sqrt(opticalPowerW) * complex(cos(phaseRad), sin(phaseRad));
            monitorCurrentA = opticalPowerW * obj.MonitorResponsivityAPerW;

            withinOperatingRange = driveCurrentA >= 0 && ...
                driveCurrentA <= obj.MaximumOperatingCurrentA && ...
                temperatureC >= obj.MinimumOperatingTemperatureC && ...
                temperatureC <= obj.MaximumOperatingTemperatureC && ...
                sampleTimeS > 0;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(~, stateName)
            if strcmp(stateName, 'PhaseRad')
                stateSize = [1 1];
                stateType = 'double';
                stateComplex = false;
            else
                error('BNLD1550Laser:UnknownState', ...
                    'Unknown discrete state: %s', stateName);
            end
        end

        function [size1, size2, size3, size4, size5, size6, size7] = ...
                getOutputSizeImpl(~)
            size1 = [1 1];
            size2 = [1 1];
            size3 = [1 1];
            size4 = [1 1];
            size5 = [1 1];
            size6 = [1 1];
            size7 = [1 1];
        end

        function [type1, type2, type3, type4, type5, type6, type7] = ...
                getOutputDataTypeImpl(~)
            type1 = 'double';
            type2 = 'double';
            type3 = 'double';
            type4 = 'double';
            type5 = 'double';
            type6 = 'double';
            type7 = 'logical';
        end

        function [complex1, complex2, complex3, complex4, complex5, ...
                complex6, complex7] = isOutputComplexImpl(~)
            complex1 = true;
            complex2 = false;
            complex3 = false;
            complex4 = false;
            complex5 = false;
            complex6 = false;
            complex7 = false;
        end

        function [fixed1, fixed2, fixed3, fixed4, fixed5, fixed6, fixed7] = ...
                isOutputFixedSizeImpl(~)
            fixed1 = true;
            fixed2 = true;
            fixed3 = true;
            fixed4 = true;
            fixed5 = true;
            fixed6 = true;
            fixed7 = true;
        end
    end
end
