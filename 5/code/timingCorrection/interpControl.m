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
            % Interpolation Controller with modulo-1 counter
            d = g + 1/self.N;
            TriggerNext = (self.Counter < d); % Check if a trigger condition
            muNext = self.mu;
            if TriggerNext % Upate mu if a trigger
                muNext = self.Counter/d;
            end
            self.mu = muNext;
            self.Counter = mod(self.Counter - d, 1); % Update counter
        end
    end
end