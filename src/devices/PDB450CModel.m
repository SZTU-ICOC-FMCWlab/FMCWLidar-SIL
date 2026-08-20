classdef PDB450CModel < matlab.System
    %PDB450CMODEL PDB450C两光电端口到平衡RF输出的一阶模型。

    properties (Nontunable)
        SampleTimeS = 10e-9
        Visibility = 0.98
        ResponsivityAPerW = 1.0
        LoadedGainVPerA = 50e3
        BandwidthHz = 4e6
        OutputSwingV = 2.3
        DifferentialSaturationW = 46e-6
        DamagePowerPerDiodeW = 20e-3
    end

    properties (DiscreteState)
        DetectorStateV
    end

    methods (Access = protected)
        function setupImpl(~, ~, ~)
        end

        function resetImpl(obj)
            obj.DetectorStateV = 0;
        end

        function [rfVoltageV, saturated] = stepImpl(obj, powerPlusW, powerMinusW)
            differentialPowerW = obj.Visibility * (powerPlusW - powerMinusW);
            unfilteredVoltageV = obj.LoadedGainVPerA * ...
                obj.ResponsivityAPerW * differentialPowerW;
            detectorPole = exp(-2 * pi * obj.BandwidthHz * obj.SampleTimeS);
            obj.DetectorStateV = detectorPole * obj.DetectorStateV + ...
                (1 - detectorPole) * unfilteredVoltageV;
            rfVoltageV = min(max(obj.DetectorStateV, ...
                -obj.OutputSwingV), obj.OutputSwingV);
            saturated = abs(differentialPowerW) >= ...
                obj.DifferentialSaturationW || ...
                powerPlusW >= obj.DamagePowerPerDiodeW || ...
                powerMinusW >= obj.DamagePowerPerDiodeW || ...
                abs(obj.DetectorStateV) >= obj.OutputSwingV;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(~, stateName)
            if strcmp(stateName, 'DetectorStateV')
                stateSize = [1 1];
                stateType = 'double';
                stateComplex = false;
            else
                error('PDB450CModel:UnknownState', ...
                    'Unknown discrete state: %s', stateName);
            end
        end

        function [size1, size2] = getOutputSizeImpl(~)
            size1 = [1 1]; size2 = [1 1];
        end

        function [type1, type2] = getOutputDataTypeImpl(~)
            type1 = 'double'; type2 = 'logical';
        end

        function [complex1, complex2] = isOutputComplexImpl(~)
            complex1 = false; complex2 = false;
        end

        function [fixed1, fixed2] = isOutputFixedSizeImpl(~)
            fixed1 = true; fixed2 = true;
        end
    end
end
