classdef PreambleDetector < matlab.System
    properties
        Threshold = 3;
        Preamble = [1+1i; 1-1i];
        Detections = 'All';
    end
    properties(Access=protected)
        detectAll;
        dataR;
        mf;
    end
    methods
        % Initialize class properties with name-value pairs
        function self = PreambleDetector(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
    methods(Access=protected)
        function setupImpl(self)
            % Create shift register
            self.dataR = zeros(length(self.Preamble)-1,1);

            % Determine matched filter
            self.mf = flip(conj(self.Preamble));

            % Determine detection mode
            self.detectAll = strcmp(self.Detections,'All');
        end
        function resetImpl(self)
            % Clear shift register
            self.dataR = zeros(size(self.dataR));
        end
        function [idx, crossCorr] = stepImpl(self, data)

            % Concatenate with previously input data
            data = [self.dataR; data(:)];

            % Run matched filter on input
            crossCorr = filter(self.mf,1,data);

            % Remove appended data samples
            crossCorr = crossCorr(length(self.Preamble):end);
            
            % Detect end of preamble
            if self.detectAll
                idx = find(abs(crossCorr) > self.Threshold);
            else
                idx = find(abs(crossCorr) > self.Threshold, 1, 'first');
            end

            % Update shift register
            self.dataR = data(end-length(self.Preamble)+2:end);
        end
    end
end