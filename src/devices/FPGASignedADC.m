classdef FPGASignedADC < matlab.System
    %FPGASIGNEDADC 双极性电压到14 bit有符号ADC码的量化模型。

    properties (Nontunable)
        Bits = 14
        FullScaleV = 2
    end

    methods (Access = protected)
        function [adcCode, clipped] = stepImpl(obj, voltageV)
            maximumCode = 2^(obj.Bits - 1) - 1;
            minimumCode = -2^(obj.Bits - 1);
            scaledCode = round(voltageV / (obj.FullScaleV / 2) * maximumCode);
            clipped = scaledCode > maximumCode || scaledCode < minimumCode;
            scaledCode = min(max(scaledCode, minimumCode), maximumCode);
            adcCode = int16(scaledCode);
        end

        function [size1, size2] = getOutputSizeImpl(~)
            size1 = [1 1]; size2 = [1 1];
        end

        function [type1, type2] = getOutputDataTypeImpl(~)
            type1 = 'int16'; type2 = 'logical';
        end

        function [complex1, complex2] = isOutputComplexImpl(~)
            complex1 = false; complex2 = false;
        end

        function [fixed1, fixed2] = isOutputFixedSizeImpl(~)
            fixed1 = true; fixed2 = true;
        end
    end
end
