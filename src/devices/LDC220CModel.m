classdef LDC220CModel < matlab.System
    %LDC220CMODEL LDC220C MOD IN 到激光驱动电流的一阶模型。

    properties (Nontunable)
        SampleTimeS = 10e-9
        BiasCurrentA = 650e-3
        InitialCurrentA = 650e-3
        ModulationGainAPerV = 206e-3
        ModulationBandwidthHz = 50e3
        CurrentMinA = 0
        CurrentMaxA = 2
        ModulationInputMinV = -10
        ModulationInputMaxV = 10
    end

    properties (DiscreteState)
        CurrentStateA
    end

    methods (Access = protected)
        function setupImpl(~, ~)
        end

        function resetImpl(obj)
            obj.CurrentStateA = obj.InitialCurrentA;
        end

        function [driveCurrentA, limited] = stepImpl(obj, modulationVoltageV)
            boundedVoltageV = min(max(modulationVoltageV, ...
                obj.ModulationInputMinV), obj.ModulationInputMaxV);
            requestedCurrentA = obj.BiasCurrentA + ...
                obj.ModulationGainAPerV * boundedVoltageV;
            targetCurrentA = min(max(requestedCurrentA, ...
                obj.CurrentMinA), obj.CurrentMaxA);
            pole = exp(-2 * pi * obj.ModulationBandwidthHz * obj.SampleTimeS);
            obj.CurrentStateA = pole * obj.CurrentStateA + ...
                (1 - pole) * targetCurrentA;
            driveCurrentA = obj.CurrentStateA;
            limited = requestedCurrentA <= obj.CurrentMinA || ...
                requestedCurrentA >= obj.CurrentMaxA;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(~, stateName)
            if strcmp(stateName, 'CurrentStateA')
                stateSize = [1 1];
                stateType = 'double';
                stateComplex = false;
            else
                error('LDC220CModel:UnknownState', ...
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
