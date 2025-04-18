%% General system details
sampleRateHz = 1e6; % Sample rate
samplesPerSymbol = 8;
numFrames = 1e3;
modulationOrder = 2;
filterSymbolSpan = 4;
barkerLength = 26; % Must be even
rng(0); % Set random number generator seed

%% Impairemnts
SNR_dB = -15:5:5;

%% Detector Configuration
treshold = 0:0.05:0.9;

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
for i = 1:length(SNR_dB)

    %% Add noise source
    chan = comm.AWGNChannel( ...
        'NoiseMethod',  'Signal to noise ratio (SNR)', ...
        'SNR',          SNR_dB(i), ...
        'SignalPower',  1, ...
        'RandomStream', 'mt19937ar with seed');

    % Compute probabilities
    falseAlarms = zeros(1,length(treshold));
    missedDetections = zeros(1,length(treshold));
    probFalseAlarm = zeros(1,length(treshold));
    probMissedDetection = zeros(1,length(treshold));

    % Loop for each threshold
    for j = 1:length(treshold)

        % Create a preamble detector
        prbdet = PreambleDetector(...
            'Preamble',  preamble,...
            'Normalize', true,...
            'Threshold', treshold(j));

        % Loop for each run
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
            idx = prbdet(filteredData);
    
            % Estimate the delay
            delayEst = idx - length(preamble) - RxGd - TxGd;
    
            % Count number of missed detections
            missedDetections(j) = missedDetections(j) + ~any(delayEst == delay);
    
            % Count the number of false alarms
            falseAlarms(j) = falseAlarms(j) + sum(delayEst ~= delay);
        end

        % Compute the probability of false alarm
        probFalseAlarm(j) = falseAlarms(j)/(2*numFrames*frameSize);

        % Compute the probability of missed detection
        probMissedDetection(j) = missedDetections(j)/(numFrames);
    end

    % Compute the probability of detection
    probDetection = 1 - probMissedDetection;

    % Plot ROC Curve
    plot(probFalseAlarm, probDetection,'LineWidth',1.5);
    hold on;
end

%% Label Plot
legend(cellfun(@(x)sprintf('SNR(dB)=%d',x),num2cell(SNR_dB),...
    'UniformOutput',false),'location','best');
grid on;
xlabel('Probability of False Alarm');
ylabel('Probability of Detection')