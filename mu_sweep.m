%% MU_SWEEP - find where fixed-mu FxLMS actually becomes unstable
%  Run this once to pick a genuinely meaningful mu_large for main.m,
%  instead of guessing. Uses the same signal generator as the main project.

clear; clc;
fs = 8000; duration = 1.0; M = 10;

sig = generate_signals(fs, duration, 1);

mu_test_values = [0.005 0.01 0.02 0.035 0.05 0.08 0.12 0.16 0.20 0.25];
final_db = zeros(size(mu_test_values));

for i = 1:length(mu_test_values)
    res = run_fxlms(sig, M, mu_test_values(i));
    tail = max(1, sig.N-200):sig.N;
    final_db(i) = 10*log10(mean(res.e(tail).^2) + 1e-12);
    fprintf('mu = %.3f  ->  final smoothed error = %.2f dB\n', mu_test_values(i), final_db(i));
end

figure;
plot(mu_test_values, final_db, '-o');
xlabel('\mu'); ylabel('Final steady-state error (dB)');
title('Finding the instability point'); grid on;

fprintf('\nLook for where final_db starts INCREASING again (getting worse) -\n');
fprintf('that''s where instability kicks in. Pick mu_large just below that,\n');
fprintf('so it''s genuinely "fast but risky," not just fast and fine.\n');
