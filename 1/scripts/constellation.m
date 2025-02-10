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
phi = 3*pi/16 + pi;

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
% xlim([-1.5 1.5])
% ylim([-1.5 1.5])

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
% x = ar*cos(2*pi*f*(0:999)) + 1i*ai_mag*sin(2*pi*f*(0:999)+ai_phase);
% theta = phi/2+pi/4-3*pi/2
% 0.5*atan2(sin(2*phi),(cos(2*phi)-1))]
n = mod(round(mod(phi/(2*pi),1)*4),4)
% if n == 2
%     n = 0;
% end
n = 0
theta = 0.5*atan(((1+eps)^2*sin(2*phi))/((1+eps)^2*cos(2*phi)-1)) + n*pi/2;
% if (sign(cos(theta)) ~= sign(cos(phi-theta)))
%     error('Bad Rotation Angle');
% end
% theta/pi
t = 0:999;
a1_mag = sqrt((1+eps)^2*cos(phi-theta)^2+sin(theta)^2);
a2_mag = sqrt((1+eps)^2*sin(phi-theta)^2+cos(theta)^2);
a1_phase = atan2(-sin(theta),(1+eps)*cos(phi-theta))
a2_phase = atan2((1+eps)*sin(phi-theta),cos(theta))
x = a1_mag*cos(2*pi*f*t+a1_phase) + 1i*a2_mag*sin(2*pi*f*t+a2_phase);
% x = x*exp(1i*theta);
% x = sqrt(1+2*(1+eps)*cos*cos(phi-theta)*cos(2*pi*f*(0:999))+
scatter(real(x),imag(x))
% xlim([-1.5 1.5])
% ylim([-1.5 1.5])
% x = a1_mag*cos(2*pi*f*t+a1_phase) + 1i*a2_mag*sin(2*pi*f*t+a1_phase);
scatter(real(x),imag(x))