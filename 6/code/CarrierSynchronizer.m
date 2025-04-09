% Class defines a fine carrier synchronizer object
classdef CarrierSynchronizer < matlab.System

    % Public class properties
    properties
        NormalizedLoopBandwidth = 0.01;
        SamplesPerSymbol = 1;
        ModulationOrder = 2;
        DampingFactor = 0.707;
    end

    % Protected class properties
    properties (Access=protected)
        proportionalLoopGain;
        integratorLoopGain;
        detectorGain;
        phaseCorr;
        dataSyncLast;
        phaseErrAccum;
        phaseAccum;
    end

    % Public class methods
    methods

        % Class constructor. Allows properties to be set with key-value
        % pairs
        function self = CarrierSynchronizer(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end

    % Protected class methods
    methods(Access=protected)

        % Setup method
        function setupImpl(self)
           

            % Compute the detector gain
            if self.ModulationOrder == 2
                self.detectorGain = 1;
            else % Assume QPSK
                self.detectorGain = 2;
            end

            % Compute proportional and integrator loop gain
            theta = self.NormalizedLoopBandwidth/(self.SamplesPerSymbol * ...
                (self.DampingFactor + 0.25/self.DampingFactor));
            Delta = 1 + 2*self.DampingFactor*theta + theta^2;
            self.proportionalLoopGain = 4*self.DampingFactor*theta/...
                Delta/(self.SamplesPerSymbol*self.detectorGain);
            self.integratorLoopGain = (4/self.SamplesPerSymbol)*...
                theta^2/Delta/(self.SamplesPerSymbol*self.detectorGain);
        end

        % Reset method
        function resetImpl(self)
            self.phaseCorr = 0;
            self.dataSyncLast = 0;
            self.phaseErrAccum = 0;
            self.phaseAccum = 0;
        end

        % Step method
        function [dataSync, phaseEst] = stepImpl(self, data)
            
            % Initialize input arrays
            dataSync = zeros(size(data));
            phaseEst = zeros(size(data));

            % Loop for each input sample
            for i = 1:length(data)
                
                % Compute phase error
                phaseErr = self.computePhaseError(self.dataSyncLast);

                % Apply fine carrier synchronization
                dataSync(i) = data(i)*exp(1i*self.phaseCorr);

                % Save last output
                self.dataSyncLast = dataSync(i);

                % Integrator in loop filter
                self.phaseErrAccum = self.phaseErrAccum + phaseErr;

                % Compute phase estimate
                phaseEst(i) = self.phaseAccum;

                % Get phase correction
                self.phaseCorr = -phaseEst(i);

                % Perform loop filter
                phase = self.proportionalLoopGain*phaseErr + ...
                    self.integratorLoopGain*self.phaseErrAccum;

                % Perform integrator
                self.phaseAccum = self.phaseAccum + phase;
            end
        end

        % Function computes the phase error
        function e = computePhaseError(self, y)
            if self.ModulationOrder == 2
                e = sign(real(y))*imag(y);
            else % Assume QPSK
                e = sign(real(y))*imag(y) - ...
                    sign(imag(y))*real(y);
            end
        end
    end
end