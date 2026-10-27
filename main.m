%% ================================================================
%  MAIN - Neural-Network-Guided Variable Step-Size FxLMS
%  ================================================================
%  Runs the full pipeline:
%    1. Generate training environment
%    2. Baseline FxLMS runs (fixed small mu, fixed large mu)
%    3. Build oracle dataset (multi-step lookahead)
%    4. Train the step-size network
%    5. Deploy the network on a FRESH (held-out) environment
%    6. Save the 4 report graphs to results/
%
%  Just open this file in MATLAB and press Run, or type `main` in the
%  command window from this folder.

clear; clc; close all;

%% ---- Parameters (tweak these first if something needs adjusting) ----
fs            = 8000;      % sample rate (Hz)
duration      = 2.0;       % seconds - longer than before, so there's room
                            % for a mid-run change AND a re-convergence
M             = 10;        % adaptive filter length
mu_small      = 0.005;     % fixed baseline: slow, stable
mu_large      = 0.05;      % fixed baseline: fast - RUN mu_sweep.m FIRST and
                            % replace this with a value just below where
                            % instability actually starts. 0.05 tested
                            % stable in the last run, which is why it tied
                            % the network instead of losing to it.
candidate_mus = [0.002 0.005 0.01 0.02 0.035 0.05 0.08 0.12];
lookahead     = 20;        % widened from 10 - more averaging, cleaner labels
err_win       = 15;        % window (samples) for the smoothed-error feature -
                            % this is what lets the network tell "just after
                            % a change, still transient" apart from steady
                            % state, which a single noisy sample can't do
hidden_size   = 8;         % NN hidden neurons - keep small (real-time budget)
change_point  = 0.5;       % fraction through the signal where the primary acoustic path
                            % abruptly changes - this is what
                            % gives variable step-size something real to do

%% ---- Step 1-2: baselines on the TRAINING environment ----
fprintf('--- Step 1-2: generating signals and baseline FxLMS runs ---\n');
sig_train = generate_signals(fs, duration, 1, change_point);   % fixed seed

res_small_train = run_fxlms(sig_train, M, mu_small);
res_large_train = run_fxlms(sig_train, M, mu_large);

%% ---- Step 3: oracle dataset ----
fprintf('\n--- Step 3: building oracle training dataset ---\n');
tic;
data = generate_oracle_dataset(sig_train, M, candidate_mus, lookahead, err_win);
fprintf('Oracle dataset built: %d examples (%.1f s)\n', size(data.X,1), toc);

%% ---- Step 4: train the network ----
fprintf('\n--- Step 4: training the step-size network ---\n');
model = train_mu_network(data, hidden_size);
fprintf('\n');

%% ---- Step 5: deploy on a FRESH environment (held-out noise realization test) ----
fprintf('--- Step 5: deploying on a held-out test environment ---\n');
sig_test = generate_signals(fs, duration, 2, change_point);   % different seed,
                                                                 % SAME change_point
                                                                 % so both baselines
                                                                 % and the NN face
                                                                 % the same challenge

res_small_test = run_fxlms(sig_test, M, mu_small);
res_large_test = run_fxlms(sig_test, M, mu_large);
res_nn_test    = run_fxlms_nn(sig_test, M, model);

% Evaluate the SAME samples for all methods and compare to uncancelled noise.
% NR (dB) = 10*log10(E[d^2]/E[e^2]); positive values mean reduction.
start_idx = M;
cp = sig_test.P{3};
segments = {start_idx:sig_test.N, start_idx:cp, (cp+1):sig_test.N, ...
            max(start_idx,sig_test.N-799):sig_test.N};
segment_names = {'Full run','Before change','After change','Last 800 samples'};
methods = {'Fixed small','Fixed large','NN-guided'};
all_res = {res_small_test,res_large_test,res_nn_test};
NR = zeros(3,numel(segments));
MSE_dB = zeros(3,numel(segments));
for j = 1:numel(segments)
    idx = segments{j};
    original_power = mean(sig_test.d(idx).^2);
    for k = 1:3
        residual_power = mean(all_res{k}.e(idx).^2);
        NR(k,j) = 10*log10((original_power+eps)/(residual_power+eps));
        MSE_dB(k,j) = 10*log10(residual_power+eps);
    end
end
fprintf('\nNOISE REDUCTION (dB, higher is better):\n');
fprintf('%-14s %12s %12s %12s %12s\n','Method',segment_names{:});
for k = 1:3
    fprintf('%-14s %12.2f %12.2f %12.2f %12.2f\n',methods{k},NR(k,:));
end
fprintf('\nNote: This is a synthetic, perfectly known secondary-path simulation.\n');
if ~exist('results','dir'), mkdir('results'); end
fid = fopen(fullfile('results','metrics.csv'),'w');
fprintf(fid,'Method,FullRunNR_dB,BeforeChangeNR_dB,AfterChangeNR_dB,Last800NR_dB,FullRunMSE_dB,BeforeChangeMSE_dB,AfterChangeMSE_dB,Last800MSE_dB\n');
for k=1:3
    fprintf(fid,'%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n',methods{k},NR(k,:),MSE_dB(k,:));
end
fclose(fid);
save(fullfile('results','experiment.mat'),'model','NR','MSE_dB','sig_test', ...
     'res_small_test','res_large_test','res_nn_test', 'mu_small','mu_large');

%% ---- Step 6: plots ----
fprintf('\n--- Step 6: generating report figures ---\n');
plot_results(sig_test, res_small_test, res_large_test, res_nn_test, 'results');

fprintf('\nDone: results/ now includes 4 figures, metrics.csv and experiment.mat.\n');
