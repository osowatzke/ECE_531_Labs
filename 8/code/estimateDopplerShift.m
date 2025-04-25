% Radius in meters
r = 0.25;

% Distance to fan 
d = 0.4;

% Get wavelength
fc = 2.4e9;
c = 3e8;
lambda = c/fc;

% Define rotation in rpm
w = 1200;

% Convert to rad/s
w = w*(2*pi)/60;

% Radial distance as a function of time
dist = @(t) sqrt(r^2*cos(w*t).^2 + (r*sin(w*t) + r).^2 + d^2);

% Create time vector over multiple cycles of movement
num_cylces = 1;
dt = 1e-5;
t = 0:dt:num_cylces*(2*pi/w);

% Compute the doppler shifts as a function of time
fd = zeros(1,length(t));
for i = 1:length(t)
    dr = (dist(t(i)+dt) - dist(t(i)))/dt;
    fd(i) = 2*dr/lambda;
end

% Plot the doppler shift against time
figure(1); clf;
plot(t*1e3, fd, 'LineWidth', 1.5);
grid on;
xlabel('Time (ms)')
ylabel('Doppler shift (Hz)')

% Compute a frequency axis for plotting
fs = 1/dt;
faxis = fs*(0:(length(t)-1))/(length(t));
faxis = faxis - fs*(faxis >= fs/2);
faxis = fftshift(faxis);

% Determine the phase of the resulting waveform
phi = filter(1,[1 -1],2*pi*fd.*dt);

% Plot the spectrum of the return
figure(2); clf;
plot(faxis/1e3,db(fftshift(fft(exp(1i*phi)))), 'LineWidth', 1.5)
grid on;
xlabel('Frequency (kHz)')
ylabel('Magnitude (dB)')
