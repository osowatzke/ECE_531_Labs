%% General system details
sampleRateHz = 1e6;
samplesPerSymbol = 8;
numFrames = 1e3;
modulationOrder = 2;
filterSymbolSpan = 4;
barkerLength = 26; % Must be even
rng(0);

%% Impairemnts
SNR_dB = 80:4:100;

%% Detector Configuration
Detections = 'First'; % Should be 'First' or 'Peak'
CheckNearbySamples = false; % Check nearby samples when performing thresholding
threshold = 0.6:0.1:0.9;

% Override parameters for peak detection
if strcmp(Detections, 'Peak')
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

%% Plot autocorrelation of preamble
figure(1);
clf;
data = [preamble; zeros(length(preamble)-1,1)];
autoCorr = filter(flip(conj(preamble)),1,data);
plot(autoCorr./max(abs(autoCorr)));
n = (0:(length(autoCorr)-1));
n = n - floor(length(autoCorr)/2);
plot(n, autoCorr/max(abs(autoCorr)), 'LineWidth', 1.5);
hold on;
h = ones(length(preamble), 1);
dataPwr = filter(h, 1, data.*conj(data));
mfPwr = sum(preamble.*conj(preamble));
normFactor = sqrt(dataPwr)*sqrt(mfPwr);
plot(n, autoCorr./normFactor, 'LineWidth', 1.5);
xlabel('Sample')
ylabel('Output (Normalized)')
xlim([min(n) max(n)]);
legend('Original','Normalized')
title('Normalized Auto-Correlation')

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
figure(2); clf;
figure(3); clf;
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
            'Detections', Detections,...
            'Threshold',  threshold(i),...
            'CheckNearbySamples', CheckNearbySamples);
    
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
            % filteredTXDataDelayed = delayedSignal;
            
            % Pass through channel
            noisyData = step(chan, filteredTXDataDelayed);
            
            % Filter signal
            filteredData = step(RxFlt, noisyData);
            % filteredData = noisyData;

            % Detect the end of the preamble
            [idx,ccOut] = prbdet(filteredData);
            
            if j == length(SNR_dB)
                figure(4); plot(abs(ccOut));
                keyboard;
            end
            % idx = prbdet(noisyData);

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
    figure(2);
    plot(SNR_dB, probDetect, 'LineWidth', 1.5); hold on;
    figure(3);
    if i == 1
        semilogy(SNR_dB, PER_ideal, 'LineWidth', 1.5);
    end
    hold on;
    semilogy(SNR_dB, PER, 'LineWidth', 1.5);
end

% Label Plots
figure(2);
grid on
xlabel('SNR (dB)');
ylabel('Detection Probability')
title('Detection Probability vs SNR')
if ~strcmp(Detections,'Peak')
    legendStr = cellfun(@(x)sprintf('T=%.2f',x), num2cell(threshold),...
        'UniformOutput', false);
    legend(legendStr,'Location','southeast');
end

figure(3);
grid on
xlabel('SNR (dB)');
ylabel('PER')
title('PER vs SNR')
legendStr = {'Ideal'};
if strcmp(Detections,'Peak')
    legendStr = [legendStr; {'Meas'}];
else
    legendStr = [legendStr; cellfun(@(x)sprintf('Meas (T=%.2f)',x),...
        num2cell(threshold(:)), 'UniformOutput', false)];
end
legend(legendStr,'Location','southwest');