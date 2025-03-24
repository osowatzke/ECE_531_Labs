classdef loopFilter < matlab.System
    properties(Access=protected)
        ProportionalGain = 0;
        IntegratorGain = 0;
        eAccum = 0;
    end
    methods
        function self = loopFilter(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
    methods(Access=protected)
        function resetImpl(self)
            self.eAccum = 0;
        end
        function g = stepImpl(self, e)
            self.eAccum = self.eAccum + e;
            g = e*self.ProportionalGain + self.eAccum*self.IntegratorGain;
        end
    end
end