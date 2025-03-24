classdef gardenerTED < TED
    methods(Access=protected)
        function e = computeTED(self,filtOut)
            % Calculate the midsample point for odd or even samples per symbol
            t1 = self.TEDBuffer(end/2 + 1 - rem(self.N,2));
            t2 = self.TEDBuffer(end/2 + 1);
            midSample = (t1+t2)/2;
            e = real(midSample)*(real(self.TEDBuffer(1))-real(filtOut)) + ...
                imag(midSample)*(imag(self.TEDBuffer(1))-imag(filtOut));
        end
    end
end