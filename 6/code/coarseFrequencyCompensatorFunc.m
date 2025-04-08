% Function performs coarse frequency compensation
function data = coarseFrequencyCompensator(data, modOrder)
    
    % Remove modulation
    dataPwr = data.^modOrder;

    % Determine best FFT size
    fftSize = 2^(ceil(log2(length(data))));

    % Take the FFT
    Fdata = fft(dataPwr,fftSize);

    % Find the FFT peak
    [~,maxIdx] = max(abs(Fdata));
    
    % Estimate the frequency of the signal using the peak
    f = (maxIdx-1)/(modOrder*fftSize);

    % Remove CFO from data
    t = (0:(length(data)-1)).';
    data = data.*exp(-1i*2*pi*f*t);
end