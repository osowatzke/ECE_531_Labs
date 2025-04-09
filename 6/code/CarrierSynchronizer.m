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
        eAccum;
        fAccum;
        phaseCorr;
        lastOut;
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
            else
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
            self.eAccum = 0;
            self.fAccum = 0;
            self.phaseCorr = 0;
            self.lastOut = 0;
        end

        % Step method
        function [dataCorr, phaseCorrection] = stepImpl(self, data)
            
            % Initialize input arrays
            phaseCorrection = zeros(size(data));
            dataCorr = zeros(size(data));

            % Loop for each input sample
            for i = 1:length(data)
                
                % Compute phase error
                e = self.phaseError(self.lastOut);

                % Apply fine carrier synchronization
                dataCorr(i) = data(i)*exp(1i*self.phaseCorr);

                % Save last output
                self.lastOut = dataCorr(i);

                % Integrator in loop filter
                self.eAccum = self.eAccum + e;

                % Compute phase correction
                phaseCorrection(i) = self.fAccum;

                % Perform loop filter
                f = self.proportionalLoopGain*e + ...
                    self.integratorLoopGain*self.eAccum;

                % Perform integrator
                self.fAccum = self.fAccum + f;

                % Get phase estimate
                self.phaseCorr = -phaseCorrection(i);
            end
        end

        % Function computes the phase error
        function e = phaseError(self, y)
            if self.ModulationOrder == 2
                e = sign(real(y))*imag(y);
            else
                e = sign(real(y))*imag(y) - ...
                    sign(imag(y))*real(y);
            end
        end
    end
end