% STFT Parameters
winSize = 32;
fftSize = 128;

% Extract binary data written by Fosphor
fid = fopen('keyfob.dat');
data = fread(fid,'single');
fclose(fid);

% Pack real and imaginary parts of data
data = complex(data(1:2:end),data(2:2:end));

% Form data cube from collected data
numTrunc = mod(numel(data),winSize);
data = data(1:(end-numTrunc));
data = reshape(data,winSize,[]);

% Perform a STFT on the data
Fdata = fft(data.*blackmanharris(winSize),fftSize);

% FFT shift the data for viewing
Fdata = fftshift(Fdata,1);

% Create frequency axis for ploting
f = -(fftSize/2):(fftSize/2-1);
f = f/fftSize;
f = f + 433.92;

% Create time axis for plotting
t = 0:(size(Fdata,2)-1);
t = t*winSize/1e6;

% Plot the data
imagesc(t,f,db(Fdata));

% Label the plot
xlabel('Time (s)')
ylabel('Frequency (MHz)')
title('KeyFob Spectrogram');