%% Lab 1 Part 2: Fine Frequency Correction

% Debugging flags
visuals = false;
useBuiltInObj = false;

%% General system details
sampleRateHz = 1e3; % Sample rate
samplesPerSymbol = 1;
modulationOrder = 4;
frameSize = 2^10;
numFrames = 300;
numSamples = numFrames*frameSize; % Samples to simulate

%% Setup objects
if modulationOrder == 2
    mod = comm.DBPSKModulator();
else % Assume QPSK
    mod = comm.QPSKModulator();
end
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'SymbolsToDisplaySource','Property',...
    'SymbolsToDisplay',frameSize/2,...
    'Name','Baseband with Freq Offset');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
ap = dsp.ArrayPlot;ap.ShowGrid = true;
ap.Title = 'Frequency Histogram';ap.XLabel = 'Hz';ap.YLabel = 'Magnitude';
ap.XOffset = -sampleRateHz/2;
ap.SampleIncrement = (sampleRateHz)/(2^10);

%% Impairments
snr = 15;
frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
frequencyDriftHz = sampleRateHz*0; %0.001;
phaseOffset = 0; % Radians

%% Generate symbols
rng(0); % Fixing for repeatability
data = randi([0 modulationOrder-1], numSamples, 1);
modulatedData = mod.step(data);

%% Add noise
noisyData = awgn(modulatedData,snr);

%% Model of error
% Add frequency offset to baseband signal

if useBuiltInObj
    if modulationOrder == 2
        modulation = 'BPSK';
    else % Assume QPSK
        modulation = 'QPSK';
    end
    carrierSync = comm.CarrierSynchronizer(...
        'SamplesPerSymbol',1,'Modulation',modulation,...
        'NormalizedLoopBandwidth',0.01,...
        'DampingFactor',1/sqrt(2));
else
    carrierSync = CarrierSynchronizer(...
        'SamplesPerSymbol',1,'ModulationOrder',modulationOrder, ...
        'NormalizedLoopBandwidth',0.01,...
        'DampingFactor',1/sqrt(2));
end

% Precalculate constants
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;
normalizedDrift = 1i.*2*pi*frequencyDriftHz./sampleRateHz^2;

offsetData = zeros(size(noisyData));
syncData = zeros(size(noisyData));
phaseEst = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + 1/2*normalizedDrift*timeIndex.^2 + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;

    % Perform fine frequency synchronization
    [syncData(timeIndex), phaseEst(timeIndex)] = carrierSync(offsetData(timeIndex));
    
    % Visualize Error
    if visuals
        step(cdPre,offsetData(timeIndex));step(cdPost,syncData(timeIndex));pause(0.1); %#ok<*UNRCH>
    end
end

% Compute EVM before and after compensation
evm = comm.EVM();
evm_pre_dB = 20*log10(evm(modulatedData(timeIndex),offsetData(timeIndex))/100);
evm_post_dB = 100;
symbolOffset = 1;
for i = 0:(modulationOrder-1)
    testOffset = exp(1i*2*pi*i/modulationOrder);
    evm_test_dB = 20*log10(evm(modulatedData(timeIndex)*testOffset,syncData(timeIndex))/100);
    if evm_test_dB < evm_post_dB
        evm_post_dB = evm_test_dB;
        symbolOffset = testOffset;
    end
end

% Handle phase ambiguity
modulatedData = modulatedData*symbolOffset;

% Display EVM
evm = comm.EVM();
evm_dB = 20*log10(evm(modulatedData(timeIndex),offsetData(timeIndex))/100);
fprintf('EVM_pre (dB) = %.2f dB\n', evm_dB);
evm_dB = 20*log10(evm(1*modulatedData(timeIndex),syncData(timeIndex))/100);
fprintf('EVM_post (dB) = %.2f dB\n', evm_dB);

% Display error variance
freqEstHz = diff(phaseEst(timeIndex))/(2*pi)*sampleRateHz;
freqErrHz = freqEstHz - frequencyOffsetHz;
freqVar = var(freqErrHz);
fprintf('Error Variance = %g\n\n', freqVar);

% Plot constellations
figure(1); clf;
subplot(1,2,1);
scatter(real(offsetData(timeIndex)),imag(offsetData(timeIndex)));
grid on;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
xlabel('In-phase')
ylabel('In-phase')
subplot(1,2,2)
scatter(real(syncData(timeIndex)),imag(syncData(timeIndex)),'r')
grid on;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
xlabel('In-phase')
ylabel('In-phase')

% Plot PLL estimate
figure(2); clf;
plot(diff(phaseEst)/(2*pi)*sampleRateHz,'r');
hold on;
plot(frequencyOffsetHz+frequencyDriftHz.*(1:numSamples).'/sampleRateHz,'b');
grid on;
xlabel('Estimate')
ylabel('Offset (Hz)')
legend('PLL Estimate','True Offset','Location','southeast')
