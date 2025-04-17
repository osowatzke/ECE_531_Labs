%% General system details
sampleRateHz = 1e6;
samplesPerSymbol = 8;
numFrames = 1e3;
modulationOrder = 2;
filterSymbolSpan = 4;
barkerLength = 26; % Must be even
rng(0);

%% Impairemnts
SNR_dB = 0:10;

%% Detector Configuration
peakDetect = true;
threshold = 0.7:0.1:0.9;

% Override parameters for peak detection
if peakDetect
    threshold = 1;
end

%% Generate symbols
bits = double(ASCII2bits('Arizona')); % Generate message (use booktxt.m for a long message)
% Preamble
hBCode = comm.BarkerCode('Length',7,'SamplesPerFrame', barkerLength/2);
preamble = step(hBCode);
preamble = [preamble;preamble];
barker = preamble<0;
frame = [barker;bits];
frameSize = length(frame);
modulatedData = pskmod(frame,2);

%% Add TX/RX Filters
TxFlt = comm.RaisedCosineTransmitFilter(...
    'OutputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan);
TxGd = TxFlt.grpdelay(1)/samplesPerSymbol;

RxFlt = comm.RaisedCosineReceiveFilter(...
    'InputSamplesPerSymbol', samplesPerSymbol,...
    'FilterSpanInSymbols', filterSymbolSpan,...
    'DecimationFactor', samplesPerSymbol);% Set to filterUpsample/2 when introducing timing estimation
RxGd = RxFlt.grpdelay(1)/samplesPerSymbol;

%% Generate ROC curve for each SNR
figure(1); clf;
figure(2); clf;
for i = 1:length(threshold)

    % Probability of Detection
    probDetect = zeros(size(SNR_dB));
    PER = zeros(size(SNR_dB));
    PER_ideal = zeros(size(SNR_dB));

    for j = 1:length(SNR_dB)

        %% Add noise source
        chan = comm.AWGNChannel( ...
            'NoiseMethod',  'Signal to noise ratio (SNR)', ...
            'SNR',          SNR_dB(j), ...
            'SignalPower',  1, ...
            'RandomStream', 'mt19937ar with seed');

        % Create a preamble detector
        prbdet = PreambleDetector(...
            'Preamble',   preamble,...
            'Normalize',  true,...
            'Detections', 'First',...
            'Threshold',  threshold(i));
    
        % Keep track of errors and missed detections
        numErrors = 0;
        numErrorsIdeal = 0;
        missedDetections = 0;
    
        % Loop for each frame
        for k = 1:numFrames
    
            % Insert random delay and append zeros
            delay = randi([0 frameSize-1-TxGd-RxGd]);% Delay should be at worst 1 frameSize-"filter delay"
            delayedSignal = [zeros(delay,1); modulatedData;...
                zeros(frameSize-delay,1)];
        
            % Filter signal
            filteredTXDataDelayed = step(TxFlt, delayedSignal);
            
            % Pass through channel
            noisyData = step(chan, filteredTXDataDelayed);
            
            % Filter signal
            filteredData = step(RxFlt, noisyData);
    
            % Detect the end of the preamble
            [idx,ccOut] = prbdet(filteredData);
            if peakDetect
                [~, idx] = max(abs(ccOut));
            end

            % Get the ideal index
            idxIdeal = delay + length(preamble) + RxGd + TxGd;
    
            % Count number of missed detections
            missedDetections = missedDetections + ~any(idx == idxIdeal);
    
            % Get the number of errors
            if isempty(idx) || (idx ~= idxIdeal)
                numErrors = numErrors + 1;
            else
                symbolsEst = filteredData(idx+1:idx+frameSize-length(preamble));
                bitsEst = pskdemod(symbolsEst,2);
                numErrors = numErrors + any(bits ~= bitsEst);
            end
            symbolsEst = filteredData(idxIdeal+1:idxIdeal+frameSize-length(preamble));
            bitsEst = pskdemod(symbolsEst,2);
            numErrorsIdeal = numErrorsIdeal + any(bits ~= bitsEst);
        end
    
        % Get the detection probability
        probDetect(j) = 1 - missedDetections/numFrames;

        % Get the Packet Error Rates
        PER(j) = numErrors/numFrames;
        PER_ideal(j) = numErrorsIdeal/numFrames;
    end
    figure(1);
    plot(SNR_dB, probDetect); hold on;
    figure(2);
    if i == 1
        semilogy(SNR_dB, PER_ideal); hold on;
    end
    semilogy(SNR_dB, PER);
end

% Label Plots
figure(1);
grid on
xlabel('SNR (dB)');
ylabel('Detection Probability')
title('Detection Probability vs SNR')
if ~peakDetect
    legendStr = cellfun(@(x)sprintf('T=%.2f',x), num2cell(threshold),...
        'UniformOutput', false);
    legend(legendStr,'Location','southeast');
end

figure(2);
grid on
xlabel('SNR (dB)');
ylabel('PER')
title('PER vs SNR')
legendStr = {'Ideal'};
if peakDetect
    legendStr = [legendStr; {'Meas'}];
else
    legendStr = [legendStr; cellfun(@(x)sprintf('Meas (T=%.2f)',x),...
        num2cell(threshold(:)), 'UniformOutput', false)];
end
legend(legendStr,'Location','southwest');