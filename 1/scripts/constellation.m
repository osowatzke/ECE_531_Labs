% Frequency of source
freq = 2000;

% Sampling rate
samp_rate = 39.8e3;

% Analong over sample rate
OSR = 16;

% Determine sample rate of simulation
sim_rate = samp_rate*OSR;

% Number of received samples
N = 1024;

% Time axis for simulation data
n = 0:(N*OSR-1);

% Create transmitted signal
x = exp(1i*2*pi*freq/sim_rate*n);

% I/Q Magnitude Imbalance
eps = 0;

% I/Q Phase Imbalance
phi = pi/4;

% Carrier Frequency
fc = 0.3;

% Mix signal to carrier frequency
tx_sig = real(x)*(1+eps).*cos(2*pi*fc*n+phi)-imag(x).*sin(2*pi*fc*n);

% Arbitrary Scale Factor to Simplify Math
tx_sig = tx_sig*2;

% Mix and LPF signal
rx_sig = tx_sig.*exp(-1i*2*pi*fc*n);
h = fir1(31,fc);
rx_sig = filtfilt(h,1,rx_sig);

% Decimate to get back to sampled signal
rx_sig = rx_sig(1:OSR:end);

% Create plot of constellation
figure(1); clf;
scatter(real(rx_sig),imag(rx_sig));
xlim([-1.5 1.5])
ylim([-1.5 1.5])

% Generate received signal based on formulas stated in homework submission
ar = (1+eps)*cos(phi);
ai = 1i*(1+eps)*sin(phi)+1;
ai_mag = abs(ai);
ai_phase = angle(ai);
f = freq/samp_rate;
x = ar*cos(2*pi*f*(0:999)) + 1i*ai_mag*sin(2*pi*f*(0:999)+ai_phase);

% Create scatter plot with received signal
figure(2); clf;
scatter(real(x),imag(x))
hold on;

% Show form in problem is mathematically equivalent
ai_mag = sqrt(1+(1+eps)^2*sin(phi)^2);
ai_phase = atan((1+eps)*sin(phi));
x = ar*cos(2*pi*f*(0:999)) + 1i*ai_mag*sin(2*pi*f*(0:999)+ai_phase);
scatter(real(x),imag(x))
xlim([-1.5 1.5])
ylim([-1.5 1.5])
