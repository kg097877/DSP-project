function res = run_fxlms_nn(sig,M,model)
% NN selects bounded mu from features at n; weights update only AFTER e(n).
assert(M <= sig.N,'Filter length exceeds signal length');
assert(isfield(model,'net') && isfield(model,'muX') && isfield(model,'sigX'));
assert(model.mu_min>=0 && model.mu_max>=model.mu_min);
x=sig.x; xf=sig.xf; d=sig.d; S=sig.S; N=sig.N; Sl=numel(S);
w=zeros(1,M); y=zeros(1,N); ys=zeros(1,N); e=d;
mu_trace=nan(1,N); e_prev=0;
if isfield(model,'err_win'), ew=model.err_win; else, ew=15; end
for n=M:N
    xv=x(n:-1:n-M+1); xfv=xf(n:-1:n-M+1);
    y(n)=w*xv'; L=min(Sl,n);
    ys(n)=S(1:L)*y(n:-1:n-L+1)';
    e(n)=d(n)-ys(n);
    feature=[e(n),e_prev,x(n)^2,mean(e(max(1,n-ew+1):n).^2)];
    f=(feature-model.muX)./model.sigX;
    predicted=double(model.net(f'));
    predicted=predicted(1);
    if ~isfinite(predicted), error('Nonfinite NN prediction at sample %d',n); end
    mu=min(max(predicted,model.mu_min),model.mu_max);
    mu_trace(n)=mu;
    w=w+mu*e(n)*xfv;
    e_prev=e(n);
end
res=struct('e',e,'y',y,'y_sec',ys,'mu_trace',mu_trace,'w',w);
end
