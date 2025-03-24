classdef loopFilter < keyValueInitializer
    properties
        ProportionalGain = 0;
        IntegratorGain = 0;
    end
    properties(Access=protected)
        eAccum = 0;
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