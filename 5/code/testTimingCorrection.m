%% General system details
numSamples = 2000;
modulationOrder = 2;
snr = 10;
delay = 2;
%% Generate symbols
rng(0);
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator(); modulatedData = real(mod(data));
%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter;
RxFlt = comm.RaisedCosineReceiveFilter('DecimationFactor',4);
%% Add noise source
chan = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',snr, ...
    'SignalPower',1,'RandomStream', 'mt19937ar with seed');
%% Add delay
varDelay = dsp.VariableFractionalDelay;
filteredTXData = TxFlt(modulatedData);
noisyData = chan(filteredTXData);
offsetData = varDelay(noisyData, delay);
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
[rxSync1, timingErr1, tedOut1] = timingSync(filteredRXData);
rmpath('./textbook')

% With system objects
addpath('./timingCorrection')
symbolSync = SymbolSynchronizer(...
    'TimingErrorDetector',"Zero-Crossing (decision-directed)");
[rxSync2, timingErr2, tedOut2] = symbolSync(filteredRXData);
rmpath('./timingCorrection')

%% Plot Results
figure(1);
clf;
plot(real(rxSync));
hold on;
plot(real(rxSync1));
plot(real(rxSync2));
xlabel('Sample')
ylabel('Sychronized Symbols');
legend('comm.SymbolSynchronizer','Textbook Implementation','Custom Implementation');

figure(2);
clf;
plot(timingErr);
hold on;
plot(timingErr1);
plot(timingErr2);
xlabel('Sample')
ylabel('Fractional Delay');
legend('comm.SymbolSynchronizer','Textbook Implementation','Custom Implementation');

figure(3);
clf;
plot(real(rxSync-rxSync1));
hold on;
plot(real(rxSync-rxSync2));
xlabel('Sample')
ylabel('Sychronized Symbol Error');
legend('Textbook Implementation','Custom Implementation');

figure(4);
clf;
plot(abs(timingErr - timingErr1))
hold on;
plot(abs(timingErr - timingErr2))
xlabel('Sample');
ylabel('Fractional Delay Error');
legend('Textbook Implementation','Custom Implementation');

figure(5);
clf;
plot(tedOut1)
hold on;
plot(tedOut2)
xlabel('Sample');
ylabel('Timing Offset');
legend('Textbook Implementation','Custom Implementation');

figure(6)
clf;
plot(timingErr - delay/4);
hold on;
plot(timingErr1 - delay/4);
plot(timingErr2 - delay/4);
xlabel('Sample');
ylabel('Fractional Delay Error');
legend('comm.SymbolSynchronizer','Textbook Implementation','Custom Implementation');