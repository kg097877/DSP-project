%% BENCHMARK_QUICK - untuned test set, tuned fixed controller, independent seeds
% First run main.m, then benchmark_quick. MATLAB + Deep Learning Toolbox.
% Quick diagnostic: 2 validation seeds and 3 test seeds.
% Lower statistical confidence than benchmark_fair; do not claim general superiority.
% DO NOT tune on the evaluation seeds or change seeds after seeing results.
assert(exist('results/experiment.mat','file')==2, 'Run main.m first');
load('results/experiment.mat','model');
M=10; fs=8000; duration=1; cp_frac=0.5;
mu_candidates=[0.002 0.005 0.01 0.02 0.035 0.05 0.08 0.12];
validation_seeds=11:12; test_seeds=101:103;
% Optimize fixed baseline on VALIDATION seeds, never test seeds.
val_score=zeros(numel(mu_candidates),numel(validation_seeds));
for a=1:numel(mu_candidates)
    for b=1:numel(validation_seeds)
        s=generate_signals(fs,duration,validation_seeds(b),cp_frac);
        r=run_fxlms(s,M,mu_candidates(a));
        idx=max(M,s.N-799):s.N;
        val_score(a,b)=10*log10((mean(s.d(idx).^2)+eps)/(mean(r.e(idx).^2)+eps));
    end
end
[~,best_idx]=max(mean(val_score,2)); mu_best=mu_candidates(best_idx);
fprintf('Validation-selected fixed mu: %.4f\n',mu_best);
% Pre-register the analysis window: last 800 samples AFTER path change.
NR_fixed=zeros(numel(test_seeds),1); NR_nn=NR_fixed;
NR_small=NR_fixed; RT_fixed=NR_fixed; RT_nn=NR_fixed;
for q=1:numel(test_seeds)
    s=generate_signals(fs,duration,test_seeds(q),cp_frac);
    a=run_fxlms(s,M,mu_best); b=run_fxlms_nn(s,M,model);
    c=run_fxlms(s,M,0.005);
    tail=(s.N-799):s.N;
    fprintf('Completed test seed %d (%d/%d)\n',test_seeds(q),q,numel(test_seeds));
    NR_fixed(q)=nrdb(s.d,a.e,tail);
    NR_nn(q)=nrdb(s.d,b.e,tail);
    NR_small(q)=nrdb(s.d,c.e,tail);
    post=(s.P{3}+1):s.N;
    RT_fixed(q)=nrdb(s.d,a.e,post);
    RT_nn(q)=nrdb(s.d,b.e,post);
end
D=NR_nn-NR_fixed; D_post=RT_nn-RT_fixed;
T=table(test_seeds(:),NR_fixed,NR_nn,D,NR_small,RT_fixed,RT_nn,D_post, ...
  'VariableNames',{'Seed','FixedBestTailNR_dB','NN_TailNR_dB','NNminusFixedTail_dB', ...
  'FixedSmallTailNR_dB','FixedBestPostNR_dB','NN_PostNR_dB','NNminusFixedPost_dB'});
if ~exist('results','dir'), mkdir('results'); end
writetable(T,fullfile('results','quick_benchmark.csv'));
fprintf('Held-out tail NR, fixed %.3f dB | NN %.3f dB | delta %.3f dB\n', ...
    mean(NR_fixed),mean(NR_nn),mean(D));
fprintf('Held-out after-change NR delta %.3f dB; NN wins %d/%d seeds\n', ...
    mean(D_post),sum(D>0),numel(D));
figure('Visible','off');
bar([mean(NR_small),mean(NR_fixed),mean(NR_nn)]);
set(gca,'XTickLabel',{'Fixed small','Fixed tuned (val)','NN-guided'});
ylabel('Mean tail noise reduction (dB)');
title('Independent Test Seeds: Fair Fixed vs NN'); grid on;
saveas(gcf,fullfile('results','fig5_quick_benchmark.png'));
if mean(D)>0
    fprintf('NN improves mean tail NR over tuned fixed baseline by %.3f dB.\n',mean(D));
else
    fprintf('NO demonstrated average tail-NR improvement over tuned fixed baseline.\n');
end
function val=nrdb(d,e,idx)
 val=10*log10((mean(d(idx).^2)+eps)/(mean(e(idx).^2)+eps));
end