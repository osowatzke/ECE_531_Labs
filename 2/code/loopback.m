% Pluto Gain Source Configuration
gainSource = 'AGC Fast Attack'; % Default is 'AGC Slow Attack';
gain = 30; % Default is 10

% Desired Frequency
freq = 300;

% Setup Receiver
rx=sdrrx('Pluto',...
    'GainSource',gainSource,...
    'OutputDataType','double',...
    'EnableBurstMode',false);

% Can only set gain for manual AGC
if strcmp(gainSource, 'Manual')
    rx.Gain = gain;
end

% Choose the frame size to capture an integer number of sinusoid periods
% Commanded frequency must be an integer or gcd function will not work
if mod(freq,1) ~= 0
    warning('Rounding frequency to nearest integer');
    freq = round(freq);
end

% Want f/fs = M/N where M and N are integers
% Solve for N (# samples per frame)
freqDivisor = gcd(rx.BasebandSampleRate,freq);
samplesPerFrame = rx.BasebandSampleRate/freqDivisor;

% Can scale number of samples per frame by any integer
% Choose an integer that gets us clsoe to 2^15
desiredSamplesPerFrame = 2^15;
samplesPerFrame = samplesPerFrame*...
    round(desiredSamplesPerFrame/samplesPerFrame);

% If there isn't an integer less than 2^16 (2x desired samples/frame)
% Give up and pick the closest frequency
if samplesPerFrame == 0
    samplesPerFrame = desiredSamplesPerFrame;
    frameDuration = samplesPerFrame/rx.BasebandSampleRate;
    freq = round(frameDuration*freq)/frameDuration;
    warning('Unable to find a good frame size. Modifying frequency to %g Hz', freq); 
end

% Print the number of samples per frame
fprintf('samplesPerFrame = %d\n', samplesPerFrame);

% Set the frame size on the receiver
rx.SamplesPerFrame = samplesPerFrame;

% Setup Transmitter
tx = sdrtx('Pluto','Gain',-30);

% Transmit sinewave
sine = dsp.SineWave('Frequency',freq,...
                    'SampleRate',rx.BasebandSampleRate,...
                    'SamplesPerFrame', samplesPerFrame,...
                    'ComplexOutput', true);
data = data.*(1:length(data)).'/length(data);
tx.transmitRepeat(sine()); % Transmit continuously
% Setup Scope
samplesPerStep = rx.SamplesPerFrame/rx.BasebandSampleRate;
steps = 3;
ts = timescope('SampleRate', rx.BasebandSampleRate,...
               'TimeSpan', samplesPerStep*steps,...
               'BufferLength', rx.SamplesPerFrame*steps);
% Receive and view sine
data = zeros(samplesPerFrame,steps);
for k=1:steps
  [data(:,k),~,overflow] = rx();
  if (overflow)
        warning('### Receiver overflow occurred on frame %d, data has been lost.', k);
  end
end
ts(data(:));
