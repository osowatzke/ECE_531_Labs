function [rxSync, timingErr] = timingSync(y)

    % Loop Filter Parameters
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

    % Interpolator state
    InterpFilterState = zeros(3,1); %#ok 

    % TED State
    TriggerHistory = false(1,N); %#ok
    TEDBuffer = zeros(1,N); %#ok

    % Loop filter state
    LoopPreviousInput = 0; %#ok
    LoopFilterState = 0; %#ok

    % Controller state
    Counter = 0; %#ok

    % Initialize outputs arrays
    rxSync = zeros(size(y));
    timingErr = zeros(size(y));

    % Loop outputs
    mu = 0;
    Trigger = false;

    % Loop for each input sample
    warning('off')
    outIdx = 0;
    for i = 1:length(y)
        timingErr(i) = mu;
        interpFilter;
        if Trigger
            outIdx = outIdx + 1; %#ok
            rxSync(outIdx) = filtOut;
        end
        zcTED;
        loopFilter;
        interpControl;
    end
    warning('on')

    % Keep only samples with triggers
    rxSync = rxSync(1:outIdx);
end