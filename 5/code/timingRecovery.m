%% Clean workspace
clear; clc;
%% General system details
numSamples = 10000;
modulationOrder = 2;
snr = 5:5:40;
delay = 0;
phaseOffset = pi/4;
N = 8;
NF = 4;
showConstellations = false;
useIdealRef = true;
useDspkMod = true;
%% Visuals
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband with Timing Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
% Initialize output array
evm_dB = zeros(length(snr),1);
raw_evm_dB = zeros(length(snr),1);
%% Loop for each SNR
for i = 1:length(snr)
    %% Generate symbols
    rng(0);
    data = randi([0 modulationOrder-1], numSamples*2, 1);
    mod = comm.DBPSKModulator(); modulatedData = mod(data);
    %% Add TX/RX Filters
    TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol',N);
    RxFlt = comm.RaisedCosineReceiveFilter('DecimationFactor',NF);
    RxFltRef = clone(RxFlt);
    %% Add noise source
    chan = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',snr(i), ...
        'SignalPower',1,'RandomStream', 'mt19937ar with seed');
    %% Add delay
    varDelay = dsp.VariableFractionalDelay;
    filteredTXData = TxFlt(modulatedData);
    noisyData = chan(filteredTXData);
    offsetData = varDelay(noisyData, delay*N);
    offsetData = offsetData*exp(1i*phaseOffset);
    filteredRXData = RxFlt(offsetData);
    filteredRxDataRef = RxFltRef(filteredTXData);
    %% Perform timing synchronization
    symbolSync = comm.SymbolSynchronizer(...
        SamplesPerSymbol=2,...
        NormalizedLoopBandwidth=0.01, ...
        DetectorGain=5.4,...
        DampingFactor=1.0,...
        TimingErrorDetector="Zero-Crossing (decision-directed)");
    [rxSync, timingErr] = symbolSync(filteredRXData);
    rawSym = filteredRXData(1:2:end);
    ccOut = xcorr(modulatedData,rawSym,32);
    [~, maxIdx] = max(abs(ccOut));
    refDly = 33 - maxIdx;
    if useIdealRef    
        rxRef = modulatedData;
        dly = refDly;
    else
        rxRef = filteredRxDataRef(1:2:end);
        dly = 0;
    end
    rawSym = rawSym((dly+1):end);
    % Align data
    ccOut = xcorr(rxRef,rxSync,32);
    [~, maxIdx] = max(abs(ccOut));
    dly = 33 - maxIdx;
    rxSync = rxSync((dly+1):end);
    % Make sure data is the same length
    minSize = min([length(rxSync),length(rxRef), length(rawSym)]);
    rxSync = rxSync(1:minSize);
    rxRef = rxRef(1:minSize);
    rawSym = rawSym(1:minSize);
    % Perform differential decoding
    if useDspkMod
        rxSync = rxSync(2:end).*exp(-1i*angle(rxSync(1:(end-1))));
        rawSym = rawSym(2:end).*exp(-1i*angle(rawSym(1:(end-1))));
        rxRef = rxRef(2:end).*exp(-1i*angle(rxRef(1:(end-1))));
    end
    % Compute EVM
    evm = comm.EVM();
    e = evm(rxRef(1000:end), rxSync(1000:end));
    evm_dB(i) = 20*log10(e/100);
    e = evm(rxRef(1000:end), rawSym(1000:end));
    raw_evm_dB(i) = 20*log10(e/100);
    % Plot constellations
    if showConstellations
        filteredRXData = filteredRXData(1:2:end);
        cdPre(filteredRXData(1000:end));
        cdPost(rxSync(1000:end));
    end
end
% Plot EVM
figure(1);
clf;
plot(snr,evm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')
figure(2);
clf;
plot(snr,raw_evm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')