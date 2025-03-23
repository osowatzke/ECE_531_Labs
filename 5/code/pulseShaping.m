% Set random number generator seed for repeatability
rng(0);

% Transmit filter
txFilter = comm.RaisedCosineTransmitFilter;

% Receive Filter
rxFilter = comm.RaisedCosineReceiveFilter('DecimationFactor',1);

% Get filter group delays
txGd = grpdelay(coeffs(txFilter).Numerator,1,1);
rxGd = grpdelay(coeffs(rxFilter).Numerator,1,1);

% Time in milliseconds
t1 = (0:20).';

% Create random symbols
bits = randi([0 1], size(t));
txSymbols = real(pskmod(bits,2));

% Run TX pulse-shaping FIR
% Account for group delay of filter
txSymbolsPad = [txSymbols; zeros(ceil(txGd/8),1)];
txSig = txFilter(txSymbolsPad);
txSig = txSig((txGd+1):end);
txSig = txSig(1:(8*length(txSymbols)));

% Create receive signal with noise
rxSig = awgn(txSig,10);

% Create Time-Axis
t2 = t1.' + (0:7).'/8;
t2 = t2(:);

% Run Receive Filter
rxSigPad = [rxSig; zeros(rxGd,1)];
rxFiltOut = rxFilter(rxSigPad);
rxFiltOut = rxFiltOut((rxGd+1):end);
rxSymbols = sign(rxFiltOut(1:8:end));

% Get the Received Symbols with a Filter for Reference
rxSymbolsNoFilt = sign(rxSig(1:8:end));

figure(1); clf;
subplot(3,1,1)
stem(t1, txSymbols,'kx-');
hold on;
plot(t2, rxSig,'r');
plot(t2, txSig,'bo-');
xlabel('Time (ms)');
ylabel('Amplitude');
legend('Transmitted Data','Received Data with Noise','Transmitted SRRC',...
    'Location','southeast');

subplot(3,1,2)
stem(t1, txSymbols,'kx-');
hold on;
plot(t2, rxFiltOut,'b');
stem(t1, rxSymbols,'mo-');
xlabel('Time (ms)');
ylabel('Amplitude');
legend('Transmitted Data','Rcv Filter Output','Demodulated',...
    'Location','southeast');

subplot(3,1,3)
stem(t1, txSymbols,'kx-');
hold on;
plot(t2, rxSig,'r');
stem(t1, rxSymbolsNoFilt,'mo-');
xlabel('Time (ms)');
ylabel('Amplitude');
legend('Transmitted Data','Received Data with Noise','Demodulated',...
    'Location','southeast');

