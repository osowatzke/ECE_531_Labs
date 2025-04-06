%% Clean Workspace
clear;
clc;
%% Generate System Details
numFrames = 200;
frameSize = 1024;
numSamples = numFrames*frameSize;
samplesPerSymbol = 8;
filterSymbolSpan = 10;
%% Channel Details
snr_dB = 5:5:40;
delay = 0;
delayDrift = 0.01;
phaseOffset = 0;
%% Simulation Flags
showConstellations = false;
debugControlSystem = false;
useIdealRef = true;
useDspkMod = false;
%% Visuals
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband before Timing Offset');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband after Timing Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;
%% Generate symbols
data = randi([0 1], numSamples, 1);
mod = comm.DBPSKModulator();
modulatedData = mod(data);
clear mod;
%% Initialize Output Arrays
corrEvm_dB = zeros(size(snr_dB));
initEvm_dB = zeros(size(snr_dB));
%% Loop for each SNR
for i = 1:length(snr_dB)
    %% Add TX/RX Filters
    TxFlt = comm.RaisedCosineTransmitFilter(...
        'OutputSamplesPerSymbol', samplesPerSymbol,...
        'FilterSpanInSymbols', filterSymbolSpan);
    TxFltGd = grpdelay(TxFlt.coeffs.Numerator,1,1);
    RxFlt = comm.RaisedCosineReceiveFilter(...
        'InputSamplesPerSymbol', samplesPerSymbol,...
        'FilterSpanInSymbols', filterSymbolSpan,...
        'DecimationFactor', samplesPerSymbol/2);
    RxFltGd = grpdelay(RxFlt.coeffs.Numerator,1,1);
    RxFltRef = clone(RxFlt);
    %% Symbol Synchronizer
    symbolSync = comm.SymbolSynchronizer(...
        SamplesPerSymbol=2,...
        NormalizedLoopBandwidth=0.01, ...
        DetectorGain=5.4,...
        DampingFactor=1.0,...
        TimingErrorDetector="Zero-Crossing (decision-directed)");
    %%  Add noise source
    chan = comm.AWGNChannel('NoiseMethod', 'Signal to noise ratio (SNR)', ...
        'SNR',snr_dB(i), 'SignalPower', 1, 'RandomStream', 'mt19937ar with seed');
    %% Add delay
    varDelay = dsp.VariableFractionalDelay;
    %% Filter signal
    filteredTXData = TxFlt(modulatedData);
    %% Pass through channel
    noisyData = chan(filteredTXData);
    offsetData = zeros(size(noisyData));
    frameDelay = zeros(1,numFrames);
    %% Time delay signal
    frameSize = length(noisyData)/numFrames;
    for k = 1:numFrames
        % Compute time index
        timeStart = frameSize*(k-1) + 1;
        timeEnd = timeStart + frameSize - 1;
        timeIndex = (timeStart:timeEnd).';
        % Compute Frame dealy
        frameDelay(k) = (delay + delayDrift*(k-1))*samplesPerSymbol;
        % Apply Delay
        offsetData(timeIndex) = varDelay(noisyData(timeIndex), frameDelay(k));
    end
    %% Apply Phase Offset
    offsetData = offsetData*exp(1i*phaseOffset);
    %% Filter signal
    filteredRxData = RxFlt(offsetData);
    filteredRxDataRef = RxFltRef(noisyData);
    %% Perform timing error correction
    [rxSync, timingErr] = symbolSync(filteredRxData);
    %% Decimate to chip rate
    rxInit = filteredRxData(1:2:end);
    rxRef = filteredRxDataRef(1:2:end);
    %% Visualize Constellations
    if showConstellations
        frameSize = length(rxInit)/numFrames;
        for k = 1:numFrames
            % Select data for each frame
            timeStart = (k-1)*frameSize + 1;
            timeEnd = timeStart + frameSize - 1;
            timeEnd = min(timeEnd,length(rxSync));
            timeIndex = timeStart:timeEnd;
            % Plot constellations
            cdPre(rxInit(timeIndex));
            cdPost(rxSync(timeIndex));
            pause(0.1);
        end
    end
    %% Create Reference Timing Error
    frameSize = length(timingErr)/numFrames;
    timingErrRef = repmat(2*frameDelay/samplesPerSymbol,frameSize,1);
    timingErrRef = mod(timingErrRef(:), 1);
    %% Time align error signal
    dly = 2*RxFltGd/samplesPerSymbol;
    timingErr = timingErr((dly+1):end);
    %% Compute Fractional Delay Error 
    minSize = min(length(timingErr), length(timingErrRef));
    timingErr = timingErr(1:minSize);
    timingErrRef = timingErrRef(1:minSize);
    fracDelayErr = timingErr - timingErrRef;
    fracDelayErr = mod(fracDelayErr + 0.5, 1) - 0.5;
    %% Compute Reference Symbols
    if useIdealRef
        rxRef = modulatedData;
    end
    %% Time align symbols
    % Compute delay
    ccOut = xcorr(rxRef,rxSync,32);
    [~, maxIdx] = max(abs(ccOut));
    dly = 33 - maxIdx;
    % Compensate for delay differences
    rxSync = rxSync((dly+1):end);
    % Compute delay
    ccOut = xcorr(rxRef,rxInit,32);
    [~, maxIdx] = max(abs(ccOut));
    dly = 33 - maxIdx;
    % Compensate for delay differences
    rxInit = rxInit((dly+1):end);
    %% Ensure symbol arrays are the same length
    minSize = min([length(rxRef), length(rxSync), length(rxInit)]);
    rxRef = rxRef(1:minSize);
    rxSync = rxSync(1:minSize);
    rxInit = rxInit(1:minSize);
    %% Debug plots for control system
    if debugControlSystem
        % Plot fractional delay
        figure(1);
        clf;
        plot(timingErr);
        xlabel('Sample')
        ylabel('Fractional Delay')
        % Plot fractional delay error
        figure(2);
        clf;
        plot(fracDelayErr);
        xlabel('Sample')
        ylabel('Fractional Delay Error')
        % Plot symbols
        figure(3);
        clf;
        plot(real(rxRef));
        hold on;
        plot(real(rxSync));
        xlabel('Sample')
        ylabel('Sychronized Symbol')
        legend('Reference','Measured')
    end
    %% Perform Differential Demodulation
    if useDspkMod
        rxRef = rxRef(1:(end-1)).*exp(-1i*angle(rxRef(2:end)));
        rxSync = rxSync(1:(end-1)).*exp(-1i*angle(rxSync(2:end)));
        rxInit = rxInit(1:(end-1)).*exp(-1i*angle(rxInit(2:end)));
    end
    %% Error Vector Measurements
    evm = comm.EVM();
    e = evm(rxRef(1000:end),rxInit(1000:end));
    initEvm_dB(i) = 20*log10(e/100);
    e = evm(rxRef(1000:end),rxSync(1000:end));
    corrEvm_dB(i) = 20*log10(e/100);
end
%% Plot EVM Before Timing Compensation
figure(4);
clf;
plot(snr_dB,initEvm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')
%% Plot EVM After Timing Compensation
figure(5);
clf;
plot(snr_dB,corrEvm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')