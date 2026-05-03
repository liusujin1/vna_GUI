function varargout = view_vibration_analysis_gui(varargin)
% GUI for transfer-function and wide-log vibration analysis.
% - Page 1: frequency response / transmissibility
% - Page 2: log / sensor time-series browsing

if nargin > 0
    [varargout{1:nargout}] = dispatchViewerAction(varargin{:});
    return;
end

screenSz = get(0, 'ScreenSize');
figW = max(1280, min(round(screenSz(3) * 0.92), 1480));
figH = max(780, min(round(screenSz(4) * 0.88), 900));
figX = max(20, round((screenSz(3) - figW) / 2));
figY = max(20, round((screenSz(4) - figH) / 2));

fig = figure( ...
    'Name', 'Vibration Analysis Viewer', ...
    'NumberTitle', 'off', ...
    'Position', [figX figY figW figH], ...
    'Color', get(0, 'DefaultUicontrolBackgroundColor'), ...
    'MenuBar', 'figure', ...
    'ToolBar', 'figure', ...
    'Resize', 'on');

app = initViewerAppState();
setappdata(fig, 'app', app);
if nargout > 0
    varargout{1} = fig;
end

panel = uipanel('Parent', fig, 'Title', 'Controls', 'Units', 'pixels', ...
    'Position', [15 15 360 830]);

btnLoad = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Load Files', ...
    'Position', [15 785 100 30], ...
    'Callback', @onLoadFiles);
btnDelete = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Delete Selected', ...
    'Position', [125 785 105 30], ...
    'Callback', @onDeleteSelected);
btnClear = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Clear Plots', ...
    'Position', [240 785 105 30], ...
    'Callback', @onClearPlots);

edtFile = uicontrol('Parent', panel, 'Style', 'edit', ...
    'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'String', 'No file loaded', ...
    'Position', [15 745 330 30]);

lblLoadedFiles = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Loaded Files:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 715 100 20]);
lstFiles = uicontrol('Parent', panel, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [15 520 330 190], ...
    'Callback', @onFileSelectionChanged);

lblFsNum = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Fs Numerator:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 488 85 20]);
edtFsNum = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '5000', ...
    'BackgroundColor', 'w', ...
    'Position', [103 484 82 28], ...
    'Enable', 'off');
btnApplyFs = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Apply', ...
    'Position', [195 484 60 28], ...
    'Enable', 'off', ...
    'Callback', @onApplyFsNumerator);
lblFsHint = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'For selected frequency files only', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 462 240 18]);

grpFreq = uipanel('Parent', panel, 'Title', 'Frequency Settings', ...
    'Units', 'pixels', 'Position', [15 362 330 90]);
lblPair = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', 'Pair:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 42 40 20]);
ddPair = uicontrol('Parent', grpFreq, 'Style', 'popupmenu', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [55 40 255 24], ...
    'Callback', @onPairChanged);
lblFreqInfo = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', 'Select one or more frequency files to overlay.', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 10 300 18]);

grpLog = uipanel('Parent', panel, 'Title', 'Log Settings', ...
    'Units', 'pixels', 'Position', [15 155 330 197]);
lblPreset = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', 'Preset:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 166 45 20]);
ddPreset = uicontrol('Parent', grpLog, 'Style', 'popupmenu', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [60 164 250 24], ...
    'Callback', @onPresetChanged);
lblPlotMode = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', 'Plot Mode:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 136 60 20]);
ddPlotMode = uicontrol('Parent', grpLog, 'Style', 'popupmenu', ...
    'String', {'Subplots', 'Overlay'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [76 134 234 24], ...
    'Callback', @onPlotModeChanged);
lblLogRange = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', 'Range:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 108 45 18]);
edtLogStart = uicontrol('Parent', grpLog, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [60 105 82 24], ...
    'Callback', @onLogRangeChanged);
lblLogRangeSep = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', '~', ...
    'HorizontalAlignment', 'center', ...
    'Position', [146 108 16 18]);
edtLogEnd = uicontrol('Parent', grpLog, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [166 105 82 24], ...
    'Callback', @onLogRangeChanged);
lblLogRangeHint = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', 'Sample index', ...
    'HorizontalAlignment', 'left', ...
    'Position', [254 108 56 18]);
lblChannels = uicontrol('Parent', grpLog, 'Style', 'text', ...
    'String', 'Channels:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 80 55 20]);
lstLogChannels = uicontrol('Parent', grpLog, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [12 12 298 66], ...
    'Callback', @onLogChannelSelectionChanged);

btnPlot = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Plot', ...
    'Position', [15 112 100 30], ...
    'Callback', @onPlot);
btnDemean = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', 'Demean: Off', ...
    'Value', 0, ...
    'Position', [125 112 100 30], ...
    'Callback', @onDemeanChanged);
btnHold = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', 'Hold: Off', ...
    'Value', 0, ...
    'Position', [235 112 110 30], ...
    'Callback', @onHoldChanged);

lblStatus = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Status: ready', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 18 330 78]);

tabGroup = uitabgroup('Parent', fig, 'Units', 'pixels', 'Position', [390 15 1055 830]);
tabFreq = uitab('Parent', tabGroup, 'Title', 'Frequency Response');
tabLog = uitab('Parent', tabGroup, 'Title', 'Log / Sensors');
try
    set(tabGroup, 'SelectionChangedFcn', @onTabChanged);
catch
    try
        set(tabGroup, 'SelectionChangeFcn', @onTabChanged);
    catch
    end
end

lblFreqSelected = uicontrol('Parent', tabFreq, 'Style', 'text', ...
    'String', 'Selected pair overlay', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 785 480 20]);
btnMagFigure = uicontrol('Parent', tabFreq, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [910 782 60 26]);
btnPhaseFigure = uicontrol('Parent', tabFreq, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [910 387 60 26]);

axMag = axes('Parent', tabFreq, 'Units', 'pixels', ...
    'Position', [20 435 1010 330], 'Box', 'on');
title(axMag, 'Magnitude (dB)');
ylabel(axMag, 'Magnitude (dB)');
set(axMag, 'XScale', 'log');
grid(axMag, 'on');

axPhase = axes('Parent', tabFreq, 'Units', 'pixels', ...
    'Position', [20 40 1010 330], 'Box', 'on');
title(axPhase, 'Phase (deg)');
xlabel(axPhase, 'Frequency (Hz)');
ylabel(axPhase, 'Phase (deg)');
set(axPhase, 'XScale', 'log');
grid(axPhase, 'on');
set(btnMagFigure, 'Callback', @(~, ~) onOpenAxisFigure(axMag, 'Frequency Magnitude'));
set(btnPhaseFigure, 'Callback', @(~, ~) onOpenAxisFigure(axPhase, 'Frequency Phase'));

lblLogSelected = uicontrol('Parent', tabLog, 'Style', 'text', ...
    'String', 'Active log file', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 785 680 20]);
lblLogContext = uicontrol('Parent', tabLog, 'Style', 'text', ...
    'String', 'Category / preset / mode', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 765 860 18]);
btnLogFigure = uicontrol('Parent', tabLog, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [910 782 60 26], ...
    'Callback', @onOpenCurrentLogViewFigure);
pnlLogArea = uipanel('Parent', tabLog, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 45 1010 700]);
axLog = createLogHostAxis(pnlLogArea, 'Log / Sensor Time Series');

refreshFileList([]);
refreshContextControls();
updateTabControlVisibility();
set(fig, 'ResizeFcn', @onResize);
    onResize();

    function onLoadFiles(~, ~)
        app = getApp();
        injectedFiles = getappdata(fig, 'testFilesToLoad');
        useInjected = iscell(injectedFiles) && ~isempty(injectedFiles);
        if useInjected
            fileNames = cell(1, numel(injectedFiles));
            filePaths = cell(1, numel(injectedFiles));
            for i = 1:numel(injectedFiles)
                [filePaths{i}, baseName, ext] = fileparts(injectedFiles{i});
                fileNames{i} = [baseName, ext];
            end
            rmappdata(fig, 'testFilesToLoad');
        else
            [fileNames, filePath] = uigetfile( ...
                {'*.dat;*.txt;*.csv', 'Data Files (*.dat,*.txt,*.csv)'; ...
                 '*.*', 'All Files (*.*)'}, ...
                'Select analysis data files', app.lastOpenDir, 'MultiSelect', 'on');
            if isequal(fileNames, 0)
                return;
            end
            if ischar(fileNames)
                fileNames = {fileNames};
            end
            filePaths = repmat({filePath}, 1, numel(fileNames));
        end

        loadedIds = [];
        failed = {};
        setStatus('Status: loading files...');
        drawnow;

        for i = 1:numel(fileNames)
            fullName = fullfile(filePaths{i}, fileNames{i});
            try
                F = loadOneAnalysisFile(fullName);
                F.id = app.nextFileId;
                app.nextFileId = app.nextFileId + 1;
                app.files{end + 1} = F; %#ok<AGROW>
                loadedIds(end + 1) = F.id; %#ok<AGROW>
            catch ME
                failed{end + 1} = sprintf('%s: %s', fileNames{i}, ME.message); %#ok<AGROW>
            end
        end

        setApp(app);
        refreshFileList(loadedIds);
        refreshContextControls();
        if ~isempty(filePaths)
            app = getApp();
            app.lastOpenDir = filePaths{1};
            setApp(app);
        end
        if anyLoadedFileType(app.files, loadedIds, 'log')
            try
                set(tabGroup, 'SelectedTab', tabLog);
            catch
            end
            app = getApp();
            app.activeTab = 'log';
            setApp(app);
            updateTabControlVisibility();
            refreshContextControls();
        end
        autoPlotCurrentSelection();

        if isempty(failed)
            setStatus(sprintf('Status: loaded %d file(s).', numel(loadedIds)));
        else
            msg = sprintf('Status: loaded %d file(s), failed %d.', numel(loadedIds), numel(failed));
            if ~isempty(loadedIds)
                setStatus(msg);
            else
                setStatus(['Status: all files failed. ', failed{1}]);
            end
            showAlertCompat(fig, strjoin(failed, newline), 'Load warning');
        end
    end

    function onDeleteSelected(~, ~)
        app = getApp();
        selIds = getSelectedFileIds();
        if isempty(selIds)
            setStatus('Status: no loaded files selected.');
            return;
        end
        keep = true(1, numel(app.files));
        for i = 1:numel(app.files)
            keep(i) = ~any(app.files{i}.id == selIds);
        end
        app.files = app.files(keep);
        setApp(app);
        refreshFileList([]);
        refreshContextControls();
        setStatus(sprintf('Status: deleted %d file(s).', numel(selIds)));
    end

    function onApplyFsNumerator(~, ~)
        app = getApp();
        selIds = getSelectedFileIds();
        freqIdx = findFilesByIdsAndType(app.files, selIds, 'freq');
        if isempty(freqIdx)
            setStatus('Status: select frequency files before applying Fs numerator.');
            return;
        end
        fsNum = str2double(strtrim(get(edtFsNum, 'String')));
        if ~isfinite(fsNum) || fsNum <= 0
            showAlertCompat(fig, 'Fs numerator must be a positive number.', 'Invalid Fs numerator');
            return;
        end
        for i = 1:numel(freqIdx)
            app.files{freqIdx(i)}.fsNumerator = fsNum;
            app.files{freqIdx(i)}.fs = fsNum / app.files{freqIdx(i)}.update;
        end
        setApp(app);
        refreshFileList(selIds);
        refreshContextControls();
        setStatus(sprintf('Status: applied Fs numerator %.6g to %d frequency file(s).', fsNum, numel(freqIdx)));
    end

    function onFileSelectionChanged(~, ~)
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onPresetChanged(~, ~)
        refreshLogChannelSelection([]);
        autoPlotCurrentSelection();
    end

    function onPairChanged(~, ~)
        autoPlotCurrentSelection();
    end

    function onLogChannelSelectionChanged(~, ~)
        autoPlotCurrentSelection();
    end

    function onLogRangeChanged(~, ~)
        updateLogRangeControls();
        autoPlotCurrentSelection();
    end

    function onPlotModeChanged(~, ~)
        app = getApp();
        app.logPlotMode = getPopupSelectedString(ddPlotMode);
        if strcmp(app.logPlotMode, 'Subplots')
            app.holdPlots = false;
            set(btnHold, 'Value', 0, 'String', 'Hold: Off');
        end
        setApp(app);
        updateHoldControlState();
        autoPlotCurrentSelection();
    end

    function onDemeanChanged(~, ~)
        app = getApp();
        app.logDemean = logical(get(btnDemean, 'Value'));
        setApp(app);
        updateDemeanControlState();
        autoPlotCurrentSelection();
    end

    function onPlot(~, ~)
        app = getApp();
        if strcmp(app.activeTab, 'freq')
            plotFrequencyPage();
        else
            plotLogPage();
        end
    end

    function onHoldChanged(~, ~)
        app = getApp();
        if strcmp(app.activeTab, 'log') && strcmp(getPopupSelectedString(ddPlotMode), 'Subplots')
            app.holdPlots = false;
            set(btnHold, 'Value', 0, 'String', 'Hold: Off');
            setApp(app);
            return;
        end
        app.holdPlots = logical(get(btnHold, 'Value'));
        setApp(app);
        if app.holdPlots
            set(btnHold, 'String', 'Hold: On');
        else
            set(btnHold, 'String', 'Hold: Off');
        end
    end

    function onClearPlots(~, ~)
        clearAxisAndLegend(axMag);
        clearAxisAndLegend(axPhase);
        clearLogRenderArea(true);
        title(axMag, 'Magnitude (dB)');
        title(axPhase, 'Phase (deg)');
        xlabel(axMag, 'Frequency (Hz)');
        xlabel(axPhase, 'Frequency (Hz)');
        ylabel(axMag, 'Magnitude (dB)');
        ylabel(axPhase, 'Phase (deg)');
        set(axMag, 'XScale', 'log');
        set(axPhase, 'XScale', 'log');
        grid(axMag, 'on');
        grid(axPhase, 'on');
        app = getApp();
        app.lastLogRender = [];
        setApp(app);
        setStatus('Status: cleared all plots.');
    end

    function onOpenAxisFigure(sourceAx, fallbackTitle)
        cloneAxisToFigure(sourceAx, fallbackTitle);
    end

    function onOpenCurrentLogViewFigure(~, ~)
        app = getApp();
        if isempty(app.lastLogRender)
            setStatus('Status: no current log view to open.');
            return;
        end
        renderCurrentLogViewInFigure(app.lastLogRender);
    end

    function autoPlotCurrentSelection()
        app = getApp();
        try
            if strcmp(app.activeTab, 'freq')
                if hasSelectedFrequencyFile()
                    plotFrequencyPage();
                end
            else
                if hasSelectedLogFile()
                    plotLogPage();
                end
            end
        catch
            % Ignore transient UI states while controls are refreshing.
        end
    end

    function onTabChanged(~, ~)
        app = getApp();
        if isCurrentTab(tabGroup, tabFreq)
            app.activeTab = 'freq';
        else
            app.activeTab = 'log';
        end
        setApp(app);
        updateTabControlVisibility();
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onResize(~, ~)
        figPos = get(fig, 'Position');
        fw = max(figPos(3), 1280);
        fh = max(figPos(4), 780);
        if figPos(3) ~= fw || figPos(4) ~= fh
            figPos(3) = fw;
            figPos(4) = fh;
            set(fig, 'Position', figPos);
        end

        outerMargin = 15;
        gap = 15;
        panelW = max(320, min(360, round(fw * 0.25)));
        panelH = fh - 2 * outerMargin;
        tabX = outerMargin + panelW + gap;
        tabW = fw - tabX - outerMargin;
        tabH = panelH;

        set(panel, 'Position', [outerMargin outerMargin panelW panelH]);
        set(tabGroup, 'Position', [tabX outerMargin tabW tabH]);

        pw = panelW;
        ph = panelH;
        xPad = 15;
        contentW = pw - 2 * xPad;
        btnGap = 10;
        btnW = floor((contentW - 2 * btnGap) / 3);
        rowH = 28;
        topInset = 52;
        topY = ph - topInset;
        set(btnLoad, 'Position', [xPad topY btnW rowH]);
        set(btnDelete, 'Position', [xPad + btnW + btnGap topY btnW rowH]);
        set(btnClear, 'Position', [xPad + 2 * (btnW + btnGap) topY btnW rowH]);

        fileY = topY - 36;
        set(edtFile, 'Position', [xPad fileY contentW 28]);

        loadedLblY = fileY - 22;
        set(lblLoadedFiles, 'Position', [xPad loadedLblY 100 18]);
        listH = 190;
        listY = loadedLblY - listH - 6;
        set(lstFiles, 'Position', [xPad listY contentW listH]);

        fsRowY = listY - 38;
        set(lblFsNum, 'Position', [xPad fsRowY + 4 85 20]);
        set(edtFsNum, 'Position', [xPad + 88 fsRowY 82 28]);
        set(btnApplyFs, 'Position', [xPad + 180 fsRowY 60 28]);
        set(lblFsHint, 'Position', [xPad fsRowY - 24 contentW 18]);

        freqY = fsRowY - 122;
        set(grpFreq, 'Position', [xPad freqY contentW 90]);
        set(lblPair, 'Position', [12 42 40 20]);
        set(ddPair, 'Position', [55 40 contentW - 75 24]);
        set(lblFreqInfo, 'Position', [12 10 contentW - 20 18]);

        statusY = 18;
        statusH = 78;
        actionY = statusY + statusH + 12;
        actionW = floor((contentW - 2 * btnGap) / 3);
        set(btnPlot, 'Position', [xPad actionY actionW rowH]);
        set(btnDemean, 'Position', [xPad + actionW + btnGap actionY actionW rowH]);
        set(btnHold, 'Position', [xPad + 2 * (actionW + btnGap) actionY actionW rowH]);
        set(lblStatus, 'Position', [xPad statusY contentW statusH]);

        logBottom = actionY + rowH + 14;
        logTop = freqY - 12;
        logH = max(130, logTop - logBottom);
        set(grpLog, 'Position', [xPad logBottom contentW logH]);

        presetY = logH - 44;
        plotModeY = presetY - 28;
        rangeY = plotModeY - 28;
        channelsLabelY = rangeY - 28;
        listY = 12;
        listH = max(70, channelsLabelY - listY - 10);
        set(lblPreset, 'Position', [12 presetY + 1 45 16]);
        set(ddPreset, 'Position', [60 presetY - 1 contentW - 70 21]);
        set(lblPlotMode, 'Position', [12 plotModeY + 1 60 16]);
        set(ddPlotMode, 'Position', [76 plotModeY - 1 contentW - 86 21]);
        set(lblLogRange, 'Position', [12 rangeY + 1 45 16]);
        set(edtLogStart, 'Position', [60 rangeY - 1 74 21]);
        set(lblLogRangeSep, 'Position', [138 rangeY + 1 16 16]);
        set(edtLogEnd, 'Position', [158 rangeY - 1 74 21]);
        set(lblLogRangeHint, 'Position', [236 rangeY + 1 contentW - 246 16]);
        set(lblChannels, 'Position', [12 channelsLabelY 55 16]);
        set(lstLogChannels, 'Position', [12 listY contentW - 20 listH]);

        tw = tabW;
        th = tabH;
        topLabelY = th - 58;
        figBtnY = th - 66;
        figBtnW = 60;
        rightInset = 95;
        set(lblFreqSelected, 'Position', [24 topLabelY tw - 170 18]);
        set(btnMagFigure, 'Position', [tw - rightInset figBtnY figBtnW 26]);

        topMargin = 82;
        bottomMargin = 56;
        midGap = 72;
        usableH = th - topMargin - bottomMargin - midGap;
        axH = max(250, floor(usableH / 2));
        axW = tw - 60;
        phaseY = bottomMargin;
        magY = phaseY + axH + midGap;
        set(axMag, 'Position', [24 magY axW axH]);
        set(axPhase, 'Position', [24 phaseY axW axH]);
        set(btnPhaseFigure, 'Position', [tw - rightInset phaseY + axH + 16 figBtnW 26]);
        set(lblLogSelected, 'Position', [24 topLabelY tw - 190 18]);
        set(lblLogContext, 'Position', [24 topLabelY - 18 tw - 190 16]);
        set(btnLogFigure, 'Position', [tw - rightInset figBtnY figBtnW 26]);
        set(pnlLogArea, 'Position', [20 45 axW th - 132]);
        layoutLogAxes();
    end

    function plotFrequencyPage()
        app = getApp();
        selIds = getSelectedFileIds();
        freqIdx = findFilesByIdsAndType(app.files, selIds, 'freq');
        if isempty(freqIdx)
            setStatus('Status: select one or more frequency files first.');
            return;
        end

        pairLabel = getPopupSelectedString(ddPair);
        if isempty(pairLabel) || strcmp(pairLabel, '(none)')
            setStatus('Status: no available channel pair for the selected frequency files.');
            return;
        end

        if ~app.holdPlots
            clearAxisAndLegend(axMag);
            clearAxisAndLegend(axPhase);
        end

        hold(axMag, 'on');
        hold(axPhase, 'on');
        plotted = 0;
        skipped = {};
        xMin = inf;
        xMax = -inf;

        for i = 1:numel(freqIdx)
            F = app.files{freqIdx(i)};
            pairIdx = findPairIndexByLabel(F, pairLabel);
            if pairIdx < 1
                skipped{end + 1} = F.displayName; %#ok<AGROW>
                continue;
            end
            try
                [freq, magDb, phaseDeg] = computeTransferPair(F, pairIdx);
                if isempty(freq)
                    skipped{end + 1} = F.displayName; %#ok<AGROW>
                    continue;
                end
                legendName = sprintf('%s | Fs=%g/%g', F.displayName, F.fsNumerator, F.update);
                semilogx(axMag, freq, magDb, 'LineWidth', 1.1, 'DisplayName', legendName);
                semilogx(axPhase, freq, phaseDeg, 'LineWidth', 1.1, 'DisplayName', legendName);
                xMin = min(xMin, min(freq));
                xMax = max(xMax, max(freq));
                plotted = plotted + 1;
            catch ME
                skipped{end + 1} = sprintf('%s (%s)', F.displayName, ME.message); %#ok<AGROW>
            end
        end

        hold(axMag, 'off');
        hold(axPhase, 'off');
        grid(axMag, 'on');
        grid(axPhase, 'on');
        xlabel(axMag, 'Frequency (Hz)');
        xlabel(axPhase, 'Frequency (Hz)');
        ylabel(axMag, 'Magnitude (dB)');
        ylabel(axPhase, 'Phase (deg)');
        title(axMag, sprintf('Magnitude (dB) - %s', pairLabel));
        title(axPhase, sprintf('Phase (deg) - %s', pairLabel));
        if plotted > 0 && isfinite(xMin) && isfinite(xMax) && xMax > xMin
            xlim(axMag, [xMin xMax]);
            xlim(axPhase, [xMin xMax]);
        else
            set(axMag, 'XLimMode', 'auto');
            set(axPhase, 'XLimMode', 'auto');
        end

        if plotted > 0
            legend(axMag, 'show', 'Location', 'northeast');
            legend(axPhase, 'show', 'Location', 'northeast');
        else
            legend(axMag, 'off');
            legend(axPhase, 'off');
        end

        if isempty(skipped)
            setStatus(sprintf('Status: plotted pair %s for %d frequency file(s).', pairLabel, plotted));
        else
            setStatus(sprintf('Status: plotted %d file(s), skipped %d. See selection for details.', plotted, numel(skipped)));
        end
    end

    function plotLogPage()
        app = getApp();
        [F, note] = getCurrentLogFile(app.files, getSelectedFileIds());
        if isempty(F)
            setStatus('Status: select a log file first.');
            return;
        end

        G = getSelectedLogGroup(F, ddPreset);
        if isempty(G)
            setStatus('Status: selected log file has no matching preset groups.');
            return;
        end

        selCh = getListSelectionIndices(lstLogChannels, numel(G.columnIdx));
        if isempty(selCh)
            selCh = 1:numel(G.columnIdx);
        end
        colIdx = G.columnIdx(selCh);
        names = G.displayNames(selCh);
        [xData, Y, rangeStart, rangeEnd] = extractLogPlotSeries(F, colIdx, get(edtLogStart, 'String'), get(edtLogEnd, 'String'), app.logDemean);

        mode = getPopupSelectedString(ddPlotMode);
        if strcmp(mode, 'Subplots')
            renderLogSubplots(F, G, xData, Y, names, rangeStart, rangeEnd);
        else
            renderLogOverlay(F, G, xData, Y, names, rangeStart, rangeEnd);
        end

        app = getApp();
        app.lastLogRender = struct( ...
            'mode', mode, ...
            'fileId', F.id, ...
            'fileName', F.displayName, ...
            'groupName', G.name, ...
            'columnIdx', colIdx, ...
            'displayNames', {names}, ...
            'layout', chooseRenderLayout(G, numel(colIdx)), ...
            'category', F.logCategory, ...
            'rangeStart', rangeStart, ...
            'rangeEnd', rangeEnd, ...
            'demean', app.logDemean);
        setApp(app);

        if isempty(note)
            setStatus(sprintf('Status: plotted %d channel(s) from %s in %s mode, range %d-%d.', ...
                numel(colIdx), F.displayName, lower(mode), rangeStart, rangeEnd));
        else
            setStatus(sprintf('Status: plotted %d channel(s) from %s in %s mode, range %d-%d. %s', ...
                numel(colIdx), F.displayName, lower(mode), rangeStart, rangeEnd, note));
        end
    end

    function renderLogOverlay(F, G, xData, Y, names, rangeStart, rangeEnd)
        app = getApp();
        hasOverlayView = isstruct(app.lastLogRender) && isfield(app.lastLogRender, 'mode') && strcmp(app.lastLogRender.mode, 'Overlay');
        if ~app.holdPlots || isempty(axLog) || ~ishghandle(axLog) || ~hasOverlayView
            clearLogRenderArea(false);
            axLog = createLogHostAxis(pnlLogArea, sprintf('%s - %s', F.displayName, G.name));
        end
        hold(axLog, 'on');
        for i = 1:size(Y, 2)
            plot(axLog, xData, Y(:, i), ...
                'LineWidth', 1.0, 'DisplayName', names{i});
        end
        hold(axLog, 'off');
        grid(axLog, 'on');
        xlabel(axLog, 'Sample Index');
        ylabel(axLog, 'Value');
        applyLogXLimits(axLog, xData);
        title(axLog, sprintf('%s | %s | %s', getLogCategoryDisplayName(F.logCategory), G.name, F.displayName), 'Interpreter', 'none');
        legend(axLog, 'show', 'Location', 'northeast');
        setLogContextLabels(F, G, 'Overlay', size(Y, 2), rangeStart, rangeEnd);
    end

    function renderLogSubplots(F, G, xData, Y, names, rangeStart, rangeEnd)
        clearLogRenderArea(false);
        axLog = [];
        layout = chooseRenderLayout(G, size(Y, 2));
        renderSubplotGridToParent(pnlLogArea, xData, Y, names, layout, G.name);
        setLogContextLabels(F, G, 'Subplots', size(Y, 2), rangeStart, rangeEnd);
    end

    function renderCurrentLogViewInFigure(renderInfo)
        app = getApp();
        F = getFileById(app.files, renderInfo.fileId);
        if isempty(F)
            showAlertCompat(fig, 'The source log file is no longer loaded.', 'Open current view');
            return;
        end
        hFig = figure('Name', sprintf('%s - %s', renderInfo.fileName, renderInfo.groupName), ...
            'NumberTitle', 'off', 'Color', 'w');
        [xData, Y] = extractLogPlotSeries(F, renderInfo.columnIdx, renderInfo.rangeStart, renderInfo.rangeEnd, renderInfo.demean);
        if strcmp(renderInfo.mode, 'Subplots')
            renderSubplotGridToFigure(hFig, xData, Y, ...
                renderInfo.displayNames, renderInfo.layout, ...
                sprintf('%s | %s | %s', getLogCategoryDisplayName(F.logCategory), renderInfo.groupName, renderInfo.fileName), ...
                renderInfo.groupName);
        else
            ax = axes('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
            for i = 1:numel(renderInfo.columnIdx)
                plot(ax, xData, Y(:, i), ...
                    'LineWidth', 1.0, 'DisplayName', renderInfo.displayNames{i});
                hold(ax, 'on');
            end
            hold(ax, 'off');
            grid(ax, 'on');
            xlabel(ax, 'Sample Index');
            ylabel(ax, 'Value');
            applyLogXLimits(ax, xData);
            title(ax, sprintf('%s | %s | %s', getLogCategoryDisplayName(F.logCategory), renderInfo.groupName, renderInfo.fileName), 'Interpreter', 'none');
            legend(ax, 'show', 'Location', 'northeast');
        end
    end

    function clearLogRenderArea(showPlaceholder)
        if nargin < 1
            showPlaceholder = false;
        end
        kids = findall(pnlLogArea, 'Type', 'axes');
        if ~isempty(kids)
            delete(kids);
        end
        axLog = [];
        if showPlaceholder
            axLog = createLogHostAxis(pnlLogArea, 'Log / Sensor Time Series');
        end
    end

    function layoutLogAxes()
        kids = findall(pnlLogArea, 'Type', 'axes');
        if isempty(kids)
            return;
        end
        app = getApp();
        if ~isempty(app.lastLogRender) && strcmp(app.lastLogRender.mode, 'Subplots') && numel(kids) > 1
            layout = app.lastLogRender.layout;
            if prod(layout) < numel(kids)
                layout = chooseTightGrid(numel(kids));
            end
            applyAxesGridLayout(flipud(kids), layout);
        else
            set(kids, 'Units', 'normalized');
            if isscalar(kids)
                set(kids, 'Position', [0.07 0.08 0.89 0.84]);
            end
        end
    end

    function refreshFileList(selectedIds)
        app = getApp();
        if isempty(app.files)
            set(lstFiles, 'String', {'(none)'}, 'Value', 1);
            set(edtFile, 'String', 'No file loaded');
            return;
        end

        labels = cell(1, numel(app.files));
        ids = zeros(1, numel(app.files));
        for i = 1:numel(app.files)
            labels{i} = makeAnalysisFileLabel(app.files{i});
            ids(i) = app.files{i}.id;
        end
        if nargin < 1 || isempty(selectedIds)
            prevIds = getSelectedFileIds();
            if isempty(prevIds)
                selectedIds = ids(1);
            else
                selectedIds = prevIds;
            end
        end
        value = mapIdsToIndices(ids, selectedIds);
        if isempty(value)
            value = 1;
        end
        set(lstFiles, 'String', labels, 'Value', value);
        updateSelectedFileText();
    end

    function refreshContextControls()
        app = getApp();
        updateSelectedFileText();

        selIds = getSelectedFileIds();
        freqIdx = findFilesByIdsAndType(app.files, selIds, 'freq');
        if isempty(freqIdx)
            set(edtFsNum, 'Enable', 'off', 'String', '5000');
            set(btnApplyFs, 'Enable', 'off');
        else
            fsVals = zeros(1, numel(freqIdx));
            for i = 1:numel(freqIdx)
                fsVals(i) = app.files{freqIdx(i)}.fsNumerator;
            end
            if all(abs(fsVals - fsVals(1)) < 1e-12)
                fsText = num2str(fsVals(1));
            else
                fsText = 'mixed';
            end
            set(edtFsNum, 'Enable', 'on', 'String', fsText);
            set(btnApplyFs, 'Enable', 'on');
        end

        refreshFrequencyPairItems();
        refreshLogPresetItems();
        refreshLogChannelSelection([]);
        updateLogRangeControls();
        updateTabControlVisibility();
        updateTabSummaries();
        setPopupItemsCompat(ddPlotMode, {'Subplots', 'Overlay'}, app.logPlotMode);
        updateHoldControlState();
        updateDemeanControlState();
    end

    function refreshFrequencyPairItems()
        app = getApp();
        selIds = getSelectedFileIds();
        freqIdx = findFilesByIdsAndType(app.files, selIds, 'freq');
        if isempty(freqIdx)
            freqIdx = findFilesByType(app.files, 'freq');
        end
        prev = getPopupSelectedString(ddPair);
        items = collectFrequencyPairLabels(app.files, freqIdx);
        if isempty(items)
            items = {'(none)'};
        end
        setPopupItemsCompat(ddPair, items, prev);
    end

    function refreshLogPresetItems()
        app = getApp();
        [F, note] = getCurrentLogFile(app.files, getSelectedFileIds());
        prev = getPopupSelectedString(ddPreset);
        if isempty(F)
            setPopupItemsCompat(ddPreset, {'(none)'}, '(none)');
            set(lblLogSelected, 'String', 'Active log file: (none)');
            set(lblLogContext, 'String', 'Category / preset / mode');
            if isempty(note)
                set(lblFreqInfo, 'String', 'Select one or more frequency files to overlay.');
            end
            return;
        end

        visGroups = getVisibleLogGroups(F);
        groupNames = cell(1, numel(visGroups));
        for i = 1:numel(visGroups)
            groupNames{i} = visGroups(i).name;
        end
        if isempty(groupNames)
            groupNames = {'(none)'};
        end
        setPopupItemsCompat(ddPreset, groupNames, prev);
        if isempty(note)
            set(lblLogSelected, 'String', sprintf('Active log file: %s | %s', F.displayName, getLogCategoryDisplayName(F.logCategory)));
        else
            set(lblLogSelected, 'String', sprintf('Active log file: %s | %s (%s)', F.displayName, getLogCategoryDisplayName(F.logCategory), note));
        end
        if ~restoreRenderedLogContext(F)
            set(lblLogContext, 'String', 'Preset: (not plotted yet) | Mode: Subplots/Overlay');
        end
    end

    function refreshLogChannelSelection(preferredNames)
        if nargin < 1
            preferredNames = [];
        end
        app = getApp();
        [F, ~] = getCurrentLogFile(app.files, getSelectedFileIds());
        if isempty(F)
            set(lstLogChannels, 'String', {'(none)'}, 'Value', 1);
            return;
        end

        G = getSelectedLogGroup(F, ddPreset);
        if isempty(G)
            set(lstLogChannels, 'String', {'(none)'}, 'Value', 1);
            return;
        end

        items = G.displayNames;
        if isempty(items)
            items = {'(none)'};
            value = 1;
        else
            if isempty(preferredNames)
                value = 1:numel(items);
            else
                value = mapNamesToIndices(items, preferredNames);
                if isempty(value)
                    value = 1:numel(items);
                end
            end
        end
        set(lstLogChannels, 'String', items, 'Value', value);
    end

    function updateTabControlVisibility()
        app = getApp();
        if strcmp(app.activeTab, 'freq')
            set(grpFreq, 'Visible', 'on');
            set(grpLog, 'Visible', 'off');
            set(btnDemean, 'Enable', 'off');
            set(btnLogFigure, 'Enable', 'off');
        else
            set(grpFreq, 'Visible', 'off');
            set(grpLog, 'Visible', 'on');
            set(btnDemean, 'Enable', 'on');
            set(btnLogFigure, 'Enable', 'on');
        end
        updateHoldControlState();
        updateDemeanControlState();
    end

    function updateTabSummaries()
        app = getApp();
        selIds = getSelectedFileIds();
        freqIdx = findFilesByIdsAndType(app.files, selIds, 'freq');
        if isempty(freqIdx)
            set(lblFreqSelected, 'String', 'Selected pair overlay: (no frequency files selected)');
        else
            pairLabel = getPopupSelectedString(ddPair);
            set(lblFreqSelected, 'String', sprintf('Selected pair overlay: %s | files: %d', pairLabel, numel(freqIdx)));
        end

        [F, note] = getCurrentLogFile(app.files, selIds);
        if isempty(F)
            set(lblLogSelected, 'String', 'Active log file: (none)');
            set(lblLogContext, 'String', 'Category / preset / mode');
        else
            if isempty(note)
                set(lblLogSelected, 'String', sprintf('Active log file: %s | %s', F.displayName, getLogCategoryDisplayName(F.logCategory)));
            else
                set(lblLogSelected, 'String', sprintf('Active log file: %s | %s (%s)', F.displayName, getLogCategoryDisplayName(F.logCategory), note));
            end
            if ~restoreRenderedLogContext(F)
                set(lblLogContext, 'String', 'Preset: (not plotted yet) | Mode: Subplots/Overlay');
            end
        end
    end

    function updateHoldControlState()
        app = getApp();
        if strcmp(app.activeTab, 'log') && strcmp(getPopupSelectedString(ddPlotMode), 'Subplots')
            app.holdPlots = false;
            setApp(app);
            set(btnHold, 'Enable', 'off', 'Value', 0, 'String', 'Hold: Off');
        else
            set(btnHold, 'Enable', 'on');
            if app.holdPlots
                set(btnHold, 'String', 'Hold: On', 'Value', 1);
            else
                set(btnHold, 'String', 'Hold: Off', 'Value', 0);
            end
        end
    end

    function updateDemeanControlState()
        app = getApp();
        if strcmp(app.activeTab, 'log')
            set(btnDemean, 'Enable', 'on');
        else
            set(btnDemean, 'Enable', 'off');
        end
        if app.logDemean
            set(btnDemean, 'Value', 1, 'String', 'Demean: On');
        else
            set(btnDemean, 'Value', 0, 'String', 'Demean: Off');
        end
    end

    function setLogContextLabels(F, G, modeName, nChannels, rangeStart, rangeEnd)
        app = getApp();
        demeanText = ternaryText(app.logDemean, 'On', 'Off');
        set(lblLogSelected, 'String', sprintf('Active log file: %s | %s', F.displayName, getLogCategoryDisplayName(F.logCategory)));
        set(lblLogContext, 'String', sprintf('Preset: %s | Mode: %s | Range: %d-%d | Demean: %s | Channels: %d', ...
            G.name, modeName, rangeStart, rangeEnd, demeanText, nChannels));
    end

    function tf = restoreRenderedLogContext(F)
        app = getApp();
        tf = false;
        if isempty(F) || isempty(app.lastLogRender) || ~isstruct(app.lastLogRender)
            return;
        end
        renderInfo = app.lastLogRender;
        if ~isfield(renderInfo, 'fileId') || renderInfo.fileId ~= F.id
            return;
        end
        if ~isfield(renderInfo, 'groupName') || ~isfield(renderInfo, 'mode')
            return;
        end
        rangeStart = 1;
        rangeEnd = size(F.dataMatrix, 1);
        if isfield(renderInfo, 'rangeStart')
            rangeStart = renderInfo.rangeStart;
        end
        if isfield(renderInfo, 'rangeEnd')
            rangeEnd = renderInfo.rangeEnd;
        end
        if isfield(renderInfo, 'demean')
            demeanText = ternaryText(renderInfo.demean, 'On', 'Off');
        else
            demeanText = 'Off';
        end
        nChannels = 0;
        if isfield(renderInfo, 'columnIdx')
            nChannels = numel(renderInfo.columnIdx);
        end
        set(lblLogContext, 'String', sprintf('Preset: %s | Mode: %s | Range: %d-%d | Demean: %s | Channels: %d', ...
            renderInfo.groupName, renderInfo.mode, rangeStart, rangeEnd, demeanText, nChannels));
        tf = true;
    end

    function updateLogRangeControls()
        app = getApp();
        [F, ~] = getCurrentLogFile(app.files, getSelectedFileIds());
        if isempty(F)
            app.logRangeFileId = 0;
            setApp(app);
            set(edtLogStart, 'Enable', 'off', 'String', '1');
            set(edtLogEnd, 'Enable', 'off', 'String', '1');
            return;
        end
        nSamples = size(F.dataMatrix, 1);
        if ~isfield(app, 'logRangeFileId') || app.logRangeFileId ~= F.id
            startIdx = 1;
            endIdx = nSamples;
            app.logRangeFileId = F.id;
            setApp(app);
        else
            startIdx = parsePositiveInteger(get(edtLogStart, 'String'), 1);
            endIdx = parsePositiveInteger(get(edtLogEnd, 'String'), nSamples);
        end
        startIdx = max(1, min(nSamples, startIdx));
        endIdx = max(1, min(nSamples, endIdx));
        if endIdx < startIdx
            tmp = startIdx;
            startIdx = endIdx;
            endIdx = tmp;
        end
        set(edtLogStart, 'Enable', 'on', 'String', num2str(startIdx));
        set(edtLogEnd, 'Enable', 'on', 'String', num2str(endIdx));
    end

    function updateSelectedFileText()
        app = getApp();
        if isempty(app.files)
            set(edtFile, 'String', 'No file loaded');
            return;
        end
        selIds = getSelectedFileIds();
        txt = summarizeSelectedFiles(app.files, selIds);
        set(edtFile, 'String', txt);
    end

    function tf = hasSelectedFrequencyFile()
        app = getApp();
        selIds = getSelectedFileIds();
        tf = ~isempty(findFilesByIdsAndType(app.files, selIds, 'freq'));
    end

    function tf = hasSelectedLogFile()
        app = getApp();
        [F, ~] = getCurrentLogFile(app.files, getSelectedFileIds());
        tf = ~isempty(F);
    end

    function ids = getSelectedFileIds()
        app = getApp();
        if isempty(app.files)
            ids = [];
            return;
        end
        raw = get(lstFiles, 'Value');
        if isempty(raw)
            ids = [];
            return;
        end
        raw = raw(:)';
        ids = [];
        for i = 1:numel(raw)
            idx = raw(i);
            if idx >= 1 && idx <= numel(app.files)
                ids(end + 1) = app.files{idx}.id; %#ok<AGROW>
            end
        end
        ids = unique(ids, 'stable');
    end

    function app = getApp()
        app = getappdata(fig, 'app');
    end

    function setApp(appIn)
        setappdata(fig, 'app', appIn);
    end

    function setStatus(msg)
        set(lblStatus, 'String', msg);
    end
end

function varargout = dispatchViewerAction(action, varargin)
switch lower(char(action))
    case 'parsefile'
        if isempty(varargin)
            error('parsefile requires a file path.');
        end
        varargout{1} = loadOneAnalysisFile(varargin{1});
    case 'frequencypair'
        if numel(varargin) < 2
            error('frequencypair requires a file path and pair label/index.');
        end
        F = loadOneAnalysisFile(varargin{1});
        pairRef = varargin{2};
        if ischar(pairRef)
            pairIdx = findPairIndexByLabel(F, pairRef);
        else
            pairIdx = pairRef;
        end
        [freq, magDb, phaseDeg] = computeTransferPair(F, pairIdx);
        out = struct('freq', freq, 'magDb', magDb, 'phaseDeg', phaseDeg);
        varargout{1} = out;
    otherwise
        error('Unknown action: %s', char(action));
end
end

function app = initViewerAppState()
app.files = {};
app.nextFileId = 1;
app.lastOpenDir = pwd;
app.activeTab = 'freq';
app.holdPlots = false;
app.logPlotMode = 'Subplots';
app.logDemean = false;
app.logRangeFileId = 0;
app.lastLogRender = [];
end

function F = loadOneAnalysisFile(filePath)
[~, fileName, ext] = fileparts(filePath);
ext = lower(ext);
if ~ismember(ext, {'.dat', '.txt', '.csv'})
    error('Unsupported file type: %s', ext);
end

lines = readTextLinesCompat(filePath);
kind = detectAnalysisFileType(lines, fileName);
switch kind
    case 'freq'
        F = parseFrequencyAnalysisFile(filePath, lines);
    case 'log'
        F = parseWideLogAnalysisFile(filePath, lines);
    otherwise
        error('Unsupported analysis file type.');
end

F.filePath = filePath;
F.fileName = [fileName, ext];
F.displayName = F.fileName;
end

function kind = detectAnalysisFileType(lines, fileName)
kind = 'log';
hasUpdate = false;
has12NumericLine = false;
maxScan = min(numel(lines), 60);
for i = 1:maxScan
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    if ~isempty(regexpi(line, '^\s*Update\s*:', 'once'))
        hasUpdate = true;
    end
    [~, ok] = parseFixedNumericLine(line, 12);
    if ok
        has12NumericLine = true;
    end
end
if hasUpdate && has12NumericLine
    kind = 'freq';
elseif ~isempty(regexpi(fileName, '^IVHF_', 'once'))
    kind = 'freq';
end
end

function F = parseFrequencyAnalysisFile(~, lines)
dataStart = 0;
update = NaN;
samples = NaN;
average = NaN;

for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    if isnan(update)
        v = parseHeaderScalar(line, 'Update');
        if ~isnan(v)
            update = v;
        end
    end
    if isnan(samples)
        v = parseHeaderScalar(line, 'Samples');
        if ~isnan(v)
            samples = v;
        end
    end
    if isnan(average)
        v = parseHeaderScalar(line, 'Average');
        if ~isnan(v)
            average = v;
        end
    end
    [~, ok] = parseFixedNumericLine(line, 12);
    if ok
        dataStart = i;
        break;
    end
end

if dataStart < 1
    error('No 12-column numeric block found.');
end
if ~isfinite(update) || update <= 0
    error('Cannot find a valid Update value in file header.');
end

data = zeros(0, 12);
for i = dataStart:numel(lines)
    [row, ok] = parseFixedNumericLine(lines{i}, 12);
    if ok
        data(end + 1, :) = row; %#ok<AGROW>
    end
end
if isempty(data)
    error('Frequency data block is empty.');
end

headerTokens = {};
for i = dataStart - 1:-1:1
    toks = tokenizeWhitespace(lines{i});
    if numel(toks) < 12
        continue;
    end
    if sum(cellfun(@containsLetterCompat, toks)) >= 6
        headerTokens = toks(1:12);
        break;
    end
end
if isempty(headerTokens)
    headerTokens = defaultPairHeaders(6);
end

pairs = repmat(struct( ...
    'label', '', ...
    'inputName', '', ...
    'outputName', '', ...
    'inputColumn', 0, ...
    'outputColumn', 0), 1, 6);
for i = 1:6
    cIn = 2 * i - 1;
    cOut = 2 * i;
    pairs(i).inputName = headerTokens{cIn};
    pairs(i).outputName = headerTokens{cOut};
    pairs(i).label = derivePairDisplayLabel(headerTokens{cIn}, headerTokens{cOut}, i);
    pairs(i).inputColumn = cIn;
    pairs(i).outputColumn = cOut;
end

F = struct();
F.type = 'freq';
F.update = update;
F.samples = samples;
F.average = average;
F.dataMatrix = data;
F.headerNames = headerTokens;
F.pairs = pairs;
F.fsNumerator = 5000;
F.fs = F.fsNumerator / F.update;
end

function F = parseWideLogAnalysisFile(~, lines)
headerIdx = findFirstNonEmptyLine(lines);
if headerIdx < 1
    error('Log file is empty.');
end

[~, firstNums, firstIsData] = parseWideDataLine(lines{headerIdx}, []);
if firstIsData
    dataStart = headerIdx;
    nNumeric = numel(firstNums);
    rawHeaderNames = createGenericHeaders(nNumeric);
else
    separatorIdx = findSeparatorLine(lines, headerIdx + 1);
    if separatorIdx > 0
        dataStart = separatorIdx + 1;
    else
        dataStart = headerIdx + 1;
    end
    nNumeric = NaN;
    firstDataIdx = 0;
    for i = dataStart:numel(lines)
        [~, nums, ok] = parseWideDataLine(lines{i}, []);
        if ok
            nNumeric = numel(nums);
            firstDataIdx = i;
            break;
        end
    end
    if ~isfinite(nNumeric) || nNumeric < 1
        error('Cannot find numeric log rows.');
    end
    if firstDataIdx > dataStart
        dataStart = firstDataIdx;
    end
    headerTokens = tokenizeWhitespace(lines{headerIdx});
    if numel(headerTokens) >= nNumeric + 2
        rawHeaderNames = headerTokens(3:(nNumeric + 2));
    else
        rawHeaderNames = createGenericHeaders(nNumeric);
    end
end

headerNames = normalizeHeaderNames(rawHeaderNames, nNumeric);

timeText = {};
data = zeros(0, nNumeric);
for i = dataStart:numel(lines)
    [txt, nums, ok] = parseWideDataLine(lines{i}, nNumeric);
    if ok
        timeText{end + 1, 1} = txt; %#ok<AGROW>
        data(end + 1, :) = nums; %#ok<AGROW>
    end
end
if isempty(data)
    error('Log data block is empty.');
end

groups = buildWideLogGroups(headerNames);
logCategory = classifyLogCategory(headerNames);

F = struct();
F.type = 'log';
F.headerNames = headerNames;
F.rawHeaderNames = rawHeaderNames;
F.rawTimeText = timeText;
F.dataMatrix = data;
F.sampleIndex = (1:size(data, 1))';
F.groups = groups;
F.profile = classifyLegacyLogProfile(size(data, 2));
F.logCategory = logCategory;
end

function lines = readTextLinesCompat(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('Cannot open file: %s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
lines = C{1};
if isempty(lines)
    lines = {};
end
end

function idx = findFirstNonEmptyLine(lines)
idx = 0;
for i = 1:numel(lines)
    if ~isempty(strtrim(lines{i}))
        idx = i;
        return;
    end
end
end

function idx = findSeparatorLine(lines, startIdx)
idx = 0;
for i = startIdx:numel(lines)
    s = strtrim(lines{i});
    if isempty(s)
        continue;
    end
    if ~isempty(regexp(s, '^[-=]{10,}$', 'once'))
        idx = i;
        return;
    end
end
end

function val = parseHeaderScalar(line, key)
val = NaN;
expr = ['^\s*', regexptranslate('escape', key), '\s*:\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)'];
tok = regexp(line, expr, 'tokens', 'once');
if ~isempty(tok)
    val = str2double(tok{1});
end
end

function [row, ok] = parseFixedNumericLine(line, nCols)
row = [];
ok = false;
toks = tokenizeWhitespace(line);
if numel(toks) < nCols
    return;
end
toks = toks(1:nCols);
nums = str2double(toks);
if all(isfinite(nums)) && numel(nums) == nCols
    row = nums(:).';
    ok = true;
end
end

function [timeText, nums, ok] = parseWideDataLine(line, nNumeric)
timeText = '';
nums = [];
ok = false;
toks = tokenizeWhitespace(line);
if numel(toks) < 3
    return;
end
if isempty(nNumeric)
    nNumeric = numel(toks) - 2;
end
if numel(toks) < nNumeric + 2
    return;
end
numToks = toks(3:(2 + nNumeric));
vals = str2double(numToks);
if ~all(isfinite(vals))
    return;
end
timeText = [toks{1}, ' ', toks{2}];
nums = vals(:).';
ok = true;
end

function toks = tokenizeWhitespace(line)
toks = regexp(strtrim(line), '\S+', 'match');
if isempty(toks)
    toks = {};
end
end

function tf = containsLetterCompat(txt)
tf = ~isempty(regexp(txt, '[A-Za-z]', 'once'));
end

function headers = defaultPairHeaders(nPairs)
headers = cell(1, 2 * nPairs);
for i = 1:nPairs
    headers{2 * i - 1} = sprintf('Pair%d_in', i);
    headers{2 * i} = sprintf('Pair%d_out', i);
end
end

function label = derivePairDisplayLabel(inputName, outputName, idx)
baseIn = normalizePairName(inputName);
baseOut = normalizePairName(outputName);
if ~isempty(baseIn) && strcmpi(baseIn, baseOut)
    label = baseIn;
elseif ~isempty(baseIn)
    label = baseIn;
elseif ~isempty(baseOut)
    label = baseOut;
else
    label = sprintf('Pair%d', idx);
end
end

function base = normalizePairName(nameIn)
base = strtrim(nameIn);
base = regexprep(base, '\[[^\]]*\]', '');
base = regexprep(base, '\([^\)]*\)', '');
base = regexprep(base, '[_-]?(in|out)$', '', 'ignorecase');
base = regexprep(base, '[_-]?(in|out)[_-].*$', '', 'ignorecase');
base = regexprep(base, '\s+', '');
base = regexprep(base, '[^A-Za-z0-9]+$', '');
if isempty(base)
    return;
end
if ~isempty(regexpi(base, '^(x|y|z|rx|ry|rz|v\d+|h\d+)$', 'once'))
    base = upperLeadingLetter(base);
end
end

function txt = upperLeadingLetter(txt)
if isempty(txt)
    return;
end
txt = char(txt);
txt(1) = upper(txt(1));
end

function [freq, magDb, phaseDeg] = computeTransferPair(F, pairIdx)
if pairIdx < 1 || pairIdx > numel(F.pairs)
    error('Invalid pair index.');
end
if ~isfinite(F.update) || F.update <= 0
    error('Update value is invalid.');
end

x = F.dataMatrix(:, F.pairs(pairIdx).inputColumn);
y = F.dataMatrix(:, F.pairs(pairIdx).outputColumn);
n = numel(x);
if n < 8
    error('Not enough samples for tfestimate.');
end
nfft = floor(n / 3);
if nfft < 8
    nfft = n;
end
nfft = min(nfft, n);
fs = F.fsNumerator / F.update;
win = hann(nfft);
[Txy, Faxis] = tfestimate(x, y, win, 0, nfft, fs, 'onesided');
valid = isfinite(Faxis) & isfinite(Txy) & Faxis > 0;
freq = Faxis(valid);
magDb = 20 * log10(abs(Txy(valid)));
phaseDeg = angle(Txy(valid)) * 180 / pi;
end

function headers = createGenericHeaders(n)
headers = cell(1, n);
for i = 1:n
    headers{i} = sprintf('Col%02d', i);
end
end

function headers = normalizeHeaderNames(rawHeaders, nExpected)
if nargin < 2
    nExpected = numel(rawHeaders);
end
if isempty(rawHeaders)
    rawHeaders = createGenericHeaders(nExpected);
end
if numel(rawHeaders) < nExpected
    missing = createGenericHeaders(nExpected - numel(rawHeaders));
    rawHeaders = [rawHeaders(:).', missing]; %#ok<AGROW>
end
headers = rawHeaders(1:nExpected);
used = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:numel(headers)
    txt = strtrim(headers{i});
    txt = regexprep(txt, '\s+', ' ');
    if isempty(txt)
        txt = sprintf('Col%02d', i);
    end
    if isKey(used, txt)
        used(txt) = used(txt) + 1;
        txt = sprintf('%s (%d)', txt, used(txt));
    else
        used(txt) = 1;
    end
    headers{i} = txt;
end
end

function groups = buildWideLogGroups(headerNames)
groups = struct('name', {}, 'columnIdx', {}, 'displayNames', {}, 'layout', {});
nCols = numel(headerNames);

groups = addHeaderMatchGroup(groups, 'BF Velocity', headerNames, '^VEL_BF_');
groups = addHeaderMatchGroup(groups, 'SF Velocity', headerNames, '^VEL_SF_');
groups = addHeaderMatchGroup(groups, 'PROX Position', headerNames, '^PROX_');
groups = addHeaderMatchGroup(groups, 'PS Motion', headerNames, '^PS_(POS|ACC)_');
groups = addGroupedValueOutputs(groups, headerNames);
groups = addHeaderMatchGroup(groups, 'MT Actuator Force', headerNames, '^MT_AM\d+_');
groups = addHeaderMatchGroup(groups, 'MT Temperature', headerNames, '^MT_TM_');
groups = addInputOutputSensorGroups(groups, headerNames);

groups = addHeaderMatchGroup(groups, 'PS Position', headerNames, '^PS_');
groups = addHeaderMatchGroup(groups, 'VS Velocity', headerNames, '^VS_');
groups = addHeaderMatchGroup(groups, 'VFS Filtered Velocity', headerNames, '^VFS_');
groups = addHeaderMatchGroup(groups, 'TS Temperature', headerNames, '^TS_');
groups = addHeaderMatchGroup(groups, 'WS/RS Stage', headerNames, '^(WS\d*_.*|RS_)');
groups = addHeaderMatchGroup(groups, 'AC Actuator Force', headerNames, '^AC_');
groups = addHeaderMatchGroup(groups, 'Reserved', headerNames, '^RESERVED');

if nCols == 34
    groups = appendLegacy34Groups(groups);
elseif nCols == 55
    groups = appendLegacy55Groups(groups);
end

groups = appendGroup(groups, 'All Channels', 1:nCols, headerNames, chooseTightGrid(nCols));
end

function category = classifyLogCategory(headerNames)
inpScore = 0;
s611aScore = 0;
viScore = 0;
for i = 1:numel(headerNames)
    name = headerNames{i};
    if ~isempty(regexpi(name, '^(INP|OUT|TEMP_)', 'once'))
        inpScore = inpScore + 1;
    end
    if ~isempty(regexpi(name, '^(VEL_BF_|VEL_SF_|PROX_|VALUE\d+_|MT_)', 'once'))
        s611aScore = s611aScore + 1;
    end
    if ~isempty(regexpi(name, '^(PS_|VS_|VFS_|TS_|WS\d*_?|RS_|AC_|RESERVED)', 'once'))
        viScore = viScore + 1;
    end
end

[bestScore, idx] = max([inpScore, s611aScore, viScore]);
if bestScore <= 0
    category = 'generic';
    return;
end
switch idx
    case 1
        category = 'legacy_inp_out';
    case 2
        category = 'legacy_611a';
    case 3
        category = 'vi_sensor_value';
    otherwise
        category = 'generic';
end
end

function txt = getLogCategoryDisplayName(category)
switch category
    case 'legacy_inp_out'
        txt = 'INP/OUT';
    case 'legacy_611a'
        txt = '611A';
    case 'vi_sensor_value'
        txt = 'VI Sensor';
    otherwise
        txt = 'Generic';
end
end

function groups = getVisibleLogGroups(F)
if isempty(F) || ~isfield(F, 'groups') || isempty(F.groups)
    groups = struct('name', {}, 'columnIdx', {}, 'displayNames', {}, 'layout', {});
    return;
end
allowed = getAllowedLogGroupNames(F.logCategory);
groups = struct('name', {}, 'columnIdx', {}, 'displayNames', {}, 'layout', {});
for i = 1:numel(F.groups)
    if any(strcmp(F.groups(i).name, allowed))
        groups(end + 1) = F.groups(i); %#ok<AGROW>
    end
end
if isempty(groups)
    for i = 1:numel(F.groups)
        if numel(F.groups(i).name) >= 7 && strcmp(F.groups(i).name(1:7), 'Legacy ')
            continue;
        end
        groups(end + 1) = F.groups(i); %#ok<AGROW>
    end
end
end

function allowed = getAllowedLogGroupNames(category)
switch category
    case 'legacy_inp_out'
        allowed = {'INP FF', 'INP FB', 'INP PROX', 'INP Stage', 'OUT Valve', 'OUT Force', 'TEMP', 'All Channels'};
    case 'legacy_611a'
        allowed = {'BF Velocity', 'SF Velocity', 'PROX Position', 'PS Motion', ...
            'Valve Output 1', 'Valve Output 2', 'Valve Output 3', 'Valve Output 4', ...
            'Valve Output All', 'MT Actuator Force', 'MT Temperature', 'All Channels'};
    case 'vi_sensor_value'
        allowed = {'PS Position', 'VS Velocity', 'VFS Filtered Velocity', 'TS Temperature', ...
            'WS/RS Stage', 'AC Actuator Force', 'Reserved', 'All Channels'};
    otherwise
        allowed = {};
end
end

function layout = chooseRenderLayout(G, nPlots)
layout = [];
if isfield(G, 'layout') && numel(G.layout) == 2 && prod(G.layout) >= nPlots
    layout = G.layout;
end
if isempty(layout)
    layout = chooseTightGrid(nPlots);
end
end

function ax = createLogHostAxis(parentObj, ttl)
ax = axes('Parent', parentObj, 'Units', 'normalized', ...
    'Position', [0.07 0.08 0.89 0.84], 'Box', 'on');
title(ax, ttl, 'Interpreter', 'none');
xlabel(ax, 'Sample Index');
ylabel(ax, 'Value');
grid(ax, 'on');
end

function renderSubplotGridToParent(parentObj, sampleIndex, Y, names, layout, groupName)
axesHandles = createAxesGrid(parentObj, layout, size(Y, 2));
for i = 1:numel(axesHandles)
    plot(axesHandles(i), sampleIndex, Y(:, i), 'LineWidth', 1.0);
    grid(axesHandles(i), 'on');
    title(axesHandles(i), sprintf('%s | %s', groupName, names{i}), 'Interpreter', 'none');
    styleLogSubplotAxis(axesHandles(i), i, layout, false);
    applyLogXLimits(axesHandles(i), sampleIndex);
end
end

function renderSubplotGridToFigure(hFig, sampleIndex, Y, names, layout, figTitle, groupName)
axesHandles = createAxesGrid(hFig, layout, size(Y, 2));
for i = 1:numel(axesHandles)
    plot(axesHandles(i), sampleIndex, Y(:, i), 'LineWidth', 1.0);
    grid(axesHandles(i), 'on');
    title(axesHandles(i), sprintf('%s | %s', groupName, names{i}), 'Interpreter', 'none');
    styleLogSubplotAxis(axesHandles(i), i, layout, true);
    applyLogXLimits(axesHandles(i), sampleIndex);
end
try
    sgtitle(hFig, figTitle, 'Interpreter', 'none');
catch
end
end

function axesHandles = createAxesGrid(parentObj, layout, nAxes)
if prod(layout) < nAxes
    layout = chooseTightGrid(nAxes);
end
axesHandles = gobjects(1, nAxes);
for i = 1:nAxes
    axesHandles(i) = axes('Parent', parentObj, 'Units', 'normalized', 'Box', 'on');
end
applyAxesGridLayout(axesHandles, layout);
end

function applyAxesGridLayout(axesHandles, layout)
nRows = layout(1);
nCols = layout(2);
nAxes = numel(axesHandles);
left = 0.09;
right = 0.03;
bottom = 0.11;
top = 0.11;
hGap = 0.05;
vGap = 0.12;
cellW = (1 - left - right - (nCols - 1) * hGap) / nCols;
cellH = (1 - top - bottom - (nRows - 1) * vGap) / nRows;
for i = 1:nAxes
    row = ceil(i / nCols);
    col = mod(i - 1, nCols) + 1;
    x = left + (col - 1) * (cellW + hGap);
    y = 1 - top - row * cellH - (row - 1) * vGap;
    set(axesHandles(i), 'Units', 'normalized', 'Position', [x y cellW cellH]);
end
end

function styleLogSubplotAxis(ax, idx, layout, isExportFigure)
nRows = layout(1);
nCols = layout(2);
row = ceil(idx / nCols);
col = mod(idx - 1, nCols) + 1;
isBottomRow = (row == nRows);
isLeftCol = (col == 1);
if isBottomRow
    xlabel(ax, 'Sample Index');
else
    xlabel(ax, '');
end
if isLeftCol
    ylabel(ax, 'Value');
else
    ylabel(ax, '');
end
if isExportFigure
    set(ax, 'FontSize', 10, 'TitleFontSizeMultiplier', 0.95);
else
    set(ax, 'FontSize', 9, 'TitleFontSizeMultiplier', 0.90);
end
end

function applyLogXLimits(ax, xData)
if isempty(xData)
    set(ax, 'XLimMode', 'auto');
    return;
end
if numel(xData) == 1
    x0 = double(xData(1));
    xlim(ax, [x0 - 0.5, x0 + 0.5]);
else
    xlim(ax, [double(xData(1)), double(xData(end))]);
end
end

function [xData, Y, startIdx, endIdx] = extractLogPlotSeries(F, colIdx, startRef, endRef, doDemean)
nSamples = size(F.dataMatrix, 1);
if isnumeric(startRef)
    startIdx = startRef;
else
    startIdx = parsePositiveInteger(startRef, 1);
end
if isnumeric(endRef)
    endIdx = endRef;
else
    endIdx = parsePositiveInteger(endRef, nSamples);
end
startIdx = max(1, min(nSamples, startIdx));
endIdx = max(1, min(nSamples, endIdx));
if endIdx < startIdx
    tmp = startIdx;
    startIdx = endIdx;
    endIdx = tmp;
end
xData = F.sampleIndex(startIdx:endIdx);
Y = F.dataMatrix(startIdx:endIdx, colIdx);
if doDemean
    Y = removeColumnMeans(Y);
end
end

function Y = removeColumnMeans(Y)
for i = 1:size(Y, 2)
    col = Y(:, i);
    valid = isfinite(col);
    if any(valid)
        col(valid) = col(valid) - mean(col(valid));
    end
    Y(:, i) = col;
end
end

function value = parsePositiveInteger(raw, defaultValue)
if isnumeric(raw)
    value = raw;
else
    value = str2double(strtrim(raw));
end
if ~isfinite(value) || value < 1
    value = defaultValue;
end
value = max(1, round(value));
end

function tf = anyLoadedFileType(files, ids, typeName)
tf = false;
for i = 1:numel(files)
    if any(files{i}.id == ids) && strcmp(files{i}.type, typeName)
        tf = true;
        return;
    end
end
end

function txt = ternaryText(cond, trueText, falseText)
if cond
    txt = trueText;
else
    txt = falseText;
end
end

function groups = addGroupedValueOutputs(groups, headerNames)
valuePrefixes = {'VALUE1_', 'VALUE2_', 'VALUE3_', 'VALUE4_'};
for i = 1:numel(valuePrefixes)
    prefix = valuePrefixes{i};
    name = ['Valve Output ', num2str(i)];
    groups = addHeaderMatchGroup(groups, name, headerNames, ['^', regexptranslate('escape', prefix)]);
end
groups = addHeaderMatchGroup(groups, 'Valve Output All', headerNames, '^VALUE\d+_');
end

function groups = addInputOutputSensorGroups(groups, headerNames)
groups = addHeaderMatchGroup(groups, 'INP FF', headerNames, '^INP[XYZ]FF');
groups = addHeaderMatchGroup(groups, 'INP FB', headerNames, '^INP[XYZ]\d+FB|^INP[XYZ][A-Z0-9]*FB');
groups = addHeaderMatchGroup(groups, 'INP PROX', headerNames, '^INP[HV]?PROX');
groups = addHeaderMatchGroup(groups, 'INP Stage', headerNames, '^INP[XY](POS|ACC)');
groups = addHeaderMatchGroup(groups, 'OUT Valve', headerNames, '^OUTV\d+');
groups = addHeaderMatchGroup(groups, 'OUT Force', headerNames, '^OUT[XYZ][0-9]?\(N\)|^OUT[A-Z0-9]+\(N\)');
groups = addHeaderMatchGroup(groups, 'TEMP', headerNames, '^TEMP_');
end

function groups = addHeaderMatchGroup(groups, groupName, headerNames, expr)
idx = [];
names = {};
for i = 1:numel(headerNames)
    if ~isempty(regexpi(headerNames{i}, expr, 'once'))
        idx(end + 1) = i; %#ok<AGROW>
        names{end + 1} = headerNames{i}; %#ok<AGROW>
    end
end
if ~isempty(idx)
    groups = appendGroupIfMissing(groups, groupName, idx, names, chooseTightGrid(numel(idx)));
end
end

function groups = appendLegacy34Groups(groups)
defs = { ...
    'Legacy Floor FF', 1:3, {'XFF', 'YFF', 'ZFF'}, [3 1]; ...
    'Legacy Velocity FB', 4:9, {'Y1FB', 'Z1FB', 'X2FB', 'Z2FB', 'Y3FB', 'Z3FB'}, [3 2]; ...
    'Legacy Position', 10:15, {'Z1', 'Z2', 'Z3', 'H1', 'H2', 'H3'}, [3 2]; ...
    'Legacy Stage FF', 16:19, {'Xpos', 'Xacc', 'Ypos', 'Yacc'}, [2 2]; ...
    'Legacy Valve Output', 20:22, {'Value V1', 'Value V2', 'Value V3'}, [3 1]; ...
    'Legacy Motor Output', 23:28, {'Y1 Motor', 'Z1 Motor', 'X2 Motor', 'Z2 Motor', 'Y3 Motor', 'Z3 Motor'}, [3 2]; ...
    'Legacy Motor Temperature', 29:34, {'Y1 Temp', 'Z1 Temp', 'X2 Temp', 'Z2 Temp', 'Y3 Temp', 'Z3 Temp'}, [3 2]};
for i = 1:size(defs, 1)
    groups = appendGroup(groups, defs{i, 1}, defs{i, 2}, defs{i, 3}, defs{i, 4});
end
end

function groups = appendLegacy55Groups(groups)
defs = { ...
    'Legacy Floor FF', 1:3, {'XFF', 'YFF', 'ZFF'}, [3 1]; ...
    'Legacy Table ACC', 4:9, {'V1ACC', 'V2ACC', 'V3ACC', 'H1ACC', 'H2ACC', 'H3ACC'}, [3 2]; ...
    'Legacy Position', 10:17, {'V1', 'V2', 'V3', 'V4', 'H1', 'H2', 'H3', 'H4'}, [4 2]; ...
    'Legacy FFACC', 18:21, {'Xpos', 'Xacc', 'Ypos', 'Yacc'}, [2 2]; ...
    'Legacy Valve 1', 22:25, {'VALVE1-V1V2', 'VALVE1-V3V4', 'VALVE1-X1X2', 'VALVE1-Y1Y2'}, [2 2]; ...
    'Legacy Valve 2', 26:29, {'VALVE2-V1V2', 'VALVE2-V3V4', 'VALVE2-X1X2', 'VALVE2-Y1Y2'}, [2 2]; ...
    'Legacy Valve 3', 30:33, {'VALVE3-V1V2', 'VALVE3-V3V4', 'VALVE3-X1X2', 'VALVE3-Y1Y2'}, [2 2]; ...
    'Legacy Valve 4', 34:37, {'VALVE4-V1V2', 'VALVE4-V3V4', 'VALVE4-X1X2', 'VALVE4-Y1Y2'}, [2 2]; ...
    'Legacy Motor Force', [38 40 42 44], {'MOTOR V1', 'MOTOR V2', 'MOTOR V3', 'MOTOR V4'}, [2 2]; ...
    'Legacy Motor Temperature', 46:53, {'Temp V1', 'Temp Y1', 'Temp V2', 'Temp X2', 'Temp V3', 'Temp Y3', 'Temp V4', 'Temp X4'}, [4 2]};
for i = 1:size(defs, 1)
    validIdx = defs{i, 2};
    validIdx = validIdx(validIdx >= 1 & validIdx <= 55);
    groups = appendGroup(groups, defs{i, 1}, validIdx, defs{i, 3}(1:numel(validIdx)), defs{i, 4});
end
end

function groups = appendGroup(groups, groupName, idx, names, layout)
if isempty(idx)
    return;
end
G = struct();
G.name = groupName;
G.columnIdx = idx(:).';
G.displayNames = names(:).';
G.layout = layout;
groups(end + 1) = G; %#ok<AGROW>
end

function groups = appendGroupIfMissing(groups, groupName, idx, names, layout)
for i = 1:numel(groups)
    if strcmp(groups(i).name, groupName)
        return;
    end
    if isequal(groups(i).columnIdx, idx(:).')
        return;
    end
end
groups = appendGroup(groups, groupName, idx, names, layout);
end

function layout = chooseTightGrid(n)
if n <= 0
    layout = [1 1];
    return;
end
cols = ceil(sqrt(n));
rows = ceil(n / cols);
layout = [rows cols];
end

function profile = classifyLegacyLogProfile(nCols)
if nCols == 34
    profile = 'legacy34';
elseif nCols == 55
    profile = 'legacy55';
else
    profile = 'generic';
end
end

function label = makeAnalysisFileLabel(F)
if strcmp(F.type, 'freq')
    label = sprintf('[FR] %s | Update=%g | FsNum=%g', F.displayName, F.update, F.fsNumerator);
else
    label = sprintf('[LOG] %s | Ch=%d', F.displayName, size(F.dataMatrix, 2));
end
end

function summary = summarizeSelectedFiles(files, selectedIds)
if isempty(files)
    summary = 'No file loaded';
    return;
end
sel = filesByIds(files, selectedIds);
if isempty(sel)
    sel = files(1);
end
names = cell(1, numel(sel));
for i = 1:numel(sel)
    names{i} = sel{i}.displayName;
end
if numel(names) <= 2
    summary = strjoin(names, ', ');
else
    summary = sprintf('%s and %d more', names{1}, numel(names) - 1);
end
end

function sel = filesByIds(files, ids)
sel = {};
for i = 1:numel(files)
    if any(files{i}.id == ids)
        sel{end + 1} = files{i}; %#ok<AGROW>
    end
end
end

function idx = findFilesByIdsAndType(files, ids, typeName)
idx = [];
for i = 1:numel(files)
    if any(files{i}.id == ids) && strcmp(files{i}.type, typeName)
        idx(end + 1) = i; %#ok<AGROW>
    end
end
end

function idx = findFilesByType(files, typeName)
idx = [];
for i = 1:numel(files)
    if strcmp(files{i}.type, typeName)
        idx(end + 1) = i; %#ok<AGROW>
    end
end
end

function labels = collectFrequencyPairLabels(files, freqIdx)
labels = {};
for i = 1:numel(freqIdx)
    F = files{freqIdx(i)};
    for k = 1:numel(F.pairs)
        if ~any(strcmp(labels, F.pairs(k).label))
            labels{end + 1} = F.pairs(k).label; %#ok<AGROW>
        end
    end
end
end

function idx = findPairIndexByLabel(F, pairLabel)
idx = 0;
for i = 1:numel(F.pairs)
    if strcmp(F.pairs(i).label, pairLabel)
        idx = i;
        return;
    end
end
end

function [F, note] = getCurrentLogFile(files, selectedIds)
F = [];
note = '';
sel = filesByIds(files, selectedIds);
selLog = {};
for i = 1:numel(sel)
    if strcmp(sel{i}.type, 'log')
        selLog{end + 1} = sel{i}; %#ok<AGROW>
    end
end
if isempty(selLog)
    for i = 1:numel(files)
        if strcmp(files{i}.type, 'log')
            F = files{i};
            return;
        end
    end
    return;
end
F = selLog{1};
if numel(selLog) > 1
    note = 'multiple log files selected, using the first one';
end
end

function G = getSelectedLogGroup(F, hPopup)
G = [];
visGroups = getVisibleLogGroups(F);
if isempty(F) || isempty(visGroups)
    return;
end
name = getPopupSelectedString(hPopup);
for i = 1:numel(visGroups)
    if strcmp(visGroups(i).name, name)
        G = visGroups(i);
        return;
    end
end
G = visGroups(1);
end

function F = getFileById(files, fileId)
F = [];
for i = 1:numel(files)
    if files{i}.id == fileId
        F = files{i};
        return;
    end
end
end

function items = getControlItemsCompat(h)
raw = get(h, 'String');
if ischar(raw)
    items = cellstr(raw);
elseif iscell(raw)
    items = raw;
else
    items = {'(none)'};
end
if isempty(items)
    items = {'(none)'};
end
end

function txt = getPopupSelectedString(h)
items = getControlItemsCompat(h);
value = get(h, 'Value');
value = max(1, min(numel(items), value));
txt = items{value};
end

function setPopupItemsCompat(h, items, preferred)
if isempty(items)
    items = {'(none)'};
end
value = 1;
if nargin >= 3 && ~isempty(preferred)
    idx = find(strcmp(items, preferred), 1, 'first');
    if ~isempty(idx)
        value = idx;
    end
end
set(h, 'String', items, 'Value', value);
end

function idx = getListSelectionIndices(h, nItems)
idx = get(h, 'Value');
if isempty(idx)
    idx = [];
    return;
end
idx = idx(:).';
idx = idx(idx >= 1 & idx <= nItems);
end

function idx = mapIdsToIndices(ids, selectedIds)
idx = [];
for i = 1:numel(selectedIds)
    hit = find(ids == selectedIds(i), 1, 'first');
    if ~isempty(hit)
        idx(end + 1) = hit; %#ok<AGROW>
    end
end
idx = unique(idx, 'stable');
end

function idx = mapNamesToIndices(names, selectedNames)
idx = [];
for i = 1:numel(selectedNames)
    hit = find(strcmp(names, selectedNames{i}), 1, 'first');
    if ~isempty(hit)
        idx(end + 1) = hit; %#ok<AGROW>
    end
end
idx = unique(idx, 'stable');
end

function clearAxisAndLegend(ax)
cla(ax);
legend(ax, 'off');
end

function cloneAxisToFigure(sourceAx, fallbackTitle)
hFig = figure('Name', fallbackTitle, 'NumberTitle', 'off', 'Color', 'w');
newAx = axes('Parent', hFig, 'Units', 'normalized', ...
    'Position', [0.13 0.11 0.775 0.815], 'Box', 'on');
copyAxisState(sourceAx, newAx);
end

function copyAxisState(sourceAx, targetAx)
cla(targetAx);
srcChildren = flipud(get(sourceAx, 'Children'));
for i = 1:numel(srcChildren)
    copyobj(srcChildren(i), targetAx);
end
set(targetAx, 'XScale', get(sourceAx, 'XScale'));
set(targetAx, 'YScale', get(sourceAx, 'YScale'));
set(targetAx, 'XLimMode', get(sourceAx, 'XLimMode'));
set(targetAx, 'YLimMode', get(sourceAx, 'YLimMode'));
if strcmp(get(sourceAx, 'XLimMode'), 'manual')
    set(targetAx, 'XLim', get(sourceAx, 'XLim'));
end
if strcmp(get(sourceAx, 'YLimMode'), 'manual')
    set(targetAx, 'YLim', get(sourceAx, 'YLim'));
end
grid(targetAx, get(sourceAx, 'XGrid'));
title(targetAx, getTitleStringCompat(get(get(sourceAx, 'Title'), 'String')), 'Interpreter', 'none');
xlabel(targetAx, getTitleStringCompat(get(get(sourceAx, 'XLabel'), 'String')), 'Interpreter', 'none');
ylabel(targetAx, getTitleStringCompat(get(get(sourceAx, 'YLabel'), 'String')), 'Interpreter', 'none');
legend(targetAx, 'show', 'Location', 'northeast');
end

function txt = getTitleStringCompat(raw)
if iscell(raw)
    txt = strjoin(raw, ' ');
elseif ischar(raw)
    txt = raw;
else
    txt = '';
end
end

function showAlertCompat(figHandle, msg, ttl)
try
    errordlg(msg, ttl, 'modal');
catch
    try
        warndlg(msg, ttl, 'modal');
    catch
        disp(msg);
    end
end
if ishghandle(figHandle)
    figure(figHandle);
end
end

function tf = isCurrentTab(tabGroup, tabObj)
tf = false;
try
    tf = isequal(get(tabGroup, 'SelectedTab'), tabObj);
catch
    try
        tf = isequal(get(tabGroup, 'SelectedTab'), tabObj);
    catch
    end
end
end
