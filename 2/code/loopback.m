% Pluto Gain Source Configuration
gainSource = 'AGC Slow Attack'; %AGC Fast Attack'; % Default is 'AGC Slow Attack';
gain = 30; % Default is 10

% Desired Frequency
freq = 300;

% Modify sinusoid
dutyCycle = 0.5;
rampData = false;

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
desiredSamplesPerFrame = 5e5;
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
tx = sdrtx('Pluto','Gain',-50);

% Create the Sinewave
sine = dsp.SineWave('Frequency',freq,...
                    'SampleRate',rx.BasebandSampleRate,...
                    'SamplesPerFrame', samplesPerFrame,...
                    'ComplexOutput', true);
data = sine();

% Ramp the data
if rampData
    data = data.*(1:length(data)).'/length(data);
end

% Zero out a portion of the pulse
pulseTime = round(length(data)*dutyCycle);
data(pulseTime+1:end) = 0;
mf = flip(conj(data(1:pulseTime)));

% Transmit continuously
tx.transmitRepeat(data);
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

save('data.mat','data');

% % Meausre SNR
% if dutyCycle < 1
%     mfOut = fftfilt(mf,data);
%     mfPwrOut = mfOut.*conj(mfOut);
%     [~,I] = max(mfPwrOut);
%     priStart = I - pulseTime + 1;
%     priStart = priStart + 8;
%     priLen = size(data,1);
%     priLen = priLen = 
% 
% 
%     numPulses = steps;
% 
%     % priStart = 
%     % priStart = priStart + priLen;
% 
% 
%     pwr = abs(data(:).^2);
% 
%     tau_fast = 16;
%     tau_slow = size(data,1)*dutyCycle/5;
%     alpha_fast = exp(-1/tau_fast);
%     alpha_slow = exp(-1/tau_slow);
%     pwr_fast = filter(1-alpha_fast,[1 -alpha_fast],pwr);
%     pwr_slow = filter(1-alpha_slow,[1 -alpha_slow],pwr);
% 
%     % plot(db(fftfilt(mf,data(:))));
%     figure(1); 
%     clf;
%     plot(pwr_slow);
%     hold on;
%     plot(pwr_fast);
% 
%     figure(2)
%     clf;
%     pwrDelta_dB = db(pwr_fast) - db(pwr_slow);
%     plot(pwrDelta_dB)
% 
%     priLen = size(data,1);
%     coolDown = 0;
%     priStart = false(size(data(:)));
%     priEnd = false(size(data(:)));
%     for i = (2*priLen):length(pwr)
%         if coolDown == 0
%             if (pwrDelta_dB(i) > 20)
%                 priStart(i) = true;
%                 coolDown = priLen*0.75;
%             end
%         else
%             coolDown = coolDown - 1;
%         end
%     end
%     coolDown = 0;
%     for i = (2*priLen):length(pwr)
%         if coolDown == 0
%             if (pwrDelta_dB(i) < -20)
%                 priEnd(i) = true;
%                 coolDown = priLen*0.75;
%             end
%         else
%             coolDown = coolDown - 1;
%         end
%     end
%     hold on;
%     plot(priStart*max(pwrDelta_dB));
%     plot(priEnd*min(pwrDelta_dB));
% 
%     avgPwr = mean(pwr);
%     maxSigPwr = 2*avgPwr;
%     pwrThreshold = maxSigPwr/10;
%     sigDet = (pwr > pwrThreshold);
%     isNoise = ~sigDet;
%     isData = sigDet;
%     figure(1)
%     clf;
%     plot(sigDet);
%     % isNoise = ~isData;
%     Pn = mean(abs(data(isNoise)).^2,'all');
%     Psn = mean(abs(data(isData)).^2,'all');
%     SNR_dB = 10*log10((Psn - Pn)/Pn);
%     fprintf('SNR(dB) = %.2f dB\n', SNR_dB)
% end
% % plot(db(fft(data(:))));