classdef rxDataStream < matlab.System
    properties
        snr_dB = 20;
        samplesPerSymbol = 8;
        filterSymbolSpan = 4;
        numFrames = 200;
        frameSize = 2^10;
        timingDrift = 0.01;
    end
    properties(Access=protected)
        TxFlt;
        RxFlt;
        mod;
        chan;
        varDelay;
        RandStream;
        numSamples;
        modData;
        timingOffset;
    end
    methods
        function self = rxDataStream(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
            self.TxFlt = comm.RaisedCosineTransmitFilter(...
                'OutputSamplesPerSymbol', self.samplesPerSymbol,...
                'FilterSpanInSymbols', self.filterSymbolSpan);
            self.RxFlt = comm.RaisedCosineReceiveFilter(...
                'InputSamplesPerSymbol', self.samplesPerSymbol,...
                'FilterSpanInSymbols', self.filterSymbolSpan,...
                'DecimationFactor', self.samplesPerSymbol/2);
            self.mod = comm.DBPSKModulator();
            self.chan = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)',...
                'SNR',self.snr_dB,'SignalPower',1,'RandomStream', 'mt19937ar with seed');
            self.varDelay = dsp.VariableFractionalDelay;
            self.RandStream = RandStream('mt19937ar');
            self.numSamples = self.numFrames*self.frameSize;
            self.timingOffset = self.samplesPerSymbol*self.timingDrift;
        end
    end
    methods(Access=protected)
        function [filteredData, dly] = stepImpl(self)
            bits = randi([0 1], self.numSamples, 1);
            modulatedData = self.mod(bits);
            filteredTXData = self.TxFlt(modulatedData);
            noisyData = self.chan(filteredTXData);
            offsetData = zeros(size(noisyData));
            for i = 1:self.numFrames
                 s = (i-1)*self.frameSize*self.samplesPerSymbol + 1;
                 e = s + self.frameSize*self.samplesPerSymbol - 1;
                 outIdx = s:e;
                 dly = i*self.timingOffset;
                 intDly = floor(dly);
                 fracDly = dly - intDly;
                 s = s - intDly;
                 e = s + self.frameSize*self.samplesPerSymbol - 1;
                 s_pad = 0;
                 e_pad = 0;
                 if s < 1
                     s_pad = -(s - 1);
                     s = 1;
                 end
                 if e > length(noisyData)
                     e_pad = e - length(noisyData);
                     e = length(noisyData);
                 end
                 inIdx = s:e;
                 offsetData(outIdx) = [zeros(s_pad,1); self.varDelay(noisyData(inIdx), fracDly); zeros(e_pad,1)];
            end
            filteredData = self.RxFlt(offsetData);
        end
        function createData(self)
            bits = randi([0 1], self.numSsamples, 1);
            self.modData = self.mod(bits);
        end
    end
end