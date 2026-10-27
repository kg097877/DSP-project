%% Deterministic numerical and structural checks (no NN toolbox required)
% Run: verify_code
clear; clc;
fs=1000; M=5; sig=generate_signals(fs,0.5,123,0.5);
r0=run_fxlms(sig,M,0);
assert(max(abs(r0.e-sig.d)) < 1e-11,'Zero-gain identity failed');
assert(max(abs(r0.y)) < 1e-11,'Zero-gain produced output');
mu=0.035; r=run_fxlms(sig,M,mu);
assert(all(isfinite(r.e)) && all(isfinite(r.w)),'Numerical divergence');
assert(max(abs(r.y_sec-filter(sig.S,1,r.y))) < 1e-10, 'Secondary path filtering mismatch');
assert(max(abs(r.e-(sig.d-r.y_sec)))<1e-10, 'Residual identity failed');
assert(max(abs(sig.xf-filter(sig.S,1,sig.x)))<1e-10, 'Filtered reference mismatch');
% An independent, explicit-loop implementation tests time indexing and signs.
w=zeros(1,M); yy=zeros(1,sig.N); ee=sig.d;
for n=M:sig.N
    for j=1:M
        yy(n)=yy(n)+w(j)*sig.x(n-j+1);
    end
    anti=0;
    for k=1:numel(sig.S)
        if n-k+1>=1, anti=anti+sig.S(k)*yy(n-k+1); end
    end
    ee(n)=sig.d(n)-anti;
    for j=1:M
        w(j)=w(j)+mu*ee(n)*sig.xf(n-j+1);
    end
end
assert(max(abs(ee-r.e))<1e-10,'Independent reference residual mismatch');
assert(max(abs(w-r.w))<1e-10,'Independent reference coefficients mismatch');
% Causality: modifications in the future must not change earlier samples.
sig2=sig; k=round(sig.N*0.7);
sig2.x(k:end)=sig2.x(k:end)*2.0;
sig2.xf=filter(sig.S,1,sig2.x);
if iscell(sig.P)
    p1=sig.P{1}; p2=sig.P{2}; cp=sig.P{3};
    aa=filter(p1,1,sig2.x); bb=filter(p2,1,sig2.x);
    sig2.d=[aa(1:cp) bb(cp+1:end)];
else
    sig2.d=filter(sig.P,1,sig2.x);
end
r2=run_fxlms(sig2,M,mu);
assert(max(abs(r.e(1:k-1)-r2.e(1:k-1)))<1e-10,'Future leakage detected');
fprintf('PASS: 7 deterministic FxLMS checks.\n');
% Optional inference checks: use a mock constant NN when supported.
model=struct('net',@(z) 0.035,'muX',zeros(1,4),'sigX',ones(1,4), ...
             'mu_min',0.002,'mu_max',0.12,'err_win',15);
rnn=run_fxlms_nn(sig,M,model);
assert(max(abs(rnn.e-r.e))<1e-10,'NN fixed-output equivalence failed');
assert(all(isnan(rnn.mu_trace(1:M-1))),'Warm-up step sizes should be NaN');
assert(all(abs(rnn.mu_trace(M:end)-mu)<1e-12),'Step-size trace incorrect');
fprintf('PASS: 3 NN integration checks. TOTAL: 10 PASS.\n');
