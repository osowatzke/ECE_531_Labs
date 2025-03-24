classdef zcTED < keyValueInitializer
    properties
        N;
    end
    properties(Access=protected)
        TEDBuffer;
        TriggerHistory;
    end
    methods(Access=protected)
        function resetImpl(self)
            self.TEDBuffer = zeros(1,self.N);
            self.TriggerHistory = zeros(1,self.N);
        end
        function e = stepImpl(self,filtOut,Trigger)
           if Trigger && all(~self.TriggerHistory(2:end))
                % Calculate the midsample point for odd or even samples per symbol
                t1 = self.TEDBuffer(end/2 + 1 - rem(self.N,2));
                t2 = self.TEDBuffer(end/2 + 1);
                midSample = (t1+t2)/2;
                e = real(midSample)*(sign(real(self.TEDBuffer(1)))-sign(real(filtOut))) + ...
                    imag(midSample)*(sign(imag(self.TEDBuffer(1)))-sign(imag(filtOut)));
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