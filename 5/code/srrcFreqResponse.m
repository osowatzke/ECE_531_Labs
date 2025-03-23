% Mode flag ('compare','standalone')
mode = 'compare';

% Symbol period
Ts = 0.25;

% Choices of beta
beta = [0, 0.1, 0.25, 0.5, 1];

% Time values
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

    % Plot frequency response
    freqz(h);
    subplot(2,1,1);
    hold on;
    subplot(2,1,2);
    hold on;

    % Compare to MATLAB's built-in routine
    if strcmp(mode,'compare')

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