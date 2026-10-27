function sig = generate_signals(fs, duration, seed, change_point)
% GENERATE_SIGNALS  Builds the reference signal and the two acoustic paths
% used throughout the project.
%
%   sig = generate_signals(fs, duration, seed, change_point)
%
%   sig.x   - reference signal (what the reference mic picks up)
%   sig.d   - noise arriving at the error mic via the primary path P(z)
%   sig.xf  - reference filtered through the secondary path S(z)
%             (this is the "Fx" in FxLMS - used ONLY in the weight update)
%   sig.S   - secondary path impulse response
%   sig.P   - primary path impulse response (may switch partway - see below)
%
%   change_point (optional, 0-1): fraction of the way through the signal
%   where the primary path abruptly changes to a different profile - this
%   simulates the real-world case of noise characteristics shifting (e.g.
%   engine RPM change, a door opening). Pass [] or omit for a stationary
%   signal. THIS IS WHAT MAKES VARIABLE STEP-SIZE ACTUALLY MATTER: with a
%   stationary environment, one well-chosen fixed mu can match an adaptive
%   one for the whole run (as you likely just saw) - the real advantage
%   only shows up when the filter has to re-converge after a change.
%
%   A pure white-noise reference converges almost instantly regardless of
%   mu, which hides the whole point of this project - so x(n) here is
%   broadband but NOT identical each call unless you fix the seed.

    if nargin < 3
        seed = 'shuffle';
    end
    if nargin < 4
        change_point = [];
    end
    rng(seed);

    N = round(fs * duration);
    t = (0:N-1)/fs;

    v = 0.5*randn(1,N);                 % broadband noise source
    P1 = [0.6 0.35 -0.25 0.15 -0.08];   % primary path, first half
    P2 = [0.3 -0.5 0.4 -0.2 0.1];       % primary path AFTER the change - a
                                          % genuinely different profile, not
                                          % just a scaled version of P1
    S = [0.5 0.25 -0.1];                % secondary path: cancel speaker -> error mic

    x  = v;
    xf = filter(S,1,x);

    if isempty(change_point)
        d = filter(P1,1,x);
        P = P1;
    else
        cp = round(change_point * N);
        d = zeros(1,N);
        d1 = filter(P1,1,x);
        d2 = filter(P2,1,x);
        d(1:cp)     = d1(1:cp);
        d(cp+1:end) = d2(cp+1:end);
        P = {P1, P2, cp};   % keep both for reference/plots
    end

    sig.fs = fs;
    sig.t  = t;
    sig.N  = N;
    sig.x  = x;
    sig.d  = d;
    sig.xf = xf;
    sig.S  = S;
    sig.P  = P;
    sig.Sl = length(S);
end

