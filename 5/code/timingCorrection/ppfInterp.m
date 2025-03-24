classdef ppfInterp < keyValueInitializer
    properties(Constant)
        alpha = 0.5;
    end
    properties (Access = protected)
        xR = zeros(4,1);
    end
    methods (Access = protected)
        function resetImpl(self)
            self.xR = zeros(4,1);
        end
        function y = stepImpl(self, x, mu)
            self.xR = [x; self.xR(1:3)];
            h = [self.alpha*mu*(mu-1);
                -self.alpha*mu^2+(1+self.alpha)*mu;
                -self.alpha*mu^2-(1-self.alpha)*mu+1;
                self.alpha*mu*(mu-1)];
            y = sum(self.xR.*h);
        end
    end
end