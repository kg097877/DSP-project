function model = train_mu_network(data, hidden_size)
% TRAIN_MU_NETWORK  Trains a small feedforward network to predict the
% oracle step size from causal features.
%
%   model = train_mu_network(data, hidden_size)
%
%   data.X, data.Y - from generate_oracle_dataset()
%   hidden_size     - number of hidden neurons (default 8 - keep it SMALL,
%                      this has to run in real time eventually)
%
%   model.net  - trained network
%   model.muX  - feature means (for normalizing new inputs at inference)
%   model.sigX - feature std devs
%   model.r2   - training R^2 - CHECK THIS before trusting the network.
%                Near 0 or negative means it hasn't learned anything real.

    if nargin < 2
        hidden_size = 8;
    end

    X = data.X;
    Y = data.Y;

    % Chronological split: hold out the final 20%% for evaluation.
    % Normalize ONLY using training examples to prevent data leakage.
    n = size(X,1);
    nTrain = floor(0.70*n);
    nVal = floor(0.10*n);
    idxTrain = 1:nTrain;
    idxVal = (nTrain+1):(nTrain+nVal);
    idxTest = (nTrain+nVal+1):n;
    muX = mean(X(idxTrain,:),1);
    sigX = std(X(idxTrain,:),0,1);
    sigX(sigX < 1e-12) = 1;
    Xn = (X - muX) ./ sigX;

    net = feedforwardnet(hidden_size);
    net.trainParam.showWindow = false;
    net.divideFcn = 'divideind';
    net.divideParam.trainInd = idxTrain;
    net.divideParam.valInd = idxVal;
    net.divideParam.testInd = idxTest;
    net = train(net, Xn', Y');
    pred = net(Xn')';
    r2 = local_r2(Y(idxTrain), pred(idxTrain));
    r2_test = local_r2(Y(idxTest), pred(idxTest));
    fprintf('Oracle-label fit R^2 (training partition): %.3f\n', r2);
    fprintf('Oracle-label R^2 (chronological held-out partition): %.3f\n', r2_test);
    fprintf('IMPORTANT: R^2 evaluates step-size labels, not actual ANC quality.\n');
    fprintf('Use held-out noise reduction (dB) as the primary result.\n');

    r2_high = NaN;
    if isfield(data,'spread')
        thresh = prctile(data.spread(idxTest),75);
        highIdx = idxTest(data.spread(idxTest) >= thresh);
        r2_high = local_r2(Y(highIdx), pred(highIdx));
        fprintf('Held-out high-spread oracle-label R^2: %.3f\n',r2_high);
    end

    model.net = net;
    model.muX = muX;
    model.sigX = sigX;
    model.r2 = r2;
    model.r2_test = r2_test;
    model.r2_high_spread = r2_high;
    model.mu_min = min(data.candidate_mus);
    model.mu_max = max(data.candidate_mus);
    if isfield(data, 'err_win')
        model.err_win = data.err_win;
    else
        model.err_win = 15;
    end
end

function r = local_r2(y, pred)
    denom = sum((y - mean(y)).^2);
    if denom < 1e-12
        r = NaN;
    else
        r = 1 - sum((y-pred).^2)/denom;
    end
end
