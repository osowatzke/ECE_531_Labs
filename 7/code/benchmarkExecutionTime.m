% Configure preamble position
gapLen = 100;
gapLenEnd = 200;
gen = @(Len) 2*randi([0 1],Len,1)-1;

% Number of runs to do at each sequence length
numRuns = 2048;

% Sequence lengths to test
sequenceLength = 10:50:2000;

% Allocate arrays for execution time
xcorrExecutionTime = zeros(numRuns, length(sequenceLength));
filterExecutionTime = zeros(numRuns, length(sequenceLength));

% Allocate arrays for error counts
xcorrNumErrors = zeros(length(sequenceLength),1);
filterNumErrors = zeros(length(sequenceLength),1);

% Loop for each sequence length
for j = 1:length(sequenceLength)

    % Generate code
    codeGen = comm.BarkerCode('Length',7,'SamplesPerFrame', sequenceLength(j));
    seq = codeGen();

    % Generate matched filter for filter implementation
    h = flip(conj(seq));

    % Create received data
    y = [gen(gapLen); seq; gen(gapLenEnd)];

    % Loop for each monte carlo run
    for i = 1:numRuns

        % Capture xcorr output and execution time
        tic; corr = xcorr(y,seq);
        xcorrExecutionTime(i,j) = toc;

        % Estimate preamble position
        [~, maxIdx] = max(abs(corr));
        gapLenEst = maxIdx - length(y);

        % Update error count
        xcorrNumErrors(j) = xcorrNumErrors(j) + (gapLenEst ~= gapLen);

        % Capture filter output and execution time
        tic; filt = filter(h,1,y);
        filterExecutionTime(i,j) = toc;

        % Estimate preamble position
        [~, maxIdx] = max(abs(filt));
        gapLenEst = maxIdx - sequenceLength(j);

        % Update error count
        filterNumErrors(j) = filterNumErrors(j) + (gapLenEst ~= gapLen);
    end
end

% Compute probability of error
xcorrProbErrors = xcorrNumErrors/numRuns;
filterNumErrors = filterNumErrors/numRuns;

% Print maximum error probabilities
fprintf('Max xcorr Error Probability: %.4f\n', max(xcorrProbErrors));
fprintf('Max filter Error Probability: %.4f\n', max(filterNumErrors));

% Plot exeuction times
figure(1);
clf;
hold on;
plot(sequenceLength, mean(xcorrExecutionTime));
plot(sequenceLength, mean(filterExecutionTime));
box on;
grid on;
title('Execution Time Comparison')
legend('xcorr','filter');
xlabel('Sequence Length');
ylabel('Execution Time (s)')