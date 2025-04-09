%% Lab 1 Part 2: Fine Frequency Correction

% Debugging flags
visuals = false;

%% General system details
sampleRateHz = 1e3; % Sample rate
samplesPerSymbol = 1;
frameSize = 2^10;
numFrames = 300;
numSamples = numFrames*frameSize; % Samples to simulate

%% Setup objects
mod = comm.DBPSKModulator();
mod = comm.QPSKModulator();
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

cdOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPreOut = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');

%% Impairments
snr = 15;
frequencyOffsetHz = sampleRateHz*0.02; % Offset in hertz
phaseOffset = 0; % Radians

%% Generate symbols
rng(0);
data = randi([0 3], numSamples, 1);
modulatedData = mod.step(data);

%% Add noise
noisyData = awgn(modulatedData,snr);%,'measured');

%% Model of error
% Add frequency offset to baseband signal

carrierSync = CarrierSynchronizer('ModulationOrder',4);
% carrierSync = comm.CarrierSynchronizer("SamplesPerSymbol",1,'Modulation','QAM');

% Precalculate constants
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;

offsetData = zeros(size(noisyData));
syncData = zeros(size(noisyData));
phaseError = zeros(size(noisyData));
for k=1:frameSize:numSamples
    
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = noisyData(timeIndex).*freqShift;
    for j = timeIndex(1):timeIndex(end)
        [syncData(j), phaseError(j)] = carrierSync(offsetData(j));
    end
    % [syncData(timeIndex), phaseError(timeIndex)] = carrierSync(offsetData(timeIndex));
    
    % Visualize Error
    if visuals
        step(cdPre,noisyData(timeIndex));step(cdPost,offsetData(timeIndex));pause(0.1); %#ok<*UNRCH>
        step(cdOut,syncData(timeIndex));
    end
    
end

figure(1);
hold on;
plot(real(syncData));

figure(2);
hold on;
plot(phaseError);
