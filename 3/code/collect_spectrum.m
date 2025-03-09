% Flag to collect data or load 
% data from a .mat file
collectData = false;

% Frequencies to sweep over
f = 60e6:20e6:5.98e9;

% Determine center frequency
f = f+10e6;

% Collect data with the Pluto
if collectData

    % Create an SDR Receiver Object
    rx = sdrrx('Pluto',...
        'GainSource','Manual', ...
        'CenterFrequency',2.4e9,...
        'Gain', 60,...
        'SamplesPerFrame', 32768,...
        'BasebandSampleRate',20e6);

    % Create an SDR Transmitter Object
    tx = sdrtx('Pluto', ...
        'BasebandSampleRate',20e6,...
        'CenterFrequency',6e9,...
        'Gain',-89.5);

    % Create an empty array of zeros
    data = zeros(32768,length(f));

    % Sweep over all frequencies
    for i = 1:length(f)

        % Set the center frequency in the receiver
        rx.CenterFrequency = f(i);

        % Update the transmitter whenever we cross the middle of
        % the frequency range. This ensures our transmitted signal
        % doesn't interfere with our collect
        if rx.CenterFrequency > median(f)
            if tx.CenterFrequency > median(f)
                tx.CenterFrequency = 70e6;
                tx.release
                tx(complex(zeros(1024,1)));
            end
        else
            if tx.CenterFrequency < median(f)
                tx.CenterFrequency = 6e9;
                tx.release
                tx(complex(zeros(1024,1)));
            end
        end

        % Clear buffers in the Pluto, so we don't get stale data
        rx.release

        % Collect a buffer of samples
        data(:,i) = rx();
    end

% Load old data instead of rerunning
else
    load('data.mat','data');
end

% Perform an FFT of the data
Fdata = fftshift(fft(data.*blackmanharris(size(data,1))),1);

% Normalize by FFT size and ADC bitwidth to get dBFS
Fdata = db(Fdata(:)) - 20*log10(size(data,1)) - 20*log10(2048);

% Determine the normalized frequency over the collect
fwin = (0:(size(data,1)-1)).';
fwin = fwin/length(fwin)-0.5;

% Determine the frequency in Hz for each point in data
f = f + fwin*20e6;
f = f(:);

% Use MHz instead of Hz
f = f/1e6;

% Plot entire spectrum
plot(f,Fdata);
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)');
title('Pluto SDR Spectrum')
grid on;