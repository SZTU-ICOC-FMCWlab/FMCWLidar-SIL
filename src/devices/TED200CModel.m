classdef TED200CModel < matlab.System
    %TED200CMODEL TED200C 与激光组件热负载的慢速稳温模型。

    properties (Nontunable)
        SampleTimeS = 10e-9
        InitialTemperatureC = 25
        AmbientTemperatureC = 25
        ThermalTimeConstantS = 2
        MinimumSetpointC = 15
        MaximumSetpointC = 35
    end

    properties (DiscreteState)
        TemperatureStateC
    end

    methods (Access = protected)
        function setupImpl(~, ~)
        end

        function resetImpl(obj)
            obj.TemperatureStateC = obj.InitialTemperatureC;
        end

        function [laserTemperatureC, withinRange] = stepImpl(obj, setpointC)
            thermalPole = exp(-obj.SampleTimeS / obj.ThermalTimeConstantS);
            obj.TemperatureStateC = thermalPole * obj.TemperatureStateC + ...
                (1 - thermalPole) * setpointC;
            laserTemperatureC = obj.TemperatureStateC;
            withinRange = setpointC >= obj.MinimumSetpointC && ...
                setpointC <= obj.MaximumSetpointC && ...
                obj.AmbientTemperatureC >= 0 && obj.AmbientTemperatureC <= 40;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(~, stateName)
            if strcmp(stateName, 'TemperatureStateC')
                stateSize = [1 1];
                stateType = 'double';
                stateComplex = false;
            else
                error('TED200CModel:UnknownState', ...
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
