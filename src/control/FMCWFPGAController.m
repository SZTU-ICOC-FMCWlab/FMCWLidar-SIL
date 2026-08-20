classdef FMCWFPGAController < matlab.System
    %FMCWFPGAController FIL可替换的多chirp整数控制器参考模型。
    % 输入: adcCode, enable, reset, faultIn
    % 输出: dacCode, chirpStart, chirpActive, lutWriteEnable,
    % phaseErrorHz, controllerState, chirpNumber, faultOut
    %
    % NCO和I/Q数据通路使用整数查表、整数乘法和101点滑动累加。
    % atan2在此作为CORDIC的行为参考;FIL阶段由RTL CORDIC替换。

    properties (Nontunable)
        ChirpSamples = 5000
        PrechargeSamples = 2000
        UpdateSamples = 5000
        IdleSamples = 23000
        EdgeSamples = 300
        DacBits = 16
        DacFullScaleV = 2
        BiasCurrentA = 650e-3
        CurrentGainAPerV = 200e-3
        ActualDriverBandwidthHz = 50e3
        SampleTimeS = 10e-9
        LaserSensitivityHzPerA = -0.3e12
        SweepBandwidthHz = 3e9
        MziDelaySamples = 5
        NcoStep = uint16(3)
        LearningNumerator = 13
        LearningDenominator = 20
    end

    properties (DiscreteState)
        LutBankA
        LutBankB
        CorrectionResidualHz
        FrequencyErrorMemoryHz
        IProductBuffer
        QProductBuffer
        ActiveBank
        ControllerState
        StateCounter
        LutIndex
        UpdateIndex
        ChirpNumber
        NcoIndex
        IqBufferIndex
        ISum
        QSum
        PreviousPhaseCode
        UnwrappedPhaseCode
        PhaseReferenceCode
        PhaseReferenceValid
        FrequencyErrorSumHz
        FrequencyErrorCount
        FrequencyErrorMeanHz
        CurrentPhaseErrorHz
        FaultLatched
    end

    properties (Constant, Access = private)
        StatePrecharge = uint8(1)
        StateChirp = uint8(2)
        StateUpdate = uint8(3)
        StateIdle = uint8(4)
        StateFault = uint8(5)
        PhaseScalePerPi = 268435456
        NcoLength = 100
        IqFilterLength = 101
        NcoCosLut = int16([32767 32702 32509 32187 31738 31163 30466 29648 28714 27666 26509 25247 23886 22431 20886 19260 17557 15786 13952 12062 10126 8149 6140 4107 2057 0 -2057 -4107 -6140 -8149 -10126 -12062 -13952 -15786 -17557 -19260 -20886 -22431 -23886 -25247 -26509 -27666 -28714 -29648 -30466 -31163 -31738 -32187 -32509 -32702 -32767 -32702 -32509 -32187 -31738 -31163 -30466 -29648 -28714 -27666 -26509 -25247 -23886 -22431 -20886 -19260 -17557 -15786 -13952 -12062 -10126 -8149 -6140 -4107 -2057 0 2057 4107 6140 8149 10126 12062 13952 15786 17557 19260 20886 22431 23886 25247 26509 27666 28714 29648 30466 31163 31738 32187 32509 32702])
        NcoSinLut = int16([0 -2057 -4107 -6140 -8149 -10126 -12062 -13952 -15786 -17557 -19260 -20886 -22431 -23886 -25247 -26509 -27666 -28714 -29648 -30466 -31163 -31738 -32187 -32509 -32702 -32767 -32702 -32509 -32187 -31738 -31163 -30466 -29648 -28714 -27666 -26509 -25247 -23886 -22431 -20886 -19260 -17557 -15786 -13952 -12062 -10126 -8149 -6140 -4107 -2057 0 2057 4107 6140 8149 10126 12062 13952 15786 17557 19260 20886 22431 23886 25247 26509 27666 28714 29648 30466 31163 31738 32187 32509 32702 32767 32702 32509 32187 31738 31163 30466 29648 28714 27666 26509 25247 23886 22431 20886 19260 17557 15786 13952 12062 10126 8149 6140 4107 2057])
    end

    methods (Access = protected)
        function setupImpl(~, ~, ~, ~, ~)
        end

        function resetImpl(obj)
            obj.LutBankA = zeros(obj.ChirpSamples, 1, 'uint16');
            obj.LutBankB = zeros(obj.ChirpSamples, 1, 'uint16');
            obj.CorrectionResidualHz = zeros(obj.ChirpSamples, 1, 'int64');
            obj.FrequencyErrorMemoryHz = zeros(obj.ChirpSamples, 1, 'int32');
            obj.IProductBuffer = zeros(obj.IqFilterLength, 1, 'int32');
            obj.QProductBuffer = zeros(obj.IqFilterLength, 1, 'int32');

            pole = exp(-2 * pi * obj.ActualDriverBandwidthHz * obj.SampleTimeS);
            currentStartA = obj.BiasCurrentA + ...
                (-obj.SweepBandwidthHz / 2) / obj.LaserSensitivityHzPerA;
            currentEndA = obj.BiasCurrentA + ...
                (obj.SweepBandwidthHz / 2) / obj.LaserSensitivityHzPerA;
            currentStepA = (currentEndA - currentStartA) / ...
                (obj.ChirpSamples - 1);
            previousDesiredA = currentStartA;
            for sampleIndex = 1:obj.ChirpSamples
                desiredCurrentA = currentStartA + (sampleIndex - 1) * currentStepA;
                preEmphasizedCurrentA = (desiredCurrentA - ...
                    pole * previousDesiredA) / (1 - pole);
                modulationVoltageV = (preEmphasizedCurrentA - ...
                    obj.BiasCurrentA) / obj.CurrentGainAPerV;
                modulationVoltageV = min(max(modulationVoltageV, ...
                    -obj.DacFullScaleV / 2), obj.DacFullScaleV / 2);
                dacCode = uint16(round((modulationVoltageV + ...
                    obj.DacFullScaleV / 2) / obj.DacFullScaleV * ...
                    (2^obj.DacBits - 1)));
                obj.LutBankA(sampleIndex) = dacCode;
                obj.LutBankB(sampleIndex) = dacCode;
                previousDesiredA = desiredCurrentA;
            end

            obj.ActiveBank = false;
            obj.ControllerState = obj.StatePrecharge;
            obj.StateCounter = uint32(0);
            obj.LutIndex = uint32(0);
            obj.UpdateIndex = uint32(0);
            obj.ChirpNumber = uint8(1);
            obj.NcoIndex = uint16(0);
            obj.IqBufferIndex = uint16(1);
            obj.ISum = int64(0);
            obj.QSum = int64(0);
            obj.PreviousPhaseCode = int32(0);
            obj.UnwrappedPhaseCode = int64(0);
            obj.PhaseReferenceCode = int64(0);
            obj.PhaseReferenceValid = false;
            obj.FrequencyErrorSumHz = int64(0);
            obj.FrequencyErrorCount = uint32(0);
            obj.FrequencyErrorMeanHz = int32(0);
            obj.CurrentPhaseErrorHz = int32(0);
            obj.FaultLatched = false;
        end

        function [dacCode, chirpStart, chirpActive, lutWriteEnable, ...
                phaseErrorHz, controllerState, chirpNumber, faultOut] = ...
                stepImpl(obj, adcCode, enable, reset, faultIn)
            if reset
                resetImpl(obj);
            end
            if faultIn
                obj.FaultLatched = true;
                obj.ControllerState = obj.StateFault;
            end

            dacCode = readActiveLut(obj, 1);
            chirpStart = false;
            chirpActive = false;
            lutWriteEnable = false;
            phaseErrorHz = obj.CurrentPhaseErrorHz;
            chirpNumber = obj.ChirpNumber;
            faultOut = obj.FaultLatched;

            if ~enable
                obj.ControllerState = obj.StatePrecharge;
                obj.StateCounter = uint32(0);
                controllerState = obj.ControllerState;
                return;
            end

            switch obj.ControllerState
                case obj.StatePrecharge
                    dacCode = readActiveLut(obj, 1);
                    if obj.StateCounter + 1 >= obj.PrechargeSamples
                        beginChirp(obj);
                    else
                        obj.StateCounter = obj.StateCounter + 1;
                    end

                case obj.StateChirp
                    chirpActive = true;
                    chirpStart = obj.LutIndex == 0;
                    lutAddress = double(obj.LutIndex) + 1;
                    dacCode = readActiveLut(obj, lutAddress);
                    updatePhaseEstimator(obj, adcCode, double(obj.LutIndex));
                    phaseErrorHz = obj.CurrentPhaseErrorHz;
                    if obj.LutIndex + 1 >= obj.ChirpSamples
                        if obj.FrequencyErrorCount > 0
                            obj.FrequencyErrorMeanHz = int32(round( ...
                                double(obj.FrequencyErrorSumHz) / ...
                                double(obj.FrequencyErrorCount)));
                        else
                            obj.FrequencyErrorMeanHz = int32(0);
                        end
                        obj.ControllerState = obj.StateUpdate;
                        obj.UpdateIndex = uint32(0);
                    else
                        obj.LutIndex = obj.LutIndex + 1;
                    end

                case obj.StateUpdate
                    dacCode = readActiveLut(obj, 1);
                    lutWriteEnable = true;
                    updateAddress = double(obj.UpdateIndex) + 1;
                    updateLutWord(obj, updateAddress);
                    if obj.UpdateIndex + 1 >= obj.UpdateSamples
                        obj.ActiveBank = ~obj.ActiveBank;
                        obj.ControllerState = obj.StateIdle;
                        obj.StateCounter = uint32(0);
                        if obj.ChirpNumber < intmax('uint8')
                            obj.ChirpNumber = obj.ChirpNumber + 1;
                        end
                    else
                        obj.UpdateIndex = obj.UpdateIndex + 1;
                    end

                case obj.StateIdle
                    dacCode = readActiveLut(obj, 1);
                    if obj.StateCounter + 1 >= obj.IdleSamples
                        obj.ControllerState = obj.StatePrecharge;
                        obj.StateCounter = uint32(0);
                    else
                        obj.StateCounter = obj.StateCounter + 1;
                    end

                otherwise
                    dacCode = readActiveLut(obj, 1);
                    obj.FaultLatched = true;
                    obj.ControllerState = obj.StateFault;
            end

            controllerState = obj.ControllerState;
            chirpNumber = obj.ChirpNumber;
            faultOut = obj.FaultLatched;
        end

        function [stateSize, stateType, stateComplex] = ...
                getDiscreteStateSpecificationImpl(obj, stateName)
            if strcmp(stateName, 'LutBankA') || strcmp(stateName, 'LutBankB')
                stateSize = [obj.ChirpSamples 1]; stateType = 'uint16';
            elseif strcmp(stateName, 'CorrectionResidualHz')
                stateSize = [obj.ChirpSamples 1]; stateType = 'int64';
            elseif strcmp(stateName, 'FrequencyErrorMemoryHz')
                stateSize = [obj.ChirpSamples 1]; stateType = 'int32';
            elseif strcmp(stateName, 'IProductBuffer') || ...
                    strcmp(stateName, 'QProductBuffer')
                stateSize = [obj.IqFilterLength 1]; stateType = 'int32';
            elseif strcmp(stateName, 'ActiveBank') || ...
                    strcmp(stateName, 'PhaseReferenceValid') || ...
                    strcmp(stateName, 'FaultLatched')
                stateSize = [1 1]; stateType = 'logical';
            elseif strcmp(stateName, 'ControllerState') || ...
                    strcmp(stateName, 'ChirpNumber')
                stateSize = [1 1]; stateType = 'uint8';
            elseif strcmp(stateName, 'NcoIndex') || ...
                    strcmp(stateName, 'IqBufferIndex')
                stateSize = [1 1]; stateType = 'uint16';
            elseif strcmp(stateName, 'StateCounter') || ...
                    strcmp(stateName, 'LutIndex') || ...
                    strcmp(stateName, 'UpdateIndex') || ...
                    strcmp(stateName, 'FrequencyErrorCount')
                stateSize = [1 1]; stateType = 'uint32';
            elseif strcmp(stateName, 'ISum') || strcmp(stateName, 'QSum') || ...
                    strcmp(stateName, 'UnwrappedPhaseCode') || ...
                    strcmp(stateName, 'PhaseReferenceCode') || ...
                    strcmp(stateName, 'FrequencyErrorSumHz')
                stateSize = [1 1]; stateType = 'int64';
            elseif strcmp(stateName, 'PreviousPhaseCode') || ...
                    strcmp(stateName, 'FrequencyErrorMeanHz') || ...
                    strcmp(stateName, 'CurrentPhaseErrorHz')
                stateSize = [1 1]; stateType = 'int32';
            else
                error('FMCWFPGAController:UnknownState', ...
                    'Unknown discrete state: %s', stateName);
            end
            stateComplex = false;
        end

        function [s1,s2,s3,s4,s5,s6,s7,s8] = getOutputSizeImpl(~)
            s1=[1 1]; s2=[1 1]; s3=[1 1]; s4=[1 1];
            s5=[1 1]; s6=[1 1]; s7=[1 1]; s8=[1 1];
        end

        function [t1,t2,t3,t4,t5,t6,t7,t8] = getOutputDataTypeImpl(~)
            t1='uint16'; t2='logical'; t3='logical'; t4='logical';
            t5='int32'; t6='uint8'; t7='uint8'; t8='logical';
        end

        function [c1,c2,c3,c4,c5,c6,c7,c8] = isOutputComplexImpl(~)
            c1=false; c2=false; c3=false; c4=false;
            c5=false; c6=false; c7=false; c8=false;
        end

        function [f1,f2,f3,f4,f5,f6,f7,f8] = isOutputFixedSizeImpl(~)
            f1=true; f2=true; f3=true; f4=true;
            f5=true; f6=true; f7=true; f8=true;
        end
    end

    methods (Access = private)
        function code = readActiveLut(obj, address)
            if obj.ActiveBank
                code = obj.LutBankB(address);
            else
                code = obj.LutBankA(address);
            end
        end

        function beginChirp(obj)
            obj.ControllerState = obj.StateChirp;
            obj.StateCounter = uint32(0);
            obj.LutIndex = uint32(0);
            obj.NcoIndex = uint16(0);
            obj.IqBufferIndex = uint16(1);
            obj.ISum = int64(0);
            obj.QSum = int64(0);
            obj.IProductBuffer(:) = int32(0);
            obj.QProductBuffer(:) = int32(0);
            obj.PreviousPhaseCode = int32(0);
            obj.UnwrappedPhaseCode = int64(0);
            obj.PhaseReferenceCode = int64(0);
            obj.PhaseReferenceValid = false;
            obj.FrequencyErrorMemoryHz(:) = int32(0);
            obj.FrequencyErrorSumHz = int64(0);
            obj.FrequencyErrorCount = uint32(0);
            obj.FrequencyErrorMeanHz = int32(0);
            obj.CurrentPhaseErrorHz = int32(0);
        end

        function updatePhaseEstimator(obj, adcCode, sampleIndex)
            ncoAddress = double(obj.NcoIndex) + 1;
            iProduct = int32(adcCode) * int32(obj.NcoCosLut(ncoAddress));
            qProduct = int32(adcCode) * int32(obj.NcoSinLut(ncoAddress));
            bufferAddress = double(obj.IqBufferIndex);
            obj.ISum = obj.ISum + int64(iProduct) - ...
                int64(obj.IProductBuffer(bufferAddress));
            obj.QSum = obj.QSum + int64(qProduct) - ...
                int64(obj.QProductBuffer(bufferAddress));
            obj.IProductBuffer(bufferAddress) = iProduct;
            obj.QProductBuffer(bufferAddress) = qProduct;

            if obj.IqBufferIndex >= obj.IqFilterLength
                obj.IqBufferIndex = uint16(1);
            else
                obj.IqBufferIndex = obj.IqBufferIndex + 1;
            end
            nextNcoIndex = obj.NcoIndex + obj.NcoStep;
            if nextNcoIndex >= obj.NcoLength
                obj.NcoIndex = nextNcoIndex - uint16(obj.NcoLength);
            else
                obj.NcoIndex = nextNcoIndex;
            end

            phaseRad = atan2(double(obj.QSum), double(obj.ISum));
            phaseCode = int32(round(phaseRad / pi * obj.PhaseScalePerPi));
            if sampleIndex == 0
                obj.PreviousPhaseCode = phaseCode;
                obj.UnwrappedPhaseCode = int64(phaseCode);
            else
                phaseDelta = int64(phaseCode) - int64(obj.PreviousPhaseCode);
                wrapCode = int64(2 * obj.PhaseScalePerPi);
                if phaseDelta > obj.PhaseScalePerPi
                    phaseDelta = phaseDelta - wrapCode;
                elseif phaseDelta < -obj.PhaseScalePerPi
                    phaseDelta = phaseDelta + wrapCode;
                end
                obj.UnwrappedPhaseCode = obj.UnwrappedPhaseCode + phaseDelta;
                obj.PreviousPhaseCode = phaseCode;
            end

            if sampleIndex == obj.EdgeSamples
                obj.PhaseReferenceCode = obj.UnwrappedPhaseCode;
                obj.PhaseReferenceValid = true;
            end
            if obj.PhaseReferenceValid
                phaseErrorCode = obj.UnwrappedPhaseCode - obj.PhaseReferenceCode;
                frequencyError = int32(round(double(phaseErrorCode) / ...
                    (2 * obj.PhaseScalePerPi * obj.SampleTimeS * ...
                    obj.MziDelaySamples)));
                obj.CurrentPhaseErrorHz = frequencyError;
                memoryAddress = sampleIndex + 1;
                obj.FrequencyErrorMemoryHz(memoryAddress) = frequencyError;
                if sampleIndex >= obj.EdgeSamples && ...
                        sampleIndex < obj.ChirpSamples - obj.EdgeSamples
                    obj.FrequencyErrorSumHz = obj.FrequencyErrorSumHz + ...
                        int64(frequencyError);
                    obj.FrequencyErrorCount = obj.FrequencyErrorCount + 1;
                end
            end
        end

        function updateLutWord(obj, address)
            extrapolationSpan = int64(50);
            leftBoundary = obj.EdgeSamples + 1;
            rightBoundary = obj.ChirpSamples - obj.EdgeSamples;
            if address <= leftBoundary
                leftError = int64(obj.FrequencyErrorMemoryHz(leftBoundary));
                leftDelta = int64(obj.FrequencyErrorMemoryHz( ...
                    leftBoundary + double(extrapolationSpan))) - leftError;
                endpointErrorHz = leftError + idivide(leftDelta * ...
                    int64(address - leftBoundary), extrapolationSpan, 'round');
            elseif address > rightBoundary
                rightError = int64(obj.FrequencyErrorMemoryHz(rightBoundary));
                rightDelta = rightError - int64(obj.FrequencyErrorMemoryHz( ...
                    rightBoundary - double(extrapolationSpan)));
                endpointErrorHz = rightError + idivide(rightDelta * ...
                    int64(address - rightBoundary), extrapolationSpan, 'round');
            else
                endpointErrorHz = int64(obj.FrequencyErrorMemoryHz(address));
            end
            centeredErrorHz = endpointErrorHz - int64(obj.FrequencyErrorMeanHz);
            learnedErrorHz = idivide(centeredErrorHz * ...
                int64(obj.LearningNumerator), int64(obj.LearningDenominator), 'round');
            accumulatedHz = obj.CorrectionResidualHz(address) + learnedErrorHz;
            hzPerCode = abs(obj.LaserSensitivityHzPerA * ...
                obj.CurrentGainAPerV * obj.DacFullScaleV / ...
                (2^obj.DacBits - 1));
            correctionCode = int64(round(double(accumulatedHz) / hzPerCode));
            obj.CorrectionResidualHz(address) = int64(round( ...
                double(accumulatedHz) - double(correctionCode) * hzPerCode));
            activeCode = int64(readActiveLut(obj, address));
            correctedCode = min(max(activeCode + correctionCode, int64(0)), ...
                int64(2^obj.DacBits - 1));
            if obj.ActiveBank
                obj.LutBankA(address) = uint16(correctedCode);
            else
                obj.LutBankB(address) = uint16(correctedCode);
            end
        end
    end
end
