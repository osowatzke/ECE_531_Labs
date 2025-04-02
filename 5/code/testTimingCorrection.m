%% General system details
numSamples = 1000;
modulationOrder = 2;
%% Generate symbols
rng(0);
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator(); modulatedData = real(mod(data));
clear mod;
%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter;
RxFlt = comm.RaisedCosineReceiveFilter('DecimationFactor',4);
%% Add delay
varDelay = dsp.VariableFractionalDelay;
filteredTXData = TxFlt(modulatedData);
offsetData = varDelay(filteredTXData, 4);
filteredRXData = RxFlt(offsetData);

%% Test Each Symbol Sychronizer
% MATLAB built-in
symbolSync = comm.SymbolSynchronizer(...
    SamplesPerSymbol=2,...
    NormalizedLoopBandwidth=0.01, ...
    DetectorGain=5.4,...
    DampingFactor=1.0,...
    TimingErrorDetector="Zero-Crossing (decision-directed)");
[rxSync, timingErr] = symbolSync(filteredRXData);

% Using provided functions
addpath('./textbook')
[rxSync1, timingErr1] = timingSync(filteredRXData);
rmpath('./textbook')

% With system objects
addpath('./timingCorrection')
symbolSync = SymbolSynchronizer(...
    'TimingErrorDetector',"Zero-Crossing (decision-directed)");
[rxSync2, timingErr2] = symbolSync(filteredRXData);
rmpath('./timingCorrection')

% Plot results
figure(1);
clf;
plot(real(rxSync));
hold on;
plot(real(rxSync1));
plot(real(rxSync2));

figure(2);
clf;
plot(timingErr);
hold on;
plot(timingErr1);
plot(timingErr2);

figure(3);
clf;
plot(real(rxSync-rxSync1));
hold on;
plot(real(rxSync-rxSync2));

figure(4);
clf;
plot(abs(timingErr - timingErr1))
hold on;
plot(abs(timingErr - timingErr2))