% Clear workspace
clear; clc;
%% General system details
sampleRateHz = 1e6; samplesPerSymbol = 8;
frameSize = 2^10; numFrames = 200;
numSamples = numFrames*frameSize; % Samples to simulate
modulationOrder = 2; filterSymbolSpan = 4;
showConstellations = false;
debugPlots = false;
useIdealRef = true;
useDspkMod = false;
phaseOffset = pi/8;
%% Visuals
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband with Timing Offset');
cdCorr = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband with Timing Correction');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
%% Impairments
snr = 5:5:40; timingOffset = samplesPerSymbol*0.01; % Samples
%% Generate symbols
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator(); modulatedData = mod(data);
clear mod;
%% Create EVM output arrays
evm_dB = zeros(size(snr));
raw_evm_dB = zeros(size(snr));
%% Loop for each SNR
for i = 1:length(snr)
    % Add TX/RX Filters
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
    % Symbol Synchronizer
    addpath('timingCorrection')
    symbolSync = comm.SymbolSynchronizer();
    % Add noise source
    clear chan;
    chan = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',snr(i), ...
        'SignalPower',1,'RandomStream', 'mt19937ar with seed');
    % Add delay
    varDelay = dsp.VariableFractionalDelay;
    % Create Output Arrays
    refSym = cell(numFrames,1);
    rxSym = cell(numFrames,1);
    rawSym = cell(numFrames,1);
    symErr = cell(numFrames,1);
    % Model of error
    % Add timing offset to baseband signal
    frameIdx = 1;
    refDly = zeros(numFrames,1);
    for k=1:frameSize:(numSamples - frameSize)
        timeIndex = (k:k+frameSize-1).';
        % Filter signal
        filteredTXData = TxFlt(modulatedData(timeIndex));
        % Pass through channel
        noisyData = chan(filteredTXData);
        % Time delay signal
        refDly(frameIdx) = k/frameSize*timingOffset;
        offsetData = varDelay(noisyData, refDly(frameIdx));
        offsetData = offsetData*exp(1i*phaseOffset);
        % Filter signal
        filteredData = RxFlt(offsetData);
        filteredDataRef = RxFltRef(noisyData);
        % Perform timing error correction
        [syncData, timingErr] = symbolSync(filteredData);
        % Decimate to chip rate
        filteredData = filteredData(1:2:end);
        filteredDataRef = filteredDataRef(1:2:end);
        % Save data for post processing
        refSym{frameIdx} = filteredDataRef;
        rawSym{frameIdx} = filteredData;
        rxSym{frameIdx} = syncData;
        symErr{frameIdx} = timingErr;
        frameIdx = frameIdx + 1;
        % Visualize data
        if showConstellations
            cdPre(filteredDataRef);
            cdPost(filteredData);
            cdCorr(syncData);
            pause(0.1);
        end
    end
    rmpath('timingCorrection');
    % Determine delay of reference constellation
    refSym = cell2mat(refSym);
    ccOut = xcorr(modulatedData,refSym,32);
    [~, maxIdx] = max(abs(ccOut));
    refDly = 33 - maxIdx;
    % Select reference data    
    if useIdealRef
        refSym = modulatedData;
    end
    % Aggregate data
    rxSym = cell2mat(rxSym);
    rawSym = cell2mat(rawSym);
    % Determine delay of data
    ccOut = xcorr(refSym,rxSym,32);
    [~, maxIdx] = max(abs(ccOut));
    dly = 33 - maxIdx;
    % Compensate for delay differences
    rxSym = rxSym((dly+1):end);
    % Determine delay of raw symbols
    if useIdealRef
        dly = refDly;
    else
        dly = 0;
    end
    % Compensate for delay differences
    rawSym = rawSym((dly+1):end);
    % Ensure arrays are the same size
    minSize = min([length(refSym), length(rxSym), length(rawSym)]);
    refSym = refSym(1:minSize);
    rxSym = rxSym(1:minSize);
    rawSym = rawSym(1:minSize);
    % Error Vector Measurement
    if useDspkMod
        rxSym = rxSym(1:(end-1)).*exp(-1i*angle(rxSym(2:end)));
        rawSym = rawSym(1:(end-1)).*exp(-1i*angle(rawSym(2:end)));
        refSym = refSym(1:(end-1)).*exp(-1i*angle(refSym(2:end)));
    end
    evm = comm.EVM();
    e = evm(refSym(1000:end),rxSym(1000:end));
    evm_dB(i) = 20*log10(e/100);
    e = evm(refSym(1000:end),rawSym(1000:end));
    raw_evm_dB(i) = 20*log10(e/100);
    % Aggregate Timing Error
    symErr = cell2mat(symErr);
    refDly = repmat(refDly.',2*frameSize,1);
    refDly = refDly(:);
    dly = 2*dly;
    if ~useIdealRef
        dly = dly + (TxFltGd + RxFltGd)/4;
    end
    symErr = symErr((dly+1):end);
    % Ensure arrays are the same size
    minSize = min(length(refDly), length(symErr));
    refDly = refDly(1:minSize)/4;
    symErr = symErr(1:minSize);
    dlyErr = mod(refDly - symErr + 0.5, 1) - 0.5;
    % Plot data
    if debugPlots
        % Plot fractional delay
        figure(1);
        clf;
        plot(real(symErr));
        xlabel('Sample')
        ylabel('Fractional Delay')
        % Plot fractional delay error
        figure(2);
        clf;
        plot(dlyErr);
        xlabel('Sample')
        ylabel('Fractional Delay Error')
        % Plot symbols
        figure(3);
        clf;
        plot(real(refSym));
        hold on;
        plot(real(rxSym));
        xlabel('Sample')
        ylabel('Sychronized Symbol')
        legend('Reference','Measured')
    end
end
% Plot EVM
figure(4);
clf;
plot(snr,evm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')
figure(5);
clf;
plot(snr,raw_evm_dB,'LineWidth',1.5);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (dB)')
