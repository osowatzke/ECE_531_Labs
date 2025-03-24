classdef interpControl < keyValueInitializer
    properties
        N;
    end
    properties(Access=protected)
        mu;
        Counter;
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