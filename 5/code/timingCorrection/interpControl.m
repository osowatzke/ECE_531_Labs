classdef interpControl < matlab.System
    properties(Access=protected)
        N = 2;
        mu;
        Counter;
    end
    methods
        function self = interpControl(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
    methods(Access=protected)
        function resetImpl(self)
            self.mu = 0;
            self.Counter = 0;
        end
        function [muNext, TriggerNext] = stepImpl(self, g)
            d = g + 1/self.N;
            TriggerNext = (self.Counter < d);
            muNext = self.mu;
            if TriggerNext
                muNext = self.Counter/d;
            end
            self.mu = muNext;
            self.Counter = mod(self.Counter - d, 1);
        end
    end
end