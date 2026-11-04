
%% WIND FARM CONTROLLER - FINAL 60 MINUTE RESULTS
% Project: 100 MW Grid-Connected Wind Farm Controller
% Scenario: Simulated wind availability, curtailment and recovery
%
% Generates:
% 1. Active power control overview
% 2. PCC active power tracking
% 3. Reactive power and PCC voltage
% 4. Ramp-rate verification
%
% All figures are saved automatically as PNG files.

clear; clc; close all;

%% 1. Project paths and logged data

scriptDir = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);

dataFile = fullfile(projectDir, 'results', 'Outputs', ...
    'WindPlant_60min_Final.mat');

plotDir = fullfile(projectDir, 'results', 'Plots');

if ~isfolder(plotDir)
    mkdir(plotDir);
end

if ~isfile(dataFile)
    error('Results file not found: %s', dataFile);
end

fprintf('\n=== WIND FARM SIMULATION RESULTS ===\n');

fileInfo = dir(dataFile);
fprintf('MAT-file size: %.2f MB\n', fileInfo.bytes/1e6);

S = load(dataFile);
L = S.logsout;

%% 2. Extract the nine logged signals

% Use the final command timestamps as the common time axis.
cmdSignal = L.get('Pcmd_MW').Values;
t = cmdSignal.Time(:);
Pcmd = cmdSignal.Data(:);

% All powers are expressed in MW / Mvar for plotting.
Pavailable = readLoggedSignal(L, 'Pavailable_MW', t);
Prequested = readLoggedSignal(L, 'Prequested_MW', t);
Pramp = readLoggedSignal(L, 'Pramp_MW', t);

Pcmd_pu = readLoggedSignal(L, 'Pcmd_pu', t);

Ppcc = readLoggedSignal(L, 'P_PCC_W', t) / 1e6;
Qpcc = readLoggedSignal(L, 'Q_PCC_var', t) / 1e6;

Vpcc = readLoggedSignal(L, 'Vpcc_pu', t);
Qcmd = readLoggedSignal(L, 'Qcmd_pu', t) * 100;

% Convert seconds to minutes.
tm = t / 60;

fprintf('Logged samples: %d\n', numel(t));
fprintf('Final simulation time: %.1f s (%.2f min)\n', ...
    t(end), t(end)/60);

if t(end) < 3599
    warning('The logged data does not reach 3600 seconds.');
end

%% 3. Basic performance calculations

% PCC active-power tracking error
Perror = Ppcc - Pcmd;
P_RMSE = sqrt(mean(Perror.^2));
P_MAE = mean(abs(Perror));
P_maxError = max(abs(Perror));

% Dispatch and availability constraints
availabilityExcess = max(Pcmd - Pavailable);
dispatchExcess = max(Pcmd - Pramp);

% Curtailment relative to available wind power
Pcurtailed = max(Pavailable - Pcmd, 0);
Ecurtailed_MWh = trapz(t, Pcurtailed) / 3600;

% One-second sampled average ramp rates (MW/min)
dt = diff(t);
valid = dt > 0;

rateDispatch = diff(Pramp);
rateCommand = diff(Pcmd);

rateDispatch = rateDispatch(valid) ./ dt(valid) * 60;
rateCommand = rateCommand(valid) ./ dt(valid) * 60;

tRate = tm(2:end);
tRate = tRate(valid);

rampLimit = 10;  % MW/min

upwardViolations = sum(rateCommand > rampLimit + 0.01);

fprintf('\n--- ACTIVE POWER PERFORMANCE ---\n');
fprintf('PCC tracking RMSE: %.4f MW\n', P_RMSE);
fprintf('PCC tracking MAE: %.4f MW\n', P_MAE);
fprintf('Maximum absolute tracking error: %.4f MW\n', ...
    P_maxError);
fprintf('Estimated curtailed energy: %.3f MWh\n', ...
    Ecurtailed_MWh);

fprintf('\n--- CONTROLLER CONSTRAINTS ---\n');
fprintf('Maximum availability exceedance: %.4f MW\n', ...
    availabilityExcess);
fprintf('Maximum dispatch exceedance: %.4f MW\n', ...
    dispatchExcess);
fprintf('Maximum command upward ramp: %.3f MW/min\n', ...
    max(rateCommand));
fprintf('Maximum command downward ramp: %.3f MW/min\n', ...
    min(rateCommand));
fprintf('Upward ramp violations: %d samples\n', ...
    upwardViolations);

fprintf('\n--- REACTIVE POWER AND VOLTAGE ---\n');
fprintf('PCC Q range: %.3f to %.3f Mvar\n', ...
    min(Qpcc), max(Qpcc));
fprintf('Q command range: %.3f to %.3f Mvar\n', ...
    min(Qcmd), max(Qcmd));
fprintf('PCC voltage range: %.4f to %.4f pu\n', ...
    min(Vpcc), max(Vpcc));

fprintf('\n--- POWER BASE CONSISTENCY ---\n');
fprintf('Maximum Pcmd per-unit conversion error: %.6g pu\n', ...
    max(abs(Pcmd_pu - Pcmd/100)));

%% 4. FIGURE 1 - Active power control overview

fig1 = figure('Name', 'Active Power Control', ...
    'Color', 'w', 'Position', [100 100 1200 570]);

plot(tm, Pavailable, 'Color', [0.15 0.55 0.25], ...
    'LineWidth', 1.6);
hold on;

stairs(tm, Prequested, '--', 'Color', [0.85 0.40 0.10], ...
    'LineWidth', 1.3);

plot(tm, Pramp, 'Color', [0.45 0.35 0.75], ...
    'LineWidth', 1.5);

plot(tm, Pcmd, 'Color', [0.05 0.35 0.80], ...
    'LineWidth', 2);

grid on;
xlim([0 60]);
ylim([0 105]);

xlabel('Simulation Time (min)');
ylabel('Active Power (MW)');

title('100 MW Wind Farm - Active Power Control', ...
    'FontWeight', 'bold');

subtitle('Wind Availability, Dispatch Curtailment and Ramp-Limited Recovery');

legend('Available Wind Power', ...
       'Requested Dispatch Power', ...
       'Ramp-Limited Dispatch', ...
       'Final Plant Power Command', ...
       'Location', 'best');

exportgraphics(fig1, fullfile(plotDir, ...
    '01_Active_Power_Control.png'), 'Resolution', 200);

%% 5. FIGURE 2 - PCC active power tracking

fig2 = figure('Name', 'PCC Active Power Tracking', ...
    'Color', 'w', 'Position', [120 120 1200 660]);

tiledlayout(2,1,'TileSpacing','compact');

nexttile;
plot(tm, Pcmd, '--', 'Color', [0.85 0.30 0.10], ...
    'LineWidth', 1.5);
hold on;
plot(tm, Ppcc, 'Color', [0.05 0.35 0.80], ...
    'LineWidth', 1.2);
grid on;
xlim([0 60]);
ylabel('Active Power (MW)');
title('Commanded vs Measured PCC Active Power');
legend('Final P Command', 'Measured PCC P', ...
    'Location', 'best');

nexttile;
plot(tm, Perror, 'Color', [0.40 0.30 0.70], ...
    'LineWidth', 1);
hold on;
yline(0, '--k');
grid on;
xlim([0 60]);
xlabel('Simulation Time (min)');
ylabel('PCC Tracking Error (MW)');
title(sprintf('PCC Power Tracking Error | RMSE = %.3f MW', ...
    P_RMSE));

sgtitle('100 MW Wind Farm - PCC Active Power Performance', ...
    'FontWeight', 'bold');

exportgraphics(fig2, fullfile(plotDir, ...
    '02_PCC_Active_Power_Tracking.png'), 'Resolution', 200);

%% 6. FIGURE 3 - Reactive power and PCC voltage

fig3 = figure('Name', 'Reactive Power and PCC Voltage', ...
    'Color', 'w', 'Position', [140 140 1200 760]);

tiledlayout(3,1,'TileSpacing','compact');

nexttile;
plot(tm, Qcmd, 'Color', [0.10 0.50 0.70], ...
    'LineWidth', 1.5);
grid on;
xlim([0 60]);
ylabel('Q Command (Mvar)');
title('Q(V) Controller - Reactive Power Command');

nexttile;
plot(tm, Qpcc, 'Color', [0.75 0.25 0.15], ...
    'LineWidth', 1.3);
grid on;
xlim([0 60]);
ylabel('PCC Q (Mvar)');
title('Measured PCC Reactive Power - Finite Grid Impedance');

nexttile;
plot(tm, Vpcc, 'Color', [0.20 0.50 0.30], ...
    'LineWidth', 1.3);
hold on;
yline(1.00, '--k', 'Nominal Voltage');
grid on;
xlim([0 60]);
xlabel('Simulation Time (min)');
ylabel('PCC Voltage (pu)');
title('PCC Voltage Response');

sgtitle('100 MW Wind Farm - Reactive Power and Voltage', ...
    'FontWeight', 'bold');

exportgraphics(fig3, fullfile(plotDir, ...
    '03_Reactive_Power_and_Voltage.png'), 'Resolution', 200);

%% 7. FIGURE 4 - Ramp-rate verification

fig4 = figure('Name', 'Ramp Rate Verification', ...
    'Color', 'w', 'Position', [160 160 1200 670]);

tiledlayout(2,1,'TileSpacing','compact');

nexttile;
plot(tRate, rateDispatch, 'Color', [0.45 0.35 0.75], ...
    'LineWidth', 1.3);
hold on;
yline(rampLimit, '--r', '+10 MW/min Limit');
yline(-rampLimit, '--r', '-10 MW/min Limit');
grid on;
xlim([0 60]);
ylabel('Ramp Rate (MW/min)');
title('Dispatch Rate Limiter Output');

nexttile;
plot(tRate, rateCommand, 'Color', [0.05 0.35 0.80], ...
    'LineWidth', 1.3);
hold on;
yline(rampLimit, '--r', '+10 MW/min Recovery Limit');
yline(0, ':k');
grid on;
xlim([0 60]);
xlabel('Simulation Time (min)');
ylabel('Ramp Rate (MW/min)');
title('Final Plant Power Command - Upward Recovery Limiting');

sgtitle('100 MW Wind Farm - Active Power Ramp-Rate Verification', ...
    'FontWeight', 'bold');

exportgraphics(fig4, fullfile(plotDir, ...
    '04_Ramp_Rate_Verification.png'), 'Resolution', 200);

%% 8. Finished

fprintf('\nAll four figures generated successfully.\n');
fprintf('Figures saved in:\n%s\n', plotDir);

%% Local helper function
function y = readLoggedSignal(L, signalName, t)

    element = L.get(signalName);

    if isempty(element)
        error('Missing logged signal: %s', signalName);
    end

    ts = element.Values;
    x = ts.Time(:);
    data = ts.Data(:);

    % Remove duplicate timestamps before interpolation.
    [x, idx] = unique(x, 'last');
    data = data(idx);

    if numel(x) == 1
        y = repmat(data, size(t));
    else
        y = interp1(x, data, t, 'linear', 'extrap');
    end
end
