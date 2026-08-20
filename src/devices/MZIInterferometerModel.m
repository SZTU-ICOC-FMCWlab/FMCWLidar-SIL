classdef MZIInterferometerModel < matlab.System
    %MZIINTERFEROMETERMODEL 50 ns 延迟MZI的两个互补光功率输出。

    properties (Nontunable)
        SampleTimeS = 10e-9
        DelayS = 50e-9
        TapPowerRatio = 1e-4
        InsertionTransmission = 0.90
        BiasPhaseRad = 0
    end

    properties (DiscreteState)
        DelayBuffer
        DelayIndex
    end

    methods (Access = protected)
        function setupImpl(~, ~)
        end

        function resetImpl(obj)
            delaySamples = max(1, round(obj.DelayS / obj.SampleTimeS));
            obj.DelayBuffer = complex(zeros(delaySamples, 1));
            obj.DelayIndex = 1;
        end

        function [powerPlusW, powerMinusW] = stepImpl(obj, opticalField)
            delayIndex = obj.DelayIndex;
            delayedField = obj.DelayBuffer(delayIndex);
            obj.DelayBuffer(delayIndex) = opticalField;
            delayIndex = delayIndex + 1;
            if delayIndex > numel(obj.DelayBuffer)
                delayIndex = 1;
            end
            obj.DelayIndex = delayIndex;

            fieldScale = sqrt(obj.TapPowerRatio * obj.InsertionTransmission);
            armNow = fieldScale * opticalField;
            armDelayed = fieldScale * delayedField * ...
                complex(cos(obj.BiasPhaseRad), sin(obj.BiasPhaseRad));
            fieldPlus = 0.5 * (armNow + armDelayed);
            fieldMinus = 0.5 * (armNow - armDelayed);
            powerPlusW = abs(fieldPlus)^2;
            powerMinusW = abs(fieldMinus)^2;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(obj, stateName)
            if strcmp(stateName, 'DelayBuffer')
                stateSize = [max(1, round(obj.DelayS / obj.SampleTimeS)) 1];
                stateType = 'double';
                stateComplex = true;
            elseif strcmp(stateName, 'DelayIndex')
                stateSize = [1 1];
                stateType = 'double';
                stateComplex = false;
            else
                error('MZIInterferometerModel:UnknownState', ...
                    'Unknown discrete state: %s', stateName);
            end
        end

        function [size1, size2] = getOutputSizeImpl(~)
            size1 = [1 1]; size2 = [1 1];
        end

        function [type1, type2] = getOutputDataTypeImpl(~)
            type1 = 'double'; type2 = 'double';
        end

        function [complex1, complex2] = isOutputComplexImpl(~)
            complex1 = false; complex2 = false;
        end

        function [fixed1, fixed2] = isOutputFixedSizeImpl(~)
            fixed1 = true; fixed2 = true;
        end
    end
end
