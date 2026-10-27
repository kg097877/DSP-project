function res = run_fxlms(sig,M,mu)
% Standard feedforward FxLMS using the exact secondary path.
% e(n)=d(n)-(S*y)(n); w(n+1)=w(n)+mu*e(n)*x_filtered(n).
validateattributes(M,{'numeric'},{'scalar','integer','positive'});
validateattributes(mu,{'numeric'},{'scalar','real','finite','nonnegative'});
assert(M <= sig.N, 'Filter length exceeds signal length');
x=sig.x; xf=sig.xf; d=sig.d; S=sig.S; N=sig.N; Sl=numel(S);
w=zeros(1,M); y=zeros(1,N); ys=zeros(1,N); e=d;
for n=M:N
    xv=x(n:-1:n-M+1);
    xfv=xf(n:-1:n-M+1);
    y(n)=w*xv';
    L=min(Sl,n);
    ys(n)=S(1:L)*y(n:-1:n-L+1)';
    e(n)=d(n)-ys(n);
    w=w+mu*e(n)*xfv;
end
res=struct('e',e,'y',y,'y_sec',ys,'w',w);
end
