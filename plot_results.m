function plot_results(sig_test, res_small, res_large, res_nn, out_dir)
% PLOT_RESULTS  Produces the four graphs your abstract promises:
%   1. Error vs Iteration (fixed-small vs fixed-large vs NN)
%   2. mu(n) vs Iteration
%   3. Fixed vs ML final-error bar comparison
%   4. Signal before/after (reference, desired, filtered output)
%
%   plot_results(sig_test, res_small, res_large, res_nn, out_dir)
%
%   Saves each figure as a PNG into out_dir (created if it doesn't exist).

    if nargin < 5
        out_dir = 'results';
    end
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    win = 50;
    db_small = 10*log10(movmean(res_small.e.^2, win) + 1e-12);
    db_large = 10*log10(movmean(res_large.e.^2, win) + 1e-12);
    db_nn    = 10*log10(movmean(res_nn.e.^2, win) + 1e-12);

    % ---- Fig 1: Error vs Iteration ----
    f1 = figure('Visible','off');
    plot(10*log10(movmean(sig_test.d.^2,win)+1e-12), 'k--', 'LineWidth',1); hold on;
    plot(db_large, 'Color',[0.6 0.6 0.6]); hold on;
    plot(db_small, 'Color',[0.61 0.77 0.9]);
    plot(db_nn,    'Color',[0.12 0.31 0.47], 'LineWidth',1.6);
    if iscell(sig_test.P)
        xline(sig_test.P{3}, '--', 'Primary acoustic path changes', 'Color',[0.8 0.2 0.2]);
    end
    legend('No cancellation','Fixed \mu (large)','Fixed \mu (small)','NN-guided \mu','Location','northeast');
    xlabel('Iteration'); ylabel('Smoothed error power (dB)');
    title('Fig. 1 - Error vs Iteration'); grid on;
    saveas(f1, fullfile(out_dir,'fig1_error_vs_iteration.png'));

    % ---- Fig 2: mu(n) vs Iteration ----
    f2 = figure('Visible','off');
    % Ignore initialization samples that do not have an NN prediction.
    M = find(isfinite(res_nn.mu_trace), 1, 'first');
    if isempty(M), M = 1; end
    plot(M:length(res_nn.mu_trace), res_nn.mu_trace(M:end), 'Color',[0.77 0.35 0.07]);
    xlim([1 length(res_nn.mu_trace)]);
    mu_visible = res_nn.mu_trace(M:end);
    ymax = max(mu_visible);
    if ~isempty(ymax) && isfinite(ymax) && ymax > 0
        ylim([0 max(0.01, 1.15*ymax)]);
    end
    xlabel('Iteration'); ylabel('\mu(n)');
    title('Fig. 2 - NN-Predicted Step Size vs Iteration'); grid on;
    saveas(f2, fullfile(out_dir,'fig2_mu_vs_iteration.png'));

    % ---- Fig 3: Fixed vs ML comparison (bar chart of tail-end MSE) ----
    % Last 800 samples: same steady-state window as metrics.csv.
    tail = max(1, length(db_small)-799):length(db_small);
    final_vals = [10*log10(mean(res_large.e(tail).^2)+1e-12), ...
                  10*log10(mean(res_small.e(tail).^2)+1e-12), ...
                  10*log10(mean(res_nn.e(tail).^2)+1e-12)];
    f3 = figure('Visible','off');
    bar(final_vals, 'FaceColor',[0.3 0.5 0.7]);
    set(gca,'XTickLabel',{'Fixed \mu (large)','Fixed \mu (small)','NN-guided \mu'});
    ylabel('Mean squared residual error (dB)');
    title('Fig. 3 - Last 800 Samples: MSE Comparison'); grid on;
    saveas(f3, fullfile(out_dir,'fig3_mse_comparison.png'));

    % ---- Fig 4: Signal before/after ----
    n_show = min(2000, sig_test.N);
    f4 = figure('Visible','off');
    subplot(3,1,1); plot(sig_test.x(1:n_show)); title('Reference x(n)');
    subplot(3,1,2); plot(sig_test.d(1:n_show)); title('Desired: noise at error mic d(n)');
    subplot(3,1,3); plot(res_nn.e(1:n_show));    title('Residual error: NN-guided FxLMS e(n)');
    xlabel('Sample');
    saveas(f4, fullfile(out_dir,'fig4_waveforms.png'));

    fprintf('Saved 4 figures to %s/\n', out_dir);
end
