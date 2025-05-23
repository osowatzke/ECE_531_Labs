classdef SymbolSynchronizer < keyValueInitializer

    % Public class properties
    properties
        SamplesPerSymbol = 2;
        NormalizedLoopBandwidth = 0.01;
        DetectorGain = 5.4;
        DampingFactor = 1;
        TimingErrorDetector = 'Zero-Crossing (decision-directed)';
    end

    % Protected class properties
    properties(Access=protected)
        % Subobjects
        interp = [];
        TED = [];
        loopFilt = [];
        interpCtrl = [];

        % Class properties from processing loop
        mu;
        Trigger;
    end

    % Public class methods
    methods

        % Class constructor
        function self = SymbolSynchronizer(varargin)

            % Call parent class constructor
            self@keyValueInitializer(varargin{:});
            
            % Map class properties to formula variables
            N = self.SamplesPerSymbol;
            Bloop = self.NormalizedLoopBandwidth;
            GD = self.DetectorGain/N;
            zeta = self.DampingFactor;

            % Solve for the loop filter coefficients
            theta = Bloop/(N*(zeta+0.25/zeta));
            Delta = 1+2*zeta*theta+theta^2;
            G1 = -4*zeta*theta/(GD*N*Delta);
            G2 = -4*theta^2/(GD*N*Delta);

            % Initialize subobjects
            self.interp = ppfInterp;
            if strcmp(self.TimingErrorDetector, 'Zero-Crossing (decision-directed)')
                self.TED = zcTED('N',N);
            elseif strcmp(self.TimingErrorDetector, 'Gardner (non-data-aided)')
                self.TED = gardenerTED('N',N);
            elseif strcmp(self.TimingErrorDetector, 'Mueller-Muller (decision-directed)')
                self.TED = mmTED('N',N);
            else
                error('''%s'' is an unsupported timing error detector method',...
                    self.TimingErrorDetector);
            end
            self.loopFilt = loopFilter(...
                'ProportionalGain',G1,...
                'IntegratorGain',G2);
            self.interpCtrl = interpControl('N',N);
        end
    end

    % Protected class methods
    methods(Access=protected)

        % Reset class properties
        function resetImpl(self)

            % Reset subobjects
            reset(self.interp);
            reset(self.TED);
            reset(self.loopFilt);
            reset(self.interpCtrl);

            % Clear class properties
            self.mu = 0;
            self.Trigger = 0;
        end

        % Class update method
        function [rxSync,timingErr, tedOut] = stepImpl(self,x)

            % Initialize output arrays
            rxSync = zeros(size(x));
            timingErr = zeros(size(x));
            tedOut = zeros(size(x));

            % Initialize output Index
            outIdx = 0;

            % Loop for each input
            for i = 1:length(x)
                timingErr(i) = self.mu;
                filtOut = self.interp(x(i), self.mu);
                if self.Trigger
                    outIdx = outIdx + 1;
                    rxSync(outIdx) = filtOut;
                end
                tedOut(i) = self.TED(filtOut,self.Trigger);
                g = self.loopFilt(tedOut(i));
                [self.mu,self.Trigger] = self.interpCtrl(g);
            end

            % Keep only samples with triggers
            rxSync = rxSync(1:outIdx);
        end
    end
end