% Class defines a coarse frequency compensation object
classdef CoarseFrequencyCompensator < matlab.System

    % Public class properties
    properties
        FrequencyResolution = 100;
        ModulationOrder = 2;
        SampleRate = 1e6;
    end

    % Protected class properties
    properties (Access=protected)
        phaseOffset;
        fftSize;
        sampleBuffer;
    end

    % Public class methods
    methods

        % Class constructor. Allows properties to be set with key-value
        % pairs
        function self = CoarseFrequencyCompensator(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end

    % Protected class methods
    methods(Access=protected)

        % Setup method
        function setupImpl(self)

            % Choose FFT size to next power of 2
            % Note that we also consider the modulation order
            % Have a higher modulation order increases the frequency
            % resolution
            self.fftSize = 2^ceil(log2(self.SampleRate/...
                (self.FrequencyResolution*self.ModulationOrder)));

            % Initialize sample buffer
            self.sampleBuffer = zeros(self.fftSize,1);
        end

        % Reset method
        function resetImpl(self)
            self.phaseOffset = 0;
            self.sampleBuffer = zeros(size(self.sampleBuffer));
        end

        % Step method
        function [data, freqEst, Fdata] = stepImpl(self, data)

            % Raise data to modulation order
            % ^2 for BPSK and ^4 for QPSK
            dataPwr = data.^self.ModulationOrder;

            % Create shift register for incoming data
            % Allows us to perform a STFT using multiple frames of data
            dataLen = length(dataPwr);
            samplesToShift = self.fftSize - dataLen;
            self.sampleBuffer(1:samplesToShift) = ...
                self.sampleBuffer(end-samplesToShift+1:end);
            self.sampleBuffer(end-dataLen+1:end) = dataPwr;

            % Take the FFT
            Fdata = fft(self.sampleBuffer,self.fftSize);

            % Compute the bin of the FFT peak
            % data.*conj(data) is a fast implementation of abs(data).^2
            [~, maxIdx] = max(Fdata.*conj(Fdata));

            % Estimate normalized frequency
            freqEst = (maxIdx-1)/(self.ModulationOrder*self.fftSize);

            % Create time array
            t = (0:(dataLen-1)).';

            % Remove CFO
            data = data.*exp(-1i*(2*pi*freqEst*t+self.phaseOffset));

            % Update phase offset
            self.phaseOffset = mod(-2*pi*freqEst*self.fftSize + ...
                self.phaseOffset, 2*pi);
        end
    end
end