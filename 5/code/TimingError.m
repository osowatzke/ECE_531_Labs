%% General system details
sampleRateHz = 1e6; samplesPerSymbol = 8;
frameSize = 2^10; numFrames = 200;
numSamples = numFrames*frameSize; % Samples to simulate
modulationOrder = 2; filterSymbolSpan = 4;
showConstellations = true;
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
snr = 20; timingOffset = samplesPerSymbol*0.01; % Samples
%% Generate symbols
data = randi([0 modulationOrder-1], numSamples*2, 1);
mod = comm.DBPSKModulator(); modulatedData = mod(data);
%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter(...
    'OutputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan);
RxFlt = comm.RaisedCosineReceiveFilter(...
    'InputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan,...
    'DecimationFactor', samplesPerSymbol/2);
RxFltRef = clone(RxFlt);
%% Symbol Synchronizer
addpath('timingCorrection')
symbolSync = comm.SymbolSynchronizer();
%% Error Vector Measurement
evm = comm.EVM();
%% Add noise source
chan = comm.AWGNChannel('NoiseMethod','Signal to noise ratio (SNR)','SNR',snr, ...
    'SignalPower',1,'RandomStream', 'mt19937ar with seed');
%% Add delay
varDelay = dsp.VariableFractionalDelay;
%% Create Output Arrays
refSym = cell(numFrames,1);
rxSym = cell(numFrames,1);
symErr = cell(numFrames,1);
%% Model of error
% Add timing offset to baseband signal
frameIdx = 1;
for k=1:frameSize:(numSamples - frameSize)
    timeIndex = (k:k+frameSize-1).';
    % Filter signal
    filteredTXData = TxFlt(modulatedData(timeIndex));
    % Pass through channel
    noisyData = chan(filteredTXData);
    % Time delay signal
    offsetData = varDelay(noisyData, k/frameSize*timingOffset);
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
%% Aggregate data
refSym = cell2mat(refSym);
rxSym = cell2mat(rxSym);
symErr = cell2mat(symErr);
% Determine delay of data
ccOut = xcorr(refSym,rxSym,2);
[~, maxIdx] = max(abs(ccOut));
dly = 3 - maxIdx;
% Compensate for delay differences
if dly >= 0
    rxSym = rxSym((dly+1):end);
    symErr = symErr((dly+1):end);
else
    refSym = refSym((-dly+1):end);
end
% Ensure arrays are the same size
minSize = min(length(refSym), length(rxSym));
refSym = refSym(1:minSize);
rxSym = rxSym(1:minSize);
symErr = symErr(1:minSize);
%% Display EVM
evm(refSym(2000:end),rxSym(2000:end))
%% Plot data
figure(1);
clf;
plot(real(symErr));

figure(2);
clf;
plot(real(refSym));
hold on;
plot(real(rxSym));