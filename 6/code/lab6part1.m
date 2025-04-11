%% General system details
sampleRateHz = 1e6; % Sample rate
modulationOrder = 2;
frameSize = 2^10;
numFrames = 100;
numSamples = numFrames*frameSize; % Samples to simulate
filterUpsample = 4;
filterSymbolSpan = 8;

%% Simulation flags
visualizeError = false;
visualizeCfc = true;
useBuiltInCfc = false;

%% Impairments
snr = 15;
frequencyOffsetHz = 1e5; % Offset in hertz
phaseOffset = 0; % Radians

%% Generate symbols
data = randi([0 modulationOrder-1], numSamples, 1);
if modulationOrder == 2
    mod = comm.DBPSKModulator();
else
    mod = comm.QPSKModulator();
end
modulatedData = mod.step(data);

%% Add TX Filter
TxFlt = comm.RaisedCosineTransmitFilter('OutputSamplesPerSymbol', filterUpsample, ...
    'FilterSpanInSymbols', filterSymbolSpan);
filteredData = step(TxFlt, modulatedData);

%% Add noise
noisyData = awgn(filteredData,snr);

%% Setup visualization object(s)
sa = dsp.SpectrumAnalyzer('SampleRate',sampleRateHz,'ShowLegend',true);

%% Model of error
% Add frequency offset to baseband signal

% Coarse Frequency Compensation
if useBuiltInCfc
    if modulationOrder == 2
        Modulation = 'BPSK';
    else
        Modulation = 'QPSK';
    end
    coarseFrequencyComp = comm.CoarseFrequencyCompensator(...
        'SampleRate',sampleRateHz,'Modulation',Modulation);
else
    coarseFrequencyComp = CoarseFrequencyCompensator('SampleRate',sampleRateHz,...
        'ModulationOrder',modulationOrder);
end

% Precalculate constant(s)
normalizedOffset = 1i.*2*pi*frequencyOffsetHz./sampleRateHz;

offsetData = zeros(size(noisyData));
compData = zeros(size(noisyData));
for k=1:frameSize:numSamples*filterUpsample

    % Create phase accurate vector
    timeIndex = (k:k+frameSize-1).';
    freqShift = exp(normalizedOffset*timeIndex + phaseOffset);
    
    % Offset data and maintain phase between frames
    offsetData(timeIndex) = (noisyData(timeIndex).*freqShift);
    
    % Coarse Frequency Compensation
    if useBuiltInCfc
        compData(timeIndex) = coarseFrequencyComp(offsetData(timeIndex));
    else
        [compData(timeIndex), ~, Fdata] = coarseFrequencyComp(offsetData(timeIndex));
    end
    
    % Visualize Error
    if visualizeError
        plotData = [noisyData(timeIndex),offsetData(timeIndex)];
        if visualizeCfc
            plotData = [plotData, compData(timeIndex)];
        end
        step(sa,plotData); pause(0.1);
    end
    
end
%% Plot
df = sampleRateHz/frameSize;
frequencies = -sampleRateHz/2:df:sampleRateHz/2-df;
spec = @(sig) fftshift(10*log10(abs(fft(sig))));
h = plot(frequencies, spec(noisyData(timeIndex)),...
     frequencies, spec(offsetData(timeIndex)));
legendText = {'Original','Offset'};
if visualizeCfc
    hold on;
    plot(frequencies, spec(compData(timeIndex)));
    legendText = [legendText, {'Corrected'}];
    hold off;
end
grid on;xlabel('Frequency (Hz)');ylabel('PSD (dB)');
legend(legendText,'Location','Best');
NumTicks = 5;L = h(1).Parent.XLim;
set(h(1).Parent,'XTick',linspace(L(1),L(2),NumTicks))

if visualizeCfc && ~useBuiltInCfc
    figure(2);
    clf;
    Fdata = fftshift(db(Fdata));
    [maxVal, maxIdx] = max(Fdata);
    frequencies = (0:(length(Fdata)-1))/length(Fdata);
    frequencies = frequencies - 0.5;
    frequencies = frequencies*sampleRateHz;
    plot(frequencies, Fdata);
    hold on;
    scatter(frequencies(maxIdx), maxVal, 'red', '*');
    grid on;xlabel('Frequency (Hz)');ylabel('PSD (dB)');
    title(sprintf('Max Frequency: %.f Hz, Frequency Est: %.f Hz',...
        frequencies(maxIdx), frequencies(maxIdx)/modulationOrder));
end
