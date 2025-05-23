classdef zcTED < TED
    methods(Access=protected)
        function e = computeTED(self,filtOut)
            % Calculate the midsample point for odd or even samples per symbol
            t1 = self.TEDBuffer(end/2 + 1 - rem(self.N,2));
            t2 = self.TEDBuffer(end/2 + 1);
            midSample = (t1+t2)/2;
            e = real(midSample)*(sign(real(self.TEDBuffer(1)))-sign(real(filtOut))) + ...
                imag(midSample)*(sign(imag(self.TEDBuffer(1)))-sign(imag(filtOut)));
        end
    end
end