%% Clean Workspace
clear;
clc;
%% Setup path
addpath('./timingCorrection')
%% System Parameters
samplesPerSymbol = 8;
decimation = 4;
frameSize = 2^14;
samplesPerFrame = frameSize*samplesPerSymbol;
txGain = -65:5:-20;
%% Synchronizer Configuration
useBuiltInSync = true;
correctAmplitude = true;
showConstellations = false;
useDspkMod = true;
%% Select Symbol Synchronizer
if useBuiltInSync
    SymbolSynchronizer = @comm.SymbolSynchronizer;
else
    SymbolSynchronizer = @SymbolSynchronizer;
end
%% Visuals
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband after Timing Sync');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10; % Place side by side
%% Initialize Output Arrays
corrEvm_dB = zeros(size(txGain));
initEvm_dB = zeros(size(txGain));
timingErr = zeros(size(txGain));
for i = 1:length(txGain)
    %% System set up
    % Set up radio
    tx = sdrtx('Pluto','SamplesPerFrame',samplesPerFrame,'Gain',txGain(i));
    rx = sdrrx('Pluto','SamplesPerFrame',4*samplesPerFrame,...
        'OutputDataType','double','GainSource', 'Manual');
    %% Create binary data for symbols
    data = randi([0 1],frameSize,1);
    %% Modulate data
    mod = comm.DBPSKModulator();
    modData = complex(mod(data));
    %% Set up filters
    rctFilt = comm.RaisedCosineTransmitFilter( ...
        'OutputSamplesPerSymbol', samplesPerSymbol);
    rcrFilt = comm.RaisedCosineReceiveFilter( ...
        'InputSamplesPerSymbol',  samplesPerSymbol, ...
        'DecimationFactor',       decimation);
    %% Pass data through radio
    tx.transmitRepeat(rctFilt(modData));
    data = rcrFilt(rx());
    %% Perform amplitude correction
    if correctAmplitude
        agcIndex = (frameSize+1):(2*frameSize);
        meanPwr = mean(data(agcIndex).*conj(data(agcIndex)));
        data = data/sqrt(meanPwr);
    end
    %% Get data prior to timing sync
    rxInit = data(1:2:end);
    %% Match Delay of Signal
    ccOut = xcorr(rxInit,modData);
    midPoint = (length(ccOut)+1)/2;
    ccOut = ccOut(midPoint:end);
    searchIdx = (frameSize+1):(2*frameSize);
    [~, maxIdx] = max(abs(ccOut(searchIdx)));
    dly = maxIdx - 1;
    rxInit = rxInit((dly+1):end);
    %% Symbol Synchronizer
    symbolSync = SymbolSynchronizer(...
        SamplesPerSymbol=2,...
        NormalizedLoopBandwidth=0.01, ...
        DetectorGain=5.4,...
        DampingFactor=1.0,...
        TimingErrorDetector="Zero-Crossing (decision-directed)");
    [rxSync,err] = symbolSync(data);
    %% Save Timing Error
    stableIdx = (length(err)/2+1):length(err);
    timingErr(i) = mean(err(stableIdx));
    %% Match Delay of Signal
    ccOut = xcorr(rxSync,modData);
    midPoint = (length(ccOut)+1)/2;
    ccOut = ccOut(midPoint:end);
    searchIdx = (frameSize+1):(2*frameSize);
    [~, maxIdx] = max(abs(ccOut(searchIdx)));
    dly = maxIdx - 1;
    rxSync = rxSync((dly+1):end);
    %% Extract Symbols from a Single Frame
    rxSync = rxSync(1:frameSize);
    rxInit = rxInit(1:frameSize);
    modData = modData(1:frameSize);
    %% Perform Differential Modulation
    if useDspkMod
        rxInit = rxInit(2:end).*exp(-1i*angle(rxInit(1:(end-1))));
        rxSync = rxSync(2:end).*exp(-1i*angle(rxSync(1:(end-1))));
        modData = modData(2:end).*exp(-1i*angle(modData(1:(end-1))));
    end
    %% Display Constellation
    if showConstellations
        % Plot constellations
        cdPre(rxInit);
        cdPost(rxSync);
        pause(0.1);
    end
    %% Compute Error Vector Magnitude
    evm = comm.EVM();
    corrEvm_dB(i) = 20*log10(evm(modData,rxSync)/100);
    initEvm_dB(i) = 20*log10(evm(modData,rxInit)/100);
end
figure(1);
clf;
plot(txGain, initEvm_dB, 'LineWidth',1.5);
grid on;
title('Plot of EVM vs TX Gain before Timing Compensation')
xlabel('Tx Gain (dB)');
ylabel('EVM (dB)')
figure(2);
clf;
plot(txGain, corrEvm_dB, 'LineWidth',1.5);
grid on;
title('Plot of EVM vs TX Gain after Timing Compensation')
xlabel('Tx Gain (dB)');
ylabel('EVM (dB)')
figure(3);
clf;
plot(txGain, timingErr, 'LineWidth',1.5);
grid on;
title('Plot of Fractional Delay Error vs TX Gain')
xlabel('Tx Gain (dB)');
ylabel('Fractional Delay');
%% Reset path
rmpath('./timingCorrection')