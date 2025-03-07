% Center frequency (2.412e9 for 2.4 GHz band and 5.18e9 for 5GHz band)
centerFreq = 5.180e9;

% Sample rate for scope. Want larger than 20 MHz signal bandwidth
sampleRate = 40e6;

% Capture data contiguously using large buffer size
samplesPerFrame = 32768*16;

% Create Pluto receiver
rx = sdrrx('Pluto',...
    'BasebandSampleRate',sampleRate,...
    'CenterFrequency',centerFreq,...
    'SamplesPerFrame',samplesPerFrame,...
    'GainSource','Manual',...
    'Gain', 62);

% Select a transmit frequency as far as possible from the
% receive frequency
freqRange = [70e6, 6e9];
freqCenter = mean(freqRange);
if rx.CenterFrequency > freqCenter
    txCenterFreq = freqRange(1);
else
    txCenterFreq = freqRange(end);
end

% Disable transmitter
tx = sdrtx('Pluto', ...
    'BasebandSampleRate',sampleRate,...
    'CenterFrequency',txCenterFreq,...
    'Gain',-89.5);
tx(complex(zeros(1024,1)));

% Initialize spectrum analyzer
scope = spectrumAnalyzer(...
    'PlotMaxHoldTrace',true,...
    'ViewType','spectrum-and-spectrogram',...
    'AveragingMethod','Running',...
    'SpectrumUnits','dBFs',...
    'FrequencyOffset',centerFreq,...
    'SampleRate',sampleRate);

% Capture data
data = rx();

% Plot spectrum
scope(data);

figure(1)
clf;
imagesc(fftshift(db(fft(reshape(data,8192,[]).*blackmanharris(8192))),1));