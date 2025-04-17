%% General system details
sampleRateHz = 1e6; % Sample rate
samplesPerSymbol = 8;
numFrames = 1e3;
modulationOrder = 2;
filterSymbolSpan = 4;
barkerLength = 26; % Must be even
rng(0); % Set random number generator seed

%% Impairemnts
SNR_dB = 0:10;

%% Detector Configuration
treshold = 0.8;

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

threshold = 0.7:0.05:0.9;

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
    BER = zeros(size(SNR_dB));
    BER_ideal = zeros(size(SNR_dB));

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
    
        % Keep track of missed detections
        missedDetections = 0;
        numBitErrors = 0;
        numBitErrorsIdeal = 0;
    
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
            [~,ccOut] = prbdet(filteredData);
            [~, idx] = max(abs(ccOut));

            % Estimate the delay
            delayEst = idx - length(preamble) - RxGd - TxGd;
    
            % Count number of missed detections
            missedDetections = missedDetections + ~any(delayEst == delay);
    
            idxIdeal = delay + length(preamble) + RxGd + TxGd;
            symbolsIdeal = filteredData(idxIdeal+1:idxIdeal+frameSize-length(preamble));
            bitsIdeal = pskdemod(symbolsIdeal,2);
            numBitErrorsIdeal = numBitErrorsIdeal + sum(bits ~= bitsIdeal);
    
            % Extract the bits for
            if isempty(idx) || (idx+frameSize-length(preamble)) > length(filteredData)
                numBitErrors = numBitErrors + length(bits);
            else
                symbolsEst = filteredData(idx+1:idx+frameSize-length(preamble));
                bitsEst = pskdemod(symbolsEst,2);
                numBitErrors = numBitErrors + sum(bits ~= bitsEst);
            end
        end
    
        probDetect(j) = 1 - missedDetections/numFrames;
        BER(j) = numBitErrors/(numFrames*length(bits));
        BER_ideal(j) = numBitErrorsIdeal/(numFrames*length(bits));
    end
    figure(1);
    plot(SNR_dB, probDetect); hold on;
    figure(2);
    if i == 1
        semilogy(SNR_dB, BER_ideal); hold on;
    end
    semilogy(SNR_dB, BER);
end

figure(1); clf;
plot(probDetect);
figure(2); clf;
semilogy(BER); hold on;
semilogy(BER_ideal);
grid on;