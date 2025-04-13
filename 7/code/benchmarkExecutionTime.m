% Configure preamble position
gapLen = 100;
gapLenEnd = 200;

% Note we create low-power noise instead of BPSK symbols so we have 0
% Probability of error. This is useful for ensuring we can correctly
% determine the start of the frame, but will not happen in practice.
gen = @(Len) 0.01*randn(Len,1);

% Number of runs to do at each sequence length
numRuns = 1000;

% Sequence lengths to test
sequenceLength = 10:10:2000;

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

    % Loop for each monte carlo run
    for i = 1:numRuns

        % Create received data
        y = [gen(gapLen); seq; gen(gapLenEnd)];

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

% Compute error probabilities
xcorrProbErrors = xcorrNumErrors/numRuns;
filterNumErrors = filterNumErrors/numRuns;

% Print maximum error probabilities
fprintf('Max xcorr Error Probability: %.4f\n', max(xcorrProbErrors));
fprintf('Max filter Error Probability: %.4f\n', max(filterNumErrors));

% Get average execution times
xcorrAvgExecutionTime = mean(xcorrExecutionTime);
filterAvgExecutionTime = mean(filterExecutionTime);

% Compute speedup
speedup = xcorrAvgExecutionTime./filterAvgExecutionTime;

% Plot exeuction times
figure(1);
clf;
hold on;
plot(sequenceLength, xcorrAvgExecutionTime);
plot(sequenceLength, filterAvgExecutionTime);
box on;
grid on;
title('Execution Time Comparison')
legend('xcorr','filter');
xlabel('Sequence Length');
ylabel('Execution Time (s)')

% Plot speedup
figure(2);
clf;
hold on;
plot(sequenceLength, speedup);
box on;
grid on;
title('Speedup from ''filter'' Command')
xlabel('Sequence Length');
ylabel('Speedup')