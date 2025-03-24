classdef mmTED < TED
    methods(Access=protected)
        function e = computeTED(self,filtOut)
            e = real(filtOut)*sign(real(self.TEDBuffer(1))) - ...
                real(self.TEDBuffer(1))*sign(real(filtOut)) + ...
                imag(filtOut)*sign(imag(self.TEDBuffer(1))) - ...
                imag(self.TEDBuffer(1))*sign(imag(filtOut));
        end
    end
end