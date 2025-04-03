% User tunable (samplesPerSymbol>=decimation)
samplesPerSymbol = 8; decimation = 4;
useDspkMod = false;
%% System set up
% Set up radio
tx = sdrtx('Pluto','Gain',-10);
rx = sdrrx('Pluto','SamplesPerFrame',1e6,'OutputDataType','double');
% Create binary data for 48, 2-bit symbols
data = randi([0 1],2^12,1);
% Modulate data
mod = comm.QPSKModulator('BitInput',true);
modData = mod(data);
% Set up filters
rctFilt = comm.RaisedCosineTransmitFilter( ...
    'OutputSamplesPerSymbol', samplesPerSymbol);
rcrFilt = comm.RaisedCosineReceiveFilter( ...
    'InputSamplesPerSymbol',  samplesPerSymbol, ...
    'DecimationFactor',       decimation);
% Pass data through radio
tx.transmitRepeat(rctFilt(modData));
data = rcrFilt(rx());
% Set up visualization and delay objects
VFD = dsp.VariableFractionalDelay;
cdPre = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband');
cdPost = comm.ConstellationDiagram('ReferenceConstellation', [-1 1],...
    'Name','Baseband after Timing Sync');
cdPre.Position(1) = 50;
cdPost.Position(1) = cdPre.Position(1)+cdPre.Position(3)+10;% Place side by side
% Get the oversample rate
OSR = samplesPerSymbol/decimation;
% Run a zero-gain boxcar filter prior to decimation
rxRaw = data(1:2:end);
% o = sum(reshape(data,OSR,[]))/OSR;
% Plot data with no delay
symbolSync = comm.SymbolSynchronizer();
[rxSync,~] = symbolSync(data);
ccOut = xcorr(rxRaw, rxSync, 32);
[~, maxIdx] = max(abs(ccOut));
dly = 33 - maxIdx;
rxSync = rxSync((dly+1):end);
% Grab end of data where AGC has converged
rxRaw = rxRaw(2000:end);
rxSync = rxSync(2000:end);
if useDspkMod
    % rxRaw = rxRaw(2:end).*exp(-1i*angle(rxRaw(1:(end-1))));
    rxSync = rxSync(2:end).*exp(-1i*angle(rxSync(1:(end-1))));
end
cdPre(rxRaw(:));
cdPost(rxSync(:));

% %% Process received data for timing offset
% for index = 0:300
%     % Delay signal
%     tau_hat = index/50;
%     delayedsig = VFD(data, tau_hat);
%     % Linear interpolation
%     o = sum(reshape(delayedsig,OSR,[]))/OSR;
%     % Visualize constellation
%     cd(o(:));
%     pause(0.1);
% end