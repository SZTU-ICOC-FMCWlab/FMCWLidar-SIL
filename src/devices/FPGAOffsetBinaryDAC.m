classdef FPGAOffsetBinaryDAC < matlab.System
    %FPGAOFFSETBINARYDAC 16 bit offset-binary DAC码到双极性电压。

    properties (Nontunable)
        Bits = 16
        FullScaleV = 2
    end

    methods (Access = protected)
        function voltageV = stepImpl(obj, dacCode)
            voltageV = double(dacCode) / (2^obj.Bits - 1) * ...
                obj.FullScaleV - obj.FullScaleV / 2;
        end

        function size1 = getOutputSizeImpl(~)
            size1 = [1 1];
        end

        function type1 = getOutputDataTypeImpl(~)
            type1 = 'double';
        end

        function complex1 = isOutputComplexImpl(~)
            complex1 = false;
        end

        function fixed1 = isOutputFixedSizeImpl(~)
            fixed1 = true;
        end
    end
end
