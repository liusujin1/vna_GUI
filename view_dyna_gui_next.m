function view_dyna_gui()
% GUI for vibration data (.vna/.mat/.txt/.dat/.csv/.xlsx)
% - channel single/multi selection
% - plot button drives time/PSD/transmissibility
% - optional low-pass/high-pass filtering in time domain

fig = uifigure('Name', 'Vibration Viewer', 'Position', [70 40 1320 920]);
app = initAppState();
fig.UserData = app;

panel = uipanel(fig, 'Title', 'Controls', 'Position', [15 15 1290 190]);

uibutton(panel, 'push', ...
    'Text', 'Load File', ...
    'Position', [20 132 110 34], ...
    'ButtonPushedFcn', @onLoadFile);

edtFile = uieditfield(panel, 'text', ...
    'Editable', 'off', ...
    'Position', [140 135 760 30], ...
    'Placeholder', 'No file loaded');

uilabel(panel, 'Text', 'Fs (Hz):', 'Position', [915 139 55 22]);
edtFs = uieditfield(panel, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', false, ...
    'Value', 1000, ...
    'Position', [970 135 80 30]);

uilabel(panel, 'Text', 'Ref ch:', 'Position', [1065 139 50 22]);
edtRefChannel = uieditfield(panel, 'numeric', ...
    'Limits', [1 Inf], ...
    'RoundFractionalValues', true, ...
    'Value', 1, ...
    'Position', [1115 135 60 30]);

uilabel(panel, 'Text', 'Channels:', 'Position', [20 92 65 22]);
lstChannels = uilistbox(panel, ...
    'Items', {'1'}, ...
    'Multiselect', 'on', ...
    'Value', {'1'}, ...
    'Position', [85 52 130 70]);

uilabel(panel, 'Text', 'Filter:', 'Position', [235 92 45 22]);
ddFilterType = uidropdown(panel, ...
    'Items', {'None', 'Low-pass', 'High-pass'}, ...
    'Value', 'None', ...
    'Position', [280 87 110 30]);

uilabel(panel, 'Text', 'Cutoff (Hz):', 'Position', [405 92 75 22]);
edtCutoff = uieditfield(panel, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', false, ...
    'Value', 100, ...
    'Position', [485 87 90 30]);

uilabel(panel, 'Text', 'Order:', 'Position', [590 92 45 22]);
edtOrder = uieditfield(panel, 'numeric', ...
    'Limits', [1 12], ...
    'RoundFractionalValues', true, ...
    'Value', 4, ...
    'Position', [640 87 60 30]);

uibutton(panel, 'push', ...
    'Text', 'Plot', ...
    'Position', [720 87 90 30], ...
    'ButtonPushedFcn', @onPlot);

uibutton(panel, 'push', ...
    'Text', 'Reset Filter', ...
    'Position', [820 87 100 30], ...
    'ButtonPushedFcn', @onResetFilter);

lblStatus = uilabel(panel, ...
    'Text', 'Status: ready', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 18 1240 22]);

axTime = uiaxes(fig, 'Position', [15 585 1290 320]);
title(axTime, 'Time Domain');
xlabel(axTime, 'Time (s)');
ylabel(axTime, 'Acceleration (m/s^2)');
grid(axTime, 'on');

axPsd = uiaxes(fig, 'Position', [15 380 1290 180]);
title(axPsd, 'PSD');
xlabel(axPsd, 'Frequency (Hz)');
ylabel(axPsd, '(m/s^2)^2/Hz');
grid(axPsd, 'on');

axTr = uiaxes(fig, 'Position', [15 210 1290 150]);
title(axTr, 'Transmissibility (k/ref)');
xlabel(axTr, 'Frequency (Hz)');
ylabel(axTr, 'Ratio');
grid(axTr, 'on');

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
            D = readVibrationFile(fullName, edtFs.Value);
            app = fig.UserData;
            app = D;
            app.filePath = fullName;
            fig.UserData = app;

            items = arrayfun(@num2str, app.validChannels, 'UniformOutput', false);
            lstChannels.Items = items;
            lstChannels.Value = items(1);
            edtRefChannel.Value = app.validChannels(1);
            edtFs.Value = app.fs;

            cla(axTime);
            cla(axPsd);
            cla(axTr);
            lblStatus.Text = sprintf('Status: loaded %s | valid channels: %s', fname, mat2str(app.validChannels));
        catch ME
            uialert(fig, ME.message, 'Load failed');
            lblStatus.Text = 'Status: load failed';
        end
    end

    function onPlot(~, ~)
        app = fig.UserData;
        if ~app.loaded
            uialert(fig, 'Please load data first.', 'Tip');
            return;
        end

        selectedChannels = parseSelectedChannels(lstChannels.Value, app.validChannels);
        if isempty(selectedChannels)
            uialert(fig, 'Please select at least one channel.', 'Tip');
            return;
        end

        refCh = chooseNearestValid(round(edtRefChannel.Value), app.validChannels);
        edtRefChannel.Value = refCh;

        cla(axTime);
        hold(axTime, 'on');
        anyTime = false;
        for i = 1:numel(selectedChannels)
            ch = selectedChannels(i);
            yRaw = safeCellGet(app.rawByCh, ch);
            if isempty(yRaw)
                continue;
            end
            yDraw = applyFilterToSignal(yRaw, app.fs, ddFilterType.Value, edtCutoff.Value, edtOrder.Value);
            N = min(numel(app.t), numel(yDraw));
            safePlot(axTime, app.t(1:N), yDraw(1:N), 'LineWidth', 1.1, 'DisplayName', sprintf('ch%d', ch));
            anyTime = true;
        end
        hold(axTime, 'off');
        if anyTime
            legend(axTime, 'show', 'Location', 'best');
        else
            legend(axTime, 'off');
            title(axTime, 'Time Domain (selected channels have no tdmeas)');
        end
        grid(axTime, 'on');
        xlabel(axTime, 'Time (s)');
        ylabel(axTime, 'Acceleration (m/s^2)');
        if anyTime
            title(axTime, sprintf('Time Domain (channels %s)', mat2str(selectedChannels)));
        end

        cla(axPsd);
        hold(axPsd, 'on');
        anyPsd = false;
        for i = 1:numel(selectedChannels)
            ch = selectedChannels(i);
            [f, psd] = getPsdForChannel(app, ch);
            if isempty(f)
                continue;
            end
            safeLoglog(axPsd, f, psd, 'LineWidth', 1.1, 'DisplayName', sprintf('PSD ch%d', ch));
            anyPsd = true;
        end
        hold(axPsd, 'off');
        if anyPsd
            legend(axPsd, 'show', 'Location', 'best');
        else
            legend(axPsd, 'off');
            title(axPsd, 'PSD (no available data for selected channels)');
        end
        grid(axPsd, 'on');
        xlabel(axPsd, 'Frequency (Hz)');
        ylabel(axPsd, '(m/s^2)^2/Hz');
        if anyPsd
            title(axPsd, sprintf('PSD (channels %s)', mat2str(selectedChannels)));
        end

        cla(axTr);
        hold(axTr, 'on');
        anyTr = false;
        for i = 1:numel(selectedChannels)
            ch = selectedChannels(i);
            if ch == refCh
                continue;
            end
            [f, tr] = getTransRatio(app, ch, refCh);
            if isempty(f)
                continue;
            end
            safeSemilogx(axTr, f, tr, 'LineWidth', 1.1, 'DisplayName', sprintf('ch%d/ch%d', ch, refCh));
            anyTr = true;
        end
        hold(axTr, 'off');
        if anyTr
            legend(axTr, 'show', 'Location', 'best');
            title(axTr, sprintf('Transmissibility Ratio (ref ch%d)', refCh));
        else
            legend(axTr, 'off');
            title(axTr, sprintf('Transmissibility Ratio (no curves, ref ch%d)', refCh));
        end
        grid(axTr, 'on');
        xlabel(axTr, 'Frequency (Hz)');
        ylabel(axTr, 'Ratio');

        lblStatus.Text = sprintf('Status: plotted channels %s | ref ch%d', mat2str(selectedChannels), refCh);
    end

    function onResetFilter(~, ~)
        ddFilterType.Value = 'None';
        lblStatus.Text = 'Status: filter reset to None';
    end
end

function app = initAppState()
app.loaded = false;
app.filePath = '';
app.t = [];
app.fs = [];
app.validChannels = 1;
app.rawByCh = {[]};
app.vna = struct( ...
    'available', false, ...
    'nCh', 1, ...
    'freq', [], ...
    'aspec', {{}}, ...
    'eu', 1, ...
    'wincor', 1, ...
    'rbw', 1);
end

function D = readVibrationFile(fileName, fsHint)
[~, ~, ext] = fileparts(fileName);
ext = lower(ext);
D = initAppState();

switch ext
    case {'.vna', '.mat'}
        S = load(fileName, '-mat');
        D = parseVnaLikeStruct(S, fsHint, D);
    case {'.txt', '.dat', '.csv', '.xlsx'}
        X = readmatrix(fileName);
        [t, y, fs] = parseNumericMatrix(X, fsHint);
        D.loaded = true;
        D.t = t;
        D.fs = fs;
        D.validChannels = 1;
        D.rawByCh = {y(:)};
        D.vna.available = false;
    otherwise
        error('Unsupported file type: %s', ext);
end
end

function D = parseVnaLikeStruct(S, fsHint, D)
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
rawByCh = cell(1, nCh);
validCh = [];
for ch = 1:nCh
    sc = slm.scmeas(ch);
    hasTd = isfield(sc, 'tdmeas') && ~isempty(sc.tdmeas);
    hasAspec = isfield(sc, 'aspec') && ~isempty(sc.aspec);
    if hasTd || hasAspec
        validCh(end + 1) = ch; %#ok<AGROW>
    end
    if hasTd
        eu = getEuVal(sc);
        y = sc.tdmeas(:) * eu;
        N = min(numel(t), numel(y));
        rawByCh{ch} = y(1:N);
    else
        rawByCh{ch} = [];
    end
end

if isempty(validCh)
    error('No valid channels found in scmeas.');
end

vna = struct( ...
    'available', false, ...
    'nCh', nCh, ...
    'freq', [], ...
    'aspec', {cell(1, nCh)}, ...
    'eu', ones(1, nCh), ...
    'wincor', 1, ...
    'rbw', 1);

if isfield(slm, 'fdxvec') && ~isempty(slm.fdxvec)
    vna.freq = slm.fdxvec(:);
end
if isfield(slm, 'wincor') && isfinite(slm.wincor)
    vna.wincor = slm.wincor;
end
if isfield(slm, 'rbw') && isfinite(slm.rbw) && slm.rbw > 0
    vna.rbw = slm.rbw;
end

for ch = 1:nCh
    sc = slm.scmeas(ch);
    if isfield(sc, 'aspec') && ~isempty(sc.aspec)
        a = sc.aspec(:);
        if ~isempty(vna.freq)
            M = min(numel(vna.freq), numel(a));
            a = a(1:M);
        end
        vna.aspec{ch} = a;
    else
        vna.aspec{ch} = [];
    end
    vna.eu(ch) = getEuVal(sc);
end
if ~isempty(vna.freq)
    vna.available = true;
end

D.loaded = true;
D.t = t;
D.fs = fs;
D.validChannels = validCh;
D.rawByCh = rawByCh;
D.vna = vna;
end

function yDraw = applyFilterToSignal(yRaw, fs, filterType, cutoff, order)
yDraw = yRaw(:);
if strcmp(filterType, 'None')
    return;
end
if cutoff <= 0 || cutoff >= fs / 2
    return;
end
try
    wn = cutoff / (fs / 2);
    if strcmp(filterType, 'Low-pass')
        [b, a] = butter(order, wn, 'low');
    else
        [b, a] = butter(order, wn, 'high');
    end
    yDraw = filtfilt(b, a, yDraw);
catch
    % If filter fails (short signal or unstable), keep raw signal.
    yDraw = yRaw(:);
end
end

function [f, psd] = getPsdForChannel(app, ch)
f = [];
psd = [];
if app.vna.available && ch >= 1 && ch <= app.vna.nCh
    a = safeCellGet(app.vna.aspec, ch);
    if ~isempty(a) && ~isempty(app.vna.freq) && isfinite(app.vna.rbw) && app.vna.rbw > 0
        M = min(numel(app.vna.freq), numel(a));
        f0 = app.vna.freq(1:M);
        eu = safeGet(app.vna.eu, ch, 1);
        p0 = app.vna.wincor * a(1:M) * (eu^2) / app.vna.rbw;
        valid = isfinite(f0) & isfinite(p0) & (f0 > 0) & (p0 > 0);
        f = f0(valid);
        psd = p0(valid);
        return;
    end
end

y = safeCellGet(app.rawByCh, ch);
if isempty(y)
    return;
end
[f, psd] = singleSideSpectrum(y, app.fs);
valid = isfinite(f) & isfinite(psd) & (f >= 0) & (psd >= 0);
f = f(valid);
psd = psd(valid);
end

function [f, tr] = getTransRatio(app, ch, refCh)
f = [];
tr = [];
if ~app.vna.available
    return;
end
if ch < 1 || ch > app.vna.nCh || refCh < 1 || refCh > app.vna.nCh
    return;
end
ak = safeCellGet(app.vna.aspec, ch);
ar = safeCellGet(app.vna.aspec, refCh);
if isempty(ak) || isempty(ar) || isempty(app.vna.freq)
    return;
end
M = min([numel(app.vna.freq), numel(ak), numel(ar)]);
f0 = app.vna.freq(1:M);
num = ak(1:M);
den = ar(1:M);
valid = isfinite(f0) & isfinite(num) & isfinite(den) & (f0 > 0) & (abs(den) > eps);
f = f0(valid);
tr = num(valid) ./ den(valid);
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

function eu = getEuVal(sc)
if isfield(sc, 'eu_val') && ~isempty(sc.eu_val) && isfinite(sc.eu_val)
    eu = sc.eu_val;
else
    eu = 1;
end
end

function selected = parseSelectedChannels(valueCell, validChannels)
if ischar(valueCell) || isstring(valueCell)
    valueCell = cellstr(valueCell);
end
selected = [];
for i = 1:numel(valueCell)
    ch = str2double(valueCell{i});
    if isfinite(ch)
        ch = round(ch);
        if ismember(ch, validChannels)
            selected(end + 1) = ch; %#ok<AGROW>
        end
    end
end
selected = unique(selected, 'stable');
end

function ch = chooseNearestValid(chIn, validList)
if isempty(validList)
    ch = 1;
    return;
end
if ismember(chIn, validList)
    ch = chIn;
    return;
end
[~, i] = min(abs(validList - chIn));
ch = validList(i);
end

function x = safeCellGet(c, idx)
if idx >= 1 && idx <= numel(c)
    x = c{idx};
else
    x = [];
end
end

function v = safeGet(arr, idx, fallback)
if idx >= 1 && idx <= numel(arr) && isfinite(arr(idx))
    v = arr(idx);
else
    v = fallback;
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

function safeSemilogx(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y) & (x > 0);
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
semilogx(ax, x, y, varargin{:});
end

function safeLoglog(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y) & (x > 0) & (y > 0);
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
P1 = P2(1:floor(N / 2) + 1);
if numel(P1) > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end
f = fs * (0:floor(N / 2))' / N;
amp = P1(:);
end
