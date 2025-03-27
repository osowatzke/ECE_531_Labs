% User tunable (samplesPerSymbol>=decimation)
samplesPerSymbol = 12; decimation = 4;
%% System set up
% Set up radio
tx = sdrtx('Pluto','Gain',-10);
rx = sdrrx('Pluto','SamplesPerFrame',1e6,'OutputDataType','double');
% Create binary data for 48, 2-bit symbols
data = randi([0 1],2^15,1);
% Modulate data
modData = pskmod(data,4,pi/4,'InputType','bit');
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
cd = comm.ConstellationDiagram;
% Get the oversample rate
OSR = samplesPerSymbol/decimation;
% Grab end of data where AGC has converged
data = data(end-OSR*1000+1:end);
% Run a zero-gain boxcar filter prior to decimation
o = sum(reshape(data,OSR,[]))/OSR;
% Plot data with no delay
cd(o(:));
pause;
%% Process received data for timing offset
for index = 0:300
    % Delay signal
    tau_hat = index/50;
    delayedsig = VFD(data, tau_hat);
    % Linear interpolation
    o = sum(reshape(delayedsig,OSR,[]))/OSR;
    % Visualize constellation
    cd(o(:));
    pause(0.1);
end