classdef zcTED < matlab.System
    properties(Access=protected)
        N;
        TEDBuffer;
    end
    methods
        function self = zcTED(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};
            end
        end
    end
    methods(Access=protected)
        function resetImpl(self)
            self.TEDBuffer = zeros(1,self.N);
        end
        function e = stepImpl(self,filtOut,Trigger,TriggerHistory)
           if Trigger && all(~TriggerHistory(2:end))
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
            switch sum([TriggerHistory(2:end) Trigger])
                case 0
                  % No update required
                case 1
                  % Shift TED buffer regularly if ONE trigger across N samples
                  self.TEDBuffer = [self.TEDBuffer(2:end), filtOut];
                otherwise % > 1
                  % Stuff a missing sample if TWO triggers across N samples
                  self.TEDBuffer = [self.TEDBuffer(3:end), 0, filtOut];
            end
        end
    end
end