%% General system details
numSamples = 1000;
modulationOrder = 2;
%% Generate symbols
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator(); modulatedData = mod(data);
clear mod;
%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter;
RxFlt = comm.RaisedCosineReceiveFilter('DecimationFactor',4);
%% Add delay
varDelay = dsp.VariableFractionalDelay;
filteredTXData = TxFlt(modulatedData);
offsetData = varDelay(filteredTXData, 3.9);
filteredRXData = real(RxFlt(offsetData));

symbolSync = comm.SymbolSynchronizer(...
    SamplesPerSymbol=2,...
    NormalizedLoopBandwidth=0.01, ...
    DetectorGain=5.4,...
    DampingFactor=1.0,...
    TimingErrorDetector="Mueller-Muller (decision-directed)");
[rxSync, timingErr] = symbolSync(filteredRXData);

addpath('./textbook')
[rxSync1, ~, timingErr1] = timingSync(filteredRXData);
rmpath('./textbook')

addpath('./timingCorrection')
symbolSync = SymbolSynchronizer(...
    'TimingErrorDetector',"Mueller-Muller (decision-directed)");
[rxSync2, ~, timingErr2] = symbolSync(filteredRXData);
rmpath('./timingCorrection')

figure(1);
clf;
plot(rxSync);
hold on;
% plot(rxSync1);
plot(rxSync2);

figure(2);
clf;
plot(timingErr);
hold on;
% plot(timingErr1);
plot(timingErr2);