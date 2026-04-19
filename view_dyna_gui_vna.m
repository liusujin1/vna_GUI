function view_dyna_gui_vna()
% GUI for vibration data (.vna/.mat/.txt/.dat/.csv/.xlsx)
% - load vibration file
% - plot time-domain signal
% - plot frequency-domain spectrum
% - apply low-pass or high-pass filter

fig = uifigure('Name', 'Vibration Viewer', 'Position', [100 100 1240 760]);

app.raw = [];
app.filtered = [];
app.t = [];
app.fs = [];
app.filePath = '';
app.channel = 3;
app.nativeFreq = [];
app.nativeSpec = [];
app.hasNativeSpec = false;
fig.UserData = app;

panel = uipanel(fig, 'Title', 'Controls', 'Position', [15 15 1210 165]);

btnLoad = uibutton(panel, 'push', ...
    'Text', 'Load File', ...
    'Position', [20 93 100 32], ...
    'ButtonPushedFcn', @onLoadFile);

edtFile = uieditfield(panel, 'text', ...
    'Editable', 'off', ...
    'Position', [130 95 640 30], ...
    'Placeholder', 'No file loaded');

uilabel(panel, 'Text', 'Channel k:', 'Position', [790 99 65 22]);
edtChannel = uieditfield(panel, 'numeric', ...
    'Limits', [1 Inf], ...
    'RoundFractionalValues', true, ...
    'Value', 3, ...
    'Position', [855 95 70 30]);

uilabel(panel, 'Text', 'Fs (Hz):', 'Position', [940 99 55 22]);
edtFs = uieditfield(panel, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', false, ...
    'Value', 1000, ...
    'Position', [995 95 80 30]);

uilabel(panel, 'Text', 'Spectrum:', 'Position', [1088 99 60 22]);
ddSpectrum = uidropdown(panel, ...
    'Items', {'FFT amplitude', 'VNA native'}, ...
    'Value', 'VNA native', ...
    'Position', [1140 95 60 30]);

uilabel(panel, 'Text', 'Filter:', 'Position', [20 45 45 22]);
ddFilterType = uidropdown(panel, ...
    'Items', {'None', 'Low-pass', 'High-pass'}, ...
    'Value', 'None', ...
    'Position', [70 40 110 30]);

uilabel(panel, 'Text', 'Cutoff (Hz):', 'Position', [200 45 75 22]);
edtCutoff = uieditfield(panel, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', false, ...
    'Value', 100, ...
    'Position', [280 40 90 30]);

uilabel(panel, 'Text', 'Order:', 'Position', [390 45 45 22]);
edtOrder = uieditfield(panel, 'numeric', ...
    'Limits', [1 12], ...
    'RoundFractionalValues', true, ...
    'Value', 4, ...
    'Position', [440 40 70 30]);

btnApply = uibutton(panel, 'push', ...
    'Text', 'Apply Filter', ...
    'Position', [530 40 100 30], ...
    'ButtonPushedFcn', @onApplyFilter);

btnReset = uibutton(panel, 'push', ...
    'Text', 'Reset', ...
    'Position', [640 40 80 30], ...
    'ButtonPushedFcn', @onResetFilter);

btnRefresh = uibutton(panel, 'push', ...
    'Text', 'Refresh Plot', ...
    'Position', [730 40 100 30], ...
    'ButtonPushedFcn', @(~,~) plotSignals());

lblStatus = uilabel(panel, ...
    'Text', 'Status: ready', ...
    'HorizontalAlignment', 'left', ...
    'Position', [850 45 350 22]);

axTime = uiaxes(fig, 'Position', [15 365 1210 375]);
title(axTime, 'Time Domain');
xlabel(axTime, 'Time (s)');
ylabel(axTime, 'Acceleration (m/s^2)');
grid(axTime, 'on');

axFreq = uiaxes(fig, 'Position', [15 190 1210 165]);
title(axFreq, 'Frequency Domain');
xlabel(axFreq, 'Frequency (Hz)');
ylabel(axFreq, 'Amplitude / PSD');
grid(axFreq, 'on');

    function onLoadFile(~, ~)
        [fname, fpath] = uigetfile( ...
            {'*.vna;*.mat;*.txt;*.dat;*.csv;*.xlsx', 'Data Files (*.vna,*.mat,*.txt,*.dat,*.csv,*.xlsx)'; ...
             '*.*', 'All Files (*.*)'}, ...
            'Select vibration data file');
        if isequal(fname, 0)
            return;
        end

        fullName = fullfile(fpath, fname);
        edtFile.Value = fullName;
        lblStatus.Text = 'Status: loading file...';
        drawnow;

        try
            fsHint = edtFs.Value;
            k = max(1, round(edtChannel.Value));
            D = readVibrationFile(fullName, fsHint, k);

            app = fig.UserData;
            app.raw = D.y;
            app.filtered = [];
            app.t = D.t;
            app.fs = D.fs;
            app.filePath = fullName;
            app.channel = D.channel;
            app.nativeFreq = D.nativeFreq;
            app.nativeSpec = D.nativeSpec;
            app.hasNativeSpec = D.hasNativeSpec;
            fig.UserData = app;

            edtChannel.Value = D.channel;
            edtFs.Value = D.fs;
            plotSignals();

            lblStatus.Text = sprintf( ...
                'Status: loaded %s | N=%d | Fs=%.3f Hz | channel=%d', ...
                fname, numel(D.y), D.fs, D.channel);
        catch ME
            uialert(fig, ME.message, 'Load failed');
            lblStatus.Text = 'Status: load failed';
        end
    end

    function onApplyFilter(~, ~)
        app = fig.UserData;
        if isempty(app.raw)
            uialert(fig, 'Please load data first.', 'Tip');
            return;
        end

        filterType = ddFilterType.Value;
        cutoff = edtCutoff.Value;
        order = edtOrder.Value;

        if strcmp(filterType, 'None')
            app.filtered = [];
            fig.UserData = app;
            plotSignals();
            lblStatus.Text = 'Status: filter disabled';
            return;
        end

        fs = app.fs;
        if cutoff <= 0 || cutoff >= fs / 2
            uialert(fig, sprintf('Cutoff must be in (0, %.3f) Hz.', fs / 2), 'Invalid parameter');
            return;
        end

        try
            wn = cutoff / (fs / 2);
            if strcmp(filterType, 'Low-pass')
                [b, a] = butter(order, wn, 'low');
            else
                [b, a] = butter(order, wn, 'high');
            end
            app.filtered = filtfilt(b, a, app.raw);
            fig.UserData = app;
            plotSignals();
            lblStatus.Text = sprintf('Status: %s applied | fc=%.3f Hz | order=%d', filterType, cutoff, order);
        catch ME
            uialert(fig, ME.message, 'Filter failed');
            lblStatus.Text = 'Status: filter failed';
        end
    end

    function onResetFilter(~, ~)
        app = fig.UserData;
        if isempty(app.raw)
            return;
        end
        app.filtered = [];
        fig.UserData = app;
        ddFilterType.Value = 'None';
        plotSignals();
        lblStatus.Text = 'Status: restored raw signal';
    end

    function plotSignals()
        app = fig.UserData;
        if isempty(app.raw)
            cla(axTime);
            cla(axFreq);
            return;
        end

        t = app.t;
        yRaw = app.raw;
        yShow = yRaw;
        if ~isempty(app.filtered)
            yShow = app.filtered;
        end

        cla(axTime);
        plot(axTime, t, yRaw, 'Color', [0.65 0.65 0.65], 'DisplayName', 'Raw');
        hold(axTime, 'on');
        if ~isempty(app.filtered)
            plot(axTime, t, yShow, 'b-', 'LineWidth', 1.1, 'DisplayName', 'Filtered');
        end
        hold(axTime, 'off');
        legend(axTime, 'show', 'Location', 'best');
        grid(axTime, 'on');
        xlabel(axTime, 'Time (s)');
        ylabel(axTime, 'Acceleration (m/s^2)');
        title(axTime, sprintf('Time Domain (channel %d)', app.channel));

        cla(axFreq);
        useNative = strcmp(ddSpectrum.Value, 'VNA native') && app.hasNativeSpec;

        if useNative
            safeLoglog(axFreq, app.nativeFreq, app.nativeSpec, ...
                'Color', [0.65 0.65 0.65], 'DisplayName', 'Raw (VNA native)');
            hold(axFreq, 'on');
            if ~isempty(app.filtered)
                [f2, a2] = singleSideSpectrum(yShow, app.fs);
                safeLoglog(axFreq, f2, a2, 'r-', 'LineWidth', 1.1, 'DisplayName', 'Filtered (FFT)');
            end
            hold(axFreq, 'off');
            title(axFreq, 'Frequency Domain (VNA native + optional filtered FFT)');
        else
            [f1, a1] = singleSideSpectrum(yRaw, app.fs);
            [f2, a2] = singleSideSpectrum(yShow, app.fs);
            safePlot(axFreq, f1, a1, 'Color', [0.65 0.65 0.65], 'DisplayName', 'Raw');
            hold(axFreq, 'on');
            if ~isempty(app.filtered)
                safePlot(axFreq, f2, a2, 'r-', 'LineWidth', 1.1, 'DisplayName', 'Filtered');
            end
            hold(axFreq, 'off');
            xlim(axFreq, [0 app.fs / 2]);
            title(axFreq, 'Frequency Domain (FFT amplitude)');
        end

        legend(axFreq, 'show', 'Location', 'best');
        grid(axFreq, 'on');
        xlabel(axFreq, 'Frequency (Hz)');
        ylabel(axFreq, 'Amplitude / PSD');

        if strcmp(ddSpectrum.Value, 'VNA native') && ~app.hasNativeSpec
            lblStatus.Text = 'Status: VNA native spectrum unavailable, fallback to FFT';
        end
    end
end

function D = readVibrationFile(fileName, fsHint, channelHint)
[~, ~, ext] = fileparts(fileName);
ext = lower(ext);

D = struct();
D.channel = max(1, round(channelHint));
D.nativeFreq = [];
D.nativeSpec = [];
D.hasNativeSpec = false;

switch ext
    case {'.vna', '.mat'}
        S = load(fileName, '-mat');
        D = parseVnaLikeStruct(S, D.channel, fsHint, D);
    case {'.txt', '.dat', '.csv', '.xlsx'}
        X = readmatrix(fileName);
        [t, y, fs] = parseNumericMatrix(X, fsHint);
        D.t = t;
        D.y = y;
        D.fs = fs;
    otherwise
        error('Unsupported file type: %s', ext);
end

if any(~isfinite(D.y))
    error('Data contains NaN or Inf.');
end
if numel(D.y) < 8
    error('Not enough data points for spectrum analysis.');
end
end

function D = parseVnaLikeStruct(S, channelHint, fsHint, D)
slm = [];
if isfield(S, 'SLm')
    slm = S.SLm;
else
    fns = fieldnames(S);
    for i = 1:numel(fns)
        v = S.(fns{i});
        if isstruct(v) && isfield(v, 'scmeas') && isfield(v, 'tdxvec')
            slm = v;
            break;
        end
    end
end

if isempty(slm)
    error('No SLm-like struct found in file.');
end

if ~isfield(slm, 'tdxvec') || ~isfield(slm, 'scmeas')
    error('SLm struct missing required fields: tdxvec/scmeas.');
end

t = slm.tdxvec(:);
if numel(t) < 2
    error('tdxvec is too short.');
end
dt = mean(diff(t));
if ~isfinite(dt) || dt <= 0
    validateFs(fsHint);
    fs = fsHint;
    t = (0:numel(t)-1)' / fs;
else
    fs = 1 / dt;
end

nCh = numel(slm.scmeas);
k = max(1, min(channelHint, nCh));
sc = slm.scmeas(k);

if ~isfield(sc, 'tdmeas') || isempty(sc.tdmeas)
    error('scmeas(%d).tdmeas is missing.', k);
end

if isfield(sc, 'eu_val') && ~isempty(sc.eu_val) && isfinite(sc.eu_val)
    gain = sc.eu_val;
else
    gain = 1;
end

y = sc.tdmeas(:) * gain;
N = min(numel(t), numel(y));
t = t(1:N);
y = y(1:N);

D.t = t;
D.y = y;
D.fs = fs;
D.channel = k;

if isfield(slm, 'fdxvec') && isfield(slm, 'wincor') && isfield(slm, 'rbw') && isfield(sc, 'aspec')
    f = slm.fdxvec(:);
    rbw = slm.rbw;
    wincor = slm.wincor;
    aspec = sc.aspec(:);
    if isfinite(rbw) && rbw > 0 && ~isempty(aspec) && ~isempty(f)
        M = min(numel(f), numel(aspec));
        f = f(1:M);
        psd = wincor * aspec(1:M) * (gain^2) / rbw;
        valid = isfinite(f) & isfinite(psd) & (f > 0) & (psd > 0);
        f = f(valid);
        psd = psd(valid);
        if ~isempty(f) && ~isempty(psd)
            D.nativeFreq = f;
            D.nativeSpec = psd;
            D.hasNativeSpec = true;
        end
    end
end
end

function [t, y, fs] = parseNumericMatrix(X, fsHint)
if isempty(X) || ~isnumeric(X)
    error('File does not contain numeric data.');
end

X = squeeze(X);
if isvector(X)
    y = X(:);
    validateFs(fsHint);
    fs = fsHint;
    t = (0:numel(y)-1)' / fs;
    return;
end

if size(X, 2) >= 2
    c1 = X(:, 1);
    c2 = X(:, 2);
    if isTimeLike(c1)
        t = c1(:);
        y = c2(:);
        fs = 1 / mean(diff(t));
    else
        y = c1(:);
        validateFs(fsHint);
        fs = fsHint;
        t = (0:numel(y)-1)' / fs;
    end
else
    y = X(:, 1);
    validateFs(fsHint);
    fs = fsHint;
    t = (0:numel(y)-1)' / fs;
end
end

function safePlot(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
plot(ax, x, y, varargin{:});
end

function safeLoglog(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y) & x > 0 & y > 0;
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
loglog(ax, x, y, varargin{:});
end

function tf = isTimeLike(v)
v = v(:);
if numel(v) < 3 || any(~isfinite(v))
    tf = false;
    return;
end
d = diff(v);
tf = all(d > 0) && (std(d) / max(mean(d), eps) < 1e-2);
end

function validateFs(fs)
if isempty(fs) || ~isfinite(fs) || fs <= 0
    error('Invalid Fs. Please input a valid sampling frequency.');
end
end

function [f, amp] = singleSideSpectrum(y, fs)
y = y(:);
N = numel(y);
y = y - mean(y);
Y = fft(y);
P2 = abs(Y / N);
P1 = P2(1:floor(N/2)+1);
if numel(P1) > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end
f = fs * (0:floor(N/2))' / N;
amp = P1(:);
end
