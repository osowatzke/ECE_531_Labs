bits = ASCII2bits('Arizona');
SNR_dB = -10:2:10;
treshold = 0:1:40;
numRuns = 100;
codeGen = comm.BarkerCode('Length',7,'SamplesPerFrame',13);
preamble = codeGen();
dataLen = 500;
symbolGen = @(len) pskmod(randi([0 1], len, 1), 2);
for i = 1:length(SNR_dB)
    falseAlarms = zeros(1,length(treshold));
    missedDetections = zeros(1,length(treshold));
    probFalseAlarm = zeros(1,length(treshold));
    probMissedDetection = zeros(1,length(treshold));
    for j = 1:length(treshold)
        prbdet = comm.PreambleDetector(...
            'Preamble',  preamble,...
            'Threshold', treshold(j));
        for k = 1:numRuns
            delay = randi([0 dataLen-length(preamble)]);
            numSymbolsStart = delay;
            numSymbolsEnd = dataLen-delay-length(preamble);
            data = [symbolGen(numSymbolsStart); preamble; symbolGen(numSymbolsEnd)];
            data = awgn(data,SNR_dB(i));
            idx = prbdet(data);
            delayEst = idx - length(preamble);
            missedDetections(j) = missedDetections(j) + ~any(delayEst == delay);
            falseAlarms(j) = falseAlarms(j) + sum(delayEst ~= delay);
            % data = data(idx+1:idx+length(preamble));
            % bits = pskdemod(data,2);
            % str = bits2ASCII(bits);
        end
        chargedSamples = (dataLen-length(preamble)+1);
        probFalseAlarm(j) = falseAlarms(j)/(numRuns*dataLen);
        probMissedDetection(j) = missedDetections(j)/(numRuns);
    end
    probDetection = 1 - probMissedDetection;
    plot(probFalseAlarm, probDetection);
    hold on;
end