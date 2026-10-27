function data = generate_oracle_dataset(sig, M, candidate_mus, lookahead, err_win)
% GENERATE_ORACLE_DATASET  Builds (features -> optimal mu) training pairs.
%
%   data = generate_oracle_dataset(sig, M, candidate_mus, lookahead, err_win)
%
%   At every iteration, each candidate mu is tried and its error ENERGY
%   over the next `lookahead` samples is measured (not just one step -
%   single-step lookahead is too noisy to learn from; this was verified
%   empirically: R^2 was -0.81 with a single step vs. a real positive R^2
%   once averaged over a short window).
%
%   Features are strictly causal: [e(n), e(n-1), x(n)^2, smoothed_energy]
%   where smoothed_energy is a moving average of e(.)^2 over the last
%   `err_win` samples - this is what actually lets the network tell a
%   transient (just after start, or just after a noise-profile change)
%   apart from steady state, which a single noisy instantaneous sample
%   can't do reliably.
%
%   data.X      - [n_examples x 4] feature matrix
%   data.Y      - [n_examples x 1] oracle mu labels
%   data.spread - [n_examples x 1] max-minus-min candidate energy at that
%                 step - a DIAGNOSTIC field (not a network input). High
%                 spread = the mu choice genuinely mattered here; low
%                 spread = every candidate performed about the same, so
%                 the label is close to arbitrary. Use this to check R^2
%                 on the examples that actually matter (see train_mu_network).
%   data.iter   - [n_examples x 1] the sample index n for each row, for
%                 plotting/inspection.
%
%   NOTE ON RUNTIME: this is O(N * candidates * lookahead). If it feels
%   slow, shorten sig.duration when you call generate_signals(), or
%   reduce lookahead / the candidate list.

    if nargin < 5
        err_win = 15;
    end

    x = sig.x; xf = sig.xf; d = sig.d; S = sig.S; Sl = sig.Sl; N = sig.N;
    n_candidates = length(candidate_mus);

    w = zeros(1,M);
    y = zeros(1,N);
    y_sec = zeros(1,N);
    e_trace = d; % Before adaptation, residual equals original disturbance. History for
                                    % smoothed-energy feature below

    X_data = zeros(N, 4);
    Y_data = zeros(N, 1);
    spread_data = zeros(N, 1);
    iter_data = zeros(N, 1);
    row = 0;
    e_prev = 0;

    for n = M:(N - lookahead - 1)
        x_vec  = x(n:-1:n-M+1);
        xf_vec = xf(n:-1:n-M+1);

        y(n) = w * x_vec';
        s_idx = min(Sl, n);
        y_sec(n) = S(1:s_idx) * y(n:-1:n-s_idx+1)';
        e_n = d(n) - y_sec(n);
        e_trace(n) = e_n;

        win_start = max(1, n - err_win + 1);
        smoothed_energy = mean(e_trace(win_start:n).^2);

        best_mu = candidate_mus(1);
        best_energy = Inf;
        all_energies = zeros(1, n_candidates);

        for c = 1:n_candidates
            mu_c = candidate_mus(c);
            w_try = w + mu_c * e_n * xf_vec;
            y_try = y;
            y_sec_try = y_sec;
            energy = 0;

            for k = 1:lookahead
                idx = n + k;
                x_vec_k  = x(idx:-1:idx-M+1);
                xf_vec_k = xf(idx:-1:idx-M+1);

                y_try(idx) = w_try * x_vec_k';
                s_idx_k = min(Sl, idx);
                y_sec_try(idx) = S(1:s_idx_k) * y_try(idx:-1:idx-s_idx_k+1)';
                e_k = d(idx) - y_sec_try(idx);

                energy = energy + e_k^2;
                w_try = w_try + mu_c * e_k * xf_vec_k;
            end

            all_energies(c) = energy;
            if energy < best_energy
                best_energy = energy;
                best_mu = mu_c;
            end
        end

        row = row + 1;
        X_data(row,:) = [e_n, e_prev, x(n)^2, smoothed_energy];
        Y_data(row)   = best_mu;
        spread_data(row) = max(all_energies) - min(all_energies);
        iter_data(row) = n;

        w = w + best_mu * e_n * xf_vec;
        e_prev = e_n;
    end

    data.X = X_data(1:row,:);
    data.Y = Y_data(1:row);
    data.spread = spread_data(1:row);
    data.iter = iter_data(1:row);
    data.candidate_mus = candidate_mus;
    data.err_win = err_win;
end
