%% General system details
numSamples = 10000;
modulationOrder = 2;
snr = 5:5:40;
delay = 0; %:0.05:0.5;
phaseOffset = 0:pi/32:pi/4;
N = 8;
NF = 4;
clear mod;
evm_dB = zeros(length(snr),length(phaseOffset));
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband with Timing Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
for j = 1:length(phaseOffset)
%% Loop for each SNR
for i = 1:length(snr)
    %% Generate symbols
    rng(0);
    data = randi([0 modulationOrder-1], numSamples*2, 1);
    mod = comm.DBPSKModulator(); modulatedData = real(mod(data));
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
    offsetData = offsetData*exp(1i*phaseOffset(j));
    filteredRXData = RxFlt(offsetData);
    filteredRxDataRef = RxFltRef(filteredTXData);
    %% Test Each Symbol Sychronizer
    % MATLAB built-in
    symbolSync = comm.SymbolSynchronizer(...
        SamplesPerSymbol=2,...
        NormalizedLoopBandwidth=0.01, ...
        DetectorGain=5.4,...
        DampingFactor=1.0,...
        TimingErrorDetector="Zero-Crossing (decision-directed)");
    [rxSync, timingErr] = symbolSync(filteredRXData);
    rxRef = filteredRxDataRef(1:2:end);
    rxRef = modulatedData;
    % Align data
    ccOut = xcorr(rxRef,rxSync,32);
    [~, maxIdx] = max(abs(ccOut));
    dly = 33 - maxIdx;
    rxSync = rxSync((dly+1):end);
    % Make sure data is the same length
    minSize = min(length(rxSync),length(rxRef));
    rxSync = rxSync(1:minSize);
    rxRef = rxRef(1:minSize);
    % Compute EVM
    evm = comm.EVM();
    e = evm(rxRef(1000:end), rxSync(1000:end));
    evm_dB(i,j) = 20*log10(e/100);
    % Plots
    % cdPre(rxRef(1000:end));
    % cdPost(rxSync(1000:end));
end
end
figure(1);
clf;
plot(snr,evm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')