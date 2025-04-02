function [filtOutArr, eArr, muArr] = timingSync(y)
    mu = 0;
    InterpFilterState = zeros(3,1); %#ok 
    Trigger = false; %#ok
    LoopPreviousInput = 0; %#ok
    LoopFilterState = 0; %#ok
    N = 2;
    zeta = 1;
    Bloop = 0.01;
    GD = 2.7;
    theta = Bloop/(N*(zeta+0.25/zeta));
    Delta = 1+2*zeta*theta+theta^2;
    G1 = -4*zeta*theta/(GD*N*Delta);
    G2 = -4*theta^2/(GD*N*Delta);
    ProportionalGain = G1+G2; %#ok
    IntegratorGain = G2; %#ok
    TriggerHistory = false(1,N); %#ok
    TEDBuffer = zeros(1,N); %#ok
    Counter = 0; %#ok
    muArr = zeros(size(y));
    eArr = zeros(size(y));
    filtOutArr = zeros(size(y));
    warning('off')
    idx = 0; %#ok
    for i = 1:length(y)
        muArr(i) = mu;
        interpFilter;
        if Trigger
            idx = idx + Trigger; %#ok
            filtOutArr(idx) = filtOut;
        end
        zcTED;
        eArr(i) = e;
        loopFilter;
        interpControl;
    end
    warning('on')
    filtOutArr = filtOutArr(1:idx);
end