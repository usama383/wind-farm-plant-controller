%% Refine final wind-farm verification: curtailment breakdown and ramp figure
% Run from any MATLAB current folder. Keep this script in the project scripts/ folder.
% No Simulink rerun required. Input profile is hypothetical (not measured SCADA).
clearvars; close all; clc;

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
matFile = fullfile(projectRoot,'results','Outputs','WindPlant_60min_Final.mat');
plotDir = fullfile(projectRoot,'results','Plots');
if ~isfile(matFile)
    error('MAT-file not found: %s\nPlace this script in <project>/scripts/.', matFile);
end
if ~isfolder(plotDir), mkdir(plotDir); end

S = load(matFile,'logsout');
L = S.logsout;
names = {'Pavailable_MW','Prequested_MW','Pramp_MW','Pcmd_MW'};
raw = cell(1,numel(names));
for k = 1:numel(names)
    try
        raw{k} = L.get(names{k}).Values;
    catch
        error('Missing logged signal: %s',names{k});
    end
end

% Interpolate to common 1-s time grid, using last sample for duplicates.
t0 = max(cellfun(@(x)double(x.Time(1)),raw));
t1 = min(cellfun(@(x)double(x.Time(end)),raw));
t = (ceil(t0):floor(t1))';
if numel(t)<2, error('Too few common recorded timestamps.'); end
P = cell(1,numel(raw));
for k = 1:numel(raw)
    tk = double(raw{k}.Time(:));
    yk = double(raw{k}.Data(:));
    [tk, idx] = unique(tk,'last');
    yk = yk(idx);
    P{k} = interp1(tk,yk,t,'linear');
end
Pavailable = P{1}; Prequested = P{2}; Pramp = P{3}; Pcmd = P{4};
Ptarget = min(Pavailable,Pramp);

% Clear definitions for energy NOT generated relative to the model's
% synthetic available-power profile. This is NOT measured redispatch energy.
dispatchReductionMW = max(Pavailable-Ptarget,0);
recoveryReductionMW = max(Ptarget-Pcmd,0);
totalReductionMW = max(Pavailable-Pcmd,0);
E_dispatch = trapz(t,dispatchReductionMW)/3600;
E_recovery = trapz(t,recoveryReductionMW)/3600;
E_total = trapz(t,totalReductionMW)/3600;
E_available = trapz(t,Pavailable)/3600;
E_commanded = trapz(t,Pcmd)/3600;
closureError = E_total - E_dispatch - E_recovery;

fprintf('\n=== CURTAILMENT / UNPRODUCED ENERGY BREAKDOWN ===\n');
fprintf('Available energy (simulated):      %.3f MWh\n',E_available);
fprintf('Commanded energy:                 %.3f MWh\n',E_commanded);
fprintf('Dispatch-constraint reduction:    %.3f MWh\n',E_dispatch);
fprintf('Recovery ramp additional loss:    %.3f MWh\n',E_recovery);
fprintf('Total not-produced energy:        %.3f MWh\n',E_total);
fprintf('Energy accounting closure error:  %.6f MWh\n',closureError);
assert(abs(closureError)<1e-4,'Energy breakdown is inconsistent; inspect logged signals.');
assert(max(Pcmd-Pavailable)<1e-3,'Final command exceeds availability in logged data.');
assert(max(Pcmd-Pramp)<1e-3,'Final command exceeds dispatch rate limiter in logged data.');

% Ramp derivatives are 1-second AVERAGES, not instantaneous waveform slopes.
tRate = t(2:end)/60;
rateDispatch = diff(Pramp)./diff(t)*60;
rateFinal = diff(Pcmd)./diff(t)*60;
rateFinalRise = max(rateFinal,0);

fig4=figure('Color','w','Position',[90 80 1250 850], ...
    'Name','04 - Ramp-Rate and Outage-Recovery Verification');
tl=tiledlayout(fig4,3,1,'TileSpacing','compact','Padding','compact');
title(tl,'100 MW Wind Farm - Dispatch Ramp, Recovery and Availability Loss', ...
    'FontSize',16,'FontWeight','bold');

nexttile;
plot(tRate,rateDispatch,'Color',[0.35 0.25 0.70],'LineWidth',1.3); hold on;
yline(10,'--r','+10 MW/min','LabelHorizontalAlignment','left');
yline(-10,'--r','-10 MW/min','LabelHorizontalAlignment','left');
ylim([-12 12]); xlim([0 60]); grid on;
ylabel('MW/min');
title('Dispatch Reference Ramp Rate (1-s Average)');

nexttile;
plot(tRate,rateFinalRise,'Color',[0 0.38 0.82],'LineWidth',1.3); hold on;
yline(10,'--r','+10 MW/min limit','LabelHorizontalAlignment','left');
ylim([0 12]); xlim([0 60]); grid on;
ylabel('MW/min');
title('Final Power Command - Upward Ramp Compliance (1-s Average)');

nexttile;
plot(t/60,Pavailable,'Color',[0.10 0.55 0.25],'LineWidth',1.4); hold on;
plot(t/60,Pramp,'--','Color',[0.5 0.35 0.73],'LineWidth',1.1);
plot(t/60,Pcmd,'Color',[0 0.38 0.82],'LineWidth',1.8);
xlim([35 45]); ylim([50 102]); grid on;
ylabel('Power (MW)'); xlabel('Simulation time (min)');
title('Turbine-Group Availability Loss and Ramp-Limited Recovery (35-45 min)');
legend({'Available wind power','Ramp-limited dispatch','Final plant command'}, ...
       'Location','best','Box','off');
exportgraphics(fig4,fullfile(plotDir,'04_Ramp_Rate_Verification_Refined.png'),'Resolution',200);

fig5=figure('Color','w','Position',[130 100 1160 640], ...
    'Name','05 - Modelled Unproduced Energy');
a=area(t/60,[dispatchReductionMW,recoveryReductionMW], ...
    'LineStyle','none');
a(1).FaceColor=[0.82 0.47 0.15];
a(2).FaceColor=[0.28 0.52 0.83];
a(1).FaceAlpha=0.8; a(2).FaceAlpha=0.8;
grid on; xlim([0 60]); ylim([0 inf]);
xlabel('Simulation time (min)'); ylabel('Power not produced (MW)');
title(sprintf(['100 MW Wind Farm - Modelled Power Reduction | Total %.3f MWh\n' ...
    'Dispatch constraint %.3f MWh | Additional recovery ramp %.3f MWh'], ...
    E_total,E_dispatch,E_recovery));
legend({'Dispatch-constrained reduction','Additional recovery-ramp reduction'}, ...
    'Location','northwest','Box','off');
annotation(fig5,'textbox',[0.15 0.015 0.75 0.035], ...
    'String','Illustrative wind availability and dispatch profile - not measured operator curtailment', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',10);
exportgraphics(fig5,fullfile(plotDir,'05_Modelled_Energy_Reduction.png'),'Resolution',200);

metricsFile = fullfile(plotDir,'energy_breakdown.txt');
fid = fopen(metricsFile,'w');
if fid < 0, error('Cannot write %s',metricsFile); end
fprintf(fid,'100 MW WIND FARM - MODELLED ENERGY REDUCTION\n');
fprintf(fid,'Illustrative inputs; not historical measured curtailment.\n');
fprintf(fid,'Available energy: %.6f MWh\n',E_available);
fprintf(fid,'Commanded energy: %.6f MWh\n',E_commanded);
fprintf(fid,'Dispatch-constrained energy reduction: %.6f MWh\n',E_dispatch);
fprintf(fid,'Additional recovery-ramp energy reduction: %.6f MWh\n',E_recovery);
fprintf(fid,'Total not-produced energy: %.6f MWh\n',E_total);
fprintf(fid,'Energy closure error: %.9f MWh\n',closureError);
fprintf(fid,'Maximum dispatch upward ramp (1s average): %.6f MW/min\n',max(rateDispatch));
fprintf(fid,'Minimum dispatch ramp (1s average): %.6f MW/min\n',min(rateDispatch));
fprintf(fid,'Maximum final upward ramp (1s average): %.6f MW/min\n',max(rateFinal));
fprintf(fid,'Minimum final downward change (1s average; outage): %.6f MW/min\n',min(rateFinal));
fclose(fid);
fprintf('\nSaved updated figures and metrics in:\n%s\n',plotDir);
