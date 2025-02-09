% Create transmitted signal
x = exp(1i*2*pi*(0.001)*(0:999));

% Mix signal to IF
mix_sig = exp(1i*2*pi*(0.15)*(0:999));
tx_sig = real(x).*real(mix_sig) - imag(x).*imag(mix_sig);

% Compute receive dsignal
rx_sig = 2*tx_sig.*conj(mix_sig);
h = fir1(31,0.15);
rx_sig = filtfilt(h,1,rx_sig);

% Plot transmitted and received signals on same axis
% Should be the same if we are doing things right
figure(1); clf;
plot(real(x));
hold on;
plot(real(rx_sig));
figure(2); clf;
plot(imag(x));
hold on;
plot(imag(rx_sig));