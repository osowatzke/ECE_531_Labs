% User tunable (samplesPerSymbol>=decimation)
samplesPerSymbol = 8; decimation = 4;
frameSize = 2^16;
useDspkMod = true;
% Gain on transmitter
txGain = -65:5:-20;
evm_dB = zeros(size(txGain));
for i = 1:length(txGain)
    %% System set up
    % Set up radio
    tx = sdrtx('Pluto','SamplesPerFrame',frameSize*8,'Gain',txGain(i));
    rx = sdrrx('Pluto','SamplesPerFrame',frameSize*8,'OutputDataType','double','GainSource', 'Manual');
    % Create binary data for 48, 2-bit symbols
    data = randi([0 1],2^16,1);
    % Modulate data
    mod = comm.DBPSKModulator(); %QPSKModulator('BitInput',true);
    modData = complex(mod(data));
    % Set up filters
    rctFilt = comm.RaisedCosineTransmitFilter( ...
        'OutputSamplesPerSymbol', samplesPerSymbol);
    rcrFilt = comm.RaisedCosineReceiveFilter( ...
        'InputSamplesPerSymbol',  samplesPerSymbol, ...
        'DecimationFactor',       decimation);
    % Pass data through radio
    tx.transmitRepeat(rctFilt(modData));
    data = rcrFilt(rx());
    meanPwr = mean(data(4000:end).*conj(data(4000:end)));
    10*log10(meanPwr)
    data = data/sqrt(meanPwr);
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
    ccOut = xcorr(modData, rxSync);
    [~, maxIdx] = max(abs(ccOut));
    dly = floor(length(ccOut)/2) + 1 - maxIdx;
    if dly < 0
        dly = dly + length(rxSync);
    end
    rxSync = rxSync((dly+1):end);
    % Grab end of data where AGC has converged
    rxRaw = rxRaw(2000:end);
    rxSync = rxSync(2000:end);
    modData = modData(2000:end);
    if useDspkMod
        % rxRaw = rxRaw(2:end).*exp(-1i*angle(rxRaw(1:(end-1))));
        rxSync = rxSync(2:end).*exp(-1i*angle(rxSync(1:(end-1))));
        modData = modData(2:end).*exp(-1i*angle(modData(1:(end-1))));
    end
    minSize = min(length(rxSync),length(modData));
    rxSync = rxSync(1:minSize);
    modData = modData(1:minSize);
    % cdPre(rxRaw(:));
    % cdPost(rxSync(:));
    evm = comm.EVM();
    evm_dB(i) = 20*log10(evm(modData,rxSync)/100);
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
end
figure(1);
clf;
plot(txGain, evm_dB,'LineWidth',1.5);
grid on;
xlabel('Tx Gain (dB)');
ylabel('EVM (dB)')