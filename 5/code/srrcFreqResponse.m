% Mode flag ('compare','standalone')
mode = 'standalone';

% Symbol period
% Results appear independent of this value
% Some weirdness when Ts can't be exactly represented as float (ex: Ts=0.1).
Ts = 1;

% Choices of beta
beta = [0, 0.1, 0.25, 0.5, 1];

% Time values
% Limit to same number of samples as MATLAB built-in
t = (-5*Ts):Ts/8:(5*Ts);

% Loop for each value of beta
for i = 1:length(beta)

    % Allocate empty array for filter data
    h = zeros(size(t));

    % Loop for each time instance
    for j = 1:length(t)

        % Create filter
        if t(j) == 0
            h(j) = 1/sqrt(Ts)*(1-beta(i)+4*beta(i)/pi);
        elseif abs(t(j)) == (Ts/(4*beta(i)))
            h(j) = beta(i)/sqrt(2*Ts)*((1+2/pi)*sin(pi/(4*beta(i))) + ...
                (1-2/pi)*cos(pi/(4*beta(i))));
        else
            h(j) = 1/sqrt(Ts)*(sin(pi*t(j)/Ts*(1-beta(i))) + ...
                4*beta(i)*t(j)/Ts*cos(pi*t(j)/Ts*(1+beta(i)))) / ...
                (pi*t(j)/Ts*(1-(4*beta(i)*t(j)/Ts)^2));
        end
    end

    % Create figure
    figure(i); clf;    
    sgtitle(sprintf('Frequency Response for \\beta = %.1f', beta(i)),...
        'FontSize',12,'FontWeight','bold');
    hold on;

    % Plot frequency response
    freqz(h);

    % Plot time-domain samples
    figure(i+10); clf;
    plot(h);
    title(sprintf('Impulse Response for \\beta = %.1f', beta(i)));

    % Compare to MATLAB's built-in routine
    if strcmp(mode,'compare')

        % Plot on top of existing data
        figure(i);
        subplot(2,1,1);
        hold on;
        subplot(2,1,2);
        hold on;

        % MATLAB creates filter with unit energy
        % Scale to match formulas from class
        gain = sqrt(sum(abs(h).^2));

        txFilter = comm.RaisedCosineTransmitFilter(...
            'RolloffFactor',beta(i),...
            'Gain',gain);
        h = coeffs(txFilter);
        freqz(h.Numerator);
    end
end