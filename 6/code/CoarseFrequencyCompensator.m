classdef CoarseFrequencyCompensator < matlab.System
    properties
        FrequencyResolution = 100;
        ModOrder = 2;
        SampleRate = 1e6;
    end
    properties (Access=protected)
        phaseOffset;
        fftSize;
        sampleBuffer;
    end
    methods
        function self = CoarseFrequencyCompensator(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
    methods(Access=protected)
        function setupImpl(self)
            self.fftSize = 2^ceil(log2(self.SampleRate/...
                (self.FrequencyResolution*self.ModOrder)));
            self.sampleBuffer = zeros(self.fftSize,1);
        end
        function resetImpl(self)
            self.phaseOffset = 0;
            self.sampleBuffer = zeros(size(self.sampleBuffer));
        end
        function data = stepImpl(self, data)
            dataPwr = data.^self.ModOrder;
            dataLen = length(dataPwr);
            samplesToShift = self.fftSize - dataLen;
            self.sampleBuffer(1:samplesToShift) = ...
                self.sampleBuffer(end-samplesToShift+1:end);
            self.sampleBuffer(end-dataLen+1:end) = dataPwr;
            Fdata = fft(self.sampleBuffer,self.fftSize);
            [~, maxIdx] = max(Fdata.*conj(Fdata));
            freqEst = (maxIdx-1)/(self.ModOrder*self.fftSize);
            t = (0:(dataLen-1)).';
            data = data.*exp(-1i*2*pi*freqEst*t+self.phaseOffset);
            self.phaseOffset = mod(-2*pi*freqEst*self.fftSize + ...
                self.phaseOffset, 2*pi);
        end
    end
end