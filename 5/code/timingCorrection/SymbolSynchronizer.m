classdef SymbolSynchronizer < matlab.System
    properties(Access=protected)
        N = 2;
        zeta = 1;
        Bloop = 0.01;
        GD = 2.7;
        interp = [];
        TED = [];
        loopFilt = [];
        interpCtrl = [];
        mu;
        Trigger;
        TriggerHistory;
    end
    methods
        function self = SymbolSynchronizer(varargin)
            for i = 1:2:nargin
                self.(varargin{i}) = varargin{i+1};e
            end
            theta = self.Bloop/(self.N*(self.zeta+0.25/self.zeta));
            Delta = 1+2*self.zeta*theta+theta^2;
            G1 = -4*self.zeta*theta/(self.GD*self.N*Delta);
            G2 = -4*theta^2/(self.GD*self.N*Delta);
            self.interp = ppfInterp;
            self.TED = zcTED('N',self.N);
            self.loopFilt = loopFilter(...
                'ProportionalGain',G1,...
                'IntegratorGain',G2);
            self.interpCtrl = interpControl('N',self.N);
        end
    end
    methods(Access=protected)
        function resetImpl(self)
            self.mu = 0;
            self.Trigger = 0;
            self.TriggerHistory = zeros(1,self.N);
            reset(self.interp);
            reset(self.TED);
            reset(self.loopFilt);
            reset(self.interpCtrl);
        end
        function [filtOut,e,muLog] = stepImpl(self,x)
            e = zeros(size(x));
            muLog = zeros(size(x));
            filtOut = zeros(size(x));
            for i = 1:length(x)
                muLog(i) = self.mu;
                filtOut(i) = self.interp(x(i), self.mu);
                e(i) = self.TED(filtOut(i),self.Trigger,self.TriggerHistory);
                g = self.loopFilt(e(i));
                self.TriggerHistory = [self.TriggerHistory(2:end), self.Trigger];
                [self.mu,self.Trigger] = self.interpCtrl(g);
            end
        end
    end
end