classdef TED < keyValueInitializer
    properties
        N;
    end
    properties(Access=protected)
        TEDBuffer;
        TriggerHistory;
    end
    methods(Access=protected)
        function e = computeTED(~,~)
            e = 0;
        end
        function resetImpl(self)
            self.TEDBuffer = zeros(1,self.N);
            self.TriggerHistory = zeros(1,self.N);
        end
        function e = stepImpl(self,filtOut,Trigger)
            % Error calculation occurs on a strobe
            if Trigger && all(~self.TriggerHistory(2:end))
                e = self.computeTED(filtOut);
            else
                e = 0;
            end
            % Update TED buffer to manage symbol stuffs
            switch sum([self.TriggerHistory(2:end) Trigger])
                case 0
                  % No update required
                case 1
                  % Shift TED buffer regularly if ONE trigger across N samples
                  self.TEDBuffer = [self.TEDBuffer(2:end), filtOut];
                otherwise % > 1
                  % Stuff a missing sample if TWO triggers across N samples
                  self.TEDBuffer = [self.TEDBuffer(3:end), 0, filtOut];
            end
            % Update trigger history
            self.TriggerHistory = [self.TriggerHistory(2:end), Trigger];
        end
    end
end