% User bounds for start and end of signal region
signalStartIdx = 312000;
signalEndIdx = 555000;

% User bounds for start and end of noise region
noiseStartIdx = 620000;
noiseEndIdx = 805000;

% Load captured data
load('data.mat','data');

% Get mask for signal
signalMask = getSampleMask(signalStartIdx, signalEndIdx, size(data));

% Get mask for noise
noiseMask = getSampleMask(noiseStartIdx, noiseEndIdx, size(data));

% Determine the power over the signal region
Ps = mean(data(signalMask).*conj(data(signalMask)));

% Determine the power over the noise region
Pn = mean(data(noiseMask).*conj(data(noiseMask)));

% Estimate the SNR
SNR_dB = 10*log10((Ps - Pn)/Pn);

% Plot ADC data
figure(1); clf;
plot(db(data(:)));

% Plot masks ontop of ADC data
hold on;
plot(db(Ps*signalMask(:),'power'),'LineWidth',1.5);
plot(db(Pn*noiseMask(:),'power'),'LineWidth',1.5);
xlabel('Sample')
ylabel('Magnitude (dB)')
legend('ADC Data','Signal Window','Noise Window')

% Disable SNR
title(sprintf('Pluto Data Capture SNR = %.2f dB', SNR_dB))

function mask = getSampleMask(startIdx, endIdx, dataDims)

    % Extract pulse length and number of pulses
    % from input data dimensions
    priLen = dataDims(1);
    numPris = dataDims(2);

    % Find start and end indices of each pulse
    startIdx = startIdx + (0:(numPris-1))*priLen;
    startIdx = mod(startIdx-1, priLen*numPris)+1;
    startIdx = sort(startIdx);
    endIdx = endIdx + (0:(numPris-1))*priLen + 1;
    endIdx = mod(endIdx-1, priLen*numPris)+1;
    endIdx = sort(endIdx);

    % Ignore ending bounds too early
    if endIdx(1) == 1
        endIdx = endIdx(2:end);
    end

    % Get bounds for partial pulses
    if startIdx(1) > endIdx(1)
        startIdx = [1, startIdx];
    end

    % Get one hot mask
    priInd = zeros(priLen*numPris,1);
    priInd(startIdx) = 1;
    priInd(endIdx) = -1;
    mask = boolean(filter(1,[1 -1],priInd));
end
