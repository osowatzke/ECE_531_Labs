classdef CarrierSychronizer < matlab.System
    properties
        NormalizedLoopBandwidth = 0.01;
        SamplesPerSymbol = 1;
        ModulationOrder = 2;
        DampingFactor = 0.707;
    end
    properties (Access=protected)
        proportionalLoopGain;
        integratorLoopGain;
        eAccum;
        fAccum;
        phaseCorr;
        lastOut;
    end
    methods(Access=protected)
        function setupImpl(self)
            theta = self.NormalizedLoopBandwidth/(self.SamplesPerSymbol * ...
                (self.DampingFactor + 0.25/self.DampingFactor));
            Delta = 1 + 2*self.DampingFactor*theta + theta^2;
            self.proportionalLoopGain = 4*self.DampingFactor*theta/Delta;
            self.integratorLoopGain = (4/self.SamplesPerSymbol)*...
                theta^2/Delta/self.SamplesPerSymbol;
        end
        function resetImpl(self)
            self.eAccum = 0;
            self.fAccum = 0;
            self.phaseCorr = 0;
            self.lastOut = 0;
        end
        function [dataCorr, phaseCorrection] = stepImpl(self, data)
            phaseCorrection = zeros(size(data));
            dataCorr = zeros(size(data));
            for i = 1:length(data)
                e = self.phaseError(self.lastOut);
                dataCorr(i) = data(i)*exp(1i*self.phaseCorr);
                self.lastOut = dataCorr(i);
                self.eAccum = self.eAccum + e;
                phaseCorrection(i) = self.fAccum;
                f = self.proportionalLoopGain*e + ...
                    self.integratorLoopGain*self.eAccum;
                self.fAccum = self.fAccum + f; 
                self.phaseCorr = -phaseCorrection(i);
            end
        end
        function e = phaseError(self, y)
            if self.ModulationOrder == 2
                e = sign(real(y))*imag(y);
            end
        end
    end
end