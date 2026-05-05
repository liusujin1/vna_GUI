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
    'Enable', 'off', ...
    'Callback', @onApplyFsNumerator);
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
    'Units', 'pixels', 'Position', [15 362 330 148]);
lblFreqPlotMode = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', 'Plot Mode:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 112 60 20]);
ddFreqPlotMode = uicontrol('Parent', grpFreq, 'Style', 'popupmenu', ...
    'String', {'Overlay', 'Subplots'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [76 110 234 24], ...
    'Callback', @onFreqPlotModeChanged);
lblFreqXAxis = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', 'X Axis:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 84 50 20], ...
    'Visible', 'off');
ddFreqXAxis = uicontrol('Parent', grpFreq, 'Style', 'popupmenu', ...
    'String', {'Sample Index', 'Time (s)'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [76 82 234 24], ...
    'Visible', 'off', ...
    'Callback', @onFreqXAxisChanged);
lblFreqChannels = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', 'Channels:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 56 55 20]);
lstFreqPairs = uicontrol('Parent', grpFreq, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [12 12 298 42], ...
    'Callback', @onFreqChannelsChanged);
lblFreqInfo = uicontrol('Parent', grpFreq, 'Style', 'text', ...
    'String', '', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 132 300 1], ...
    'Visible', 'off');

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
tabFreq = uitab('Parent', tabGroup, 'Title', 'IVSR Analysis');
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
    'String', 'Selected frequency channels', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 785 480 20]);
btnMagFigure = uicontrol('Parent', tabFreq, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [910 782 60 26]);
btnPhaseFigure = uicontrol('Parent', tabFreq, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [910 387 60 26]);

pnlMagArea = uipanel('Parent', tabFreq, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 435 1010 330]);
axMag = createFrequencyHostAxis(pnlMagArea, 'Magnitude (dB)', 'Magnitude (dB)');

pnlPhaseArea = uipanel('Parent', tabFreq, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 40 1010 330]);
axPhase = createFrequencyHostAxis(pnlPhaseArea, 'Phase (deg)', 'Phase (deg)');
set(btnMagFigure, 'Callback', @(~, ~) onOpenCurrentFrequencyViewFigure('mag'));
set(btnPhaseFigure, 'Callback', @(~, ~) onOpenCurrentFrequencyViewFigure('phase'));

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
        [~, freqIdx] = getCurrentFrequencySelection(app.files, getSelectedFileIds());
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
        if hasSelectedFrequencyFile()
            if app.holdPlots
                app.holdPlots = false;
                setApp(app);
                set(btnHold, 'Value', 0, 'String', 'Hold: Off');
                updateHoldControlState();
            end
            plotFrequencyPage();
        end
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

    function onFreqPlotModeChanged(~, ~)
        app = getApp();
        app.freqPlotMode = getPopupSelectedString(ddFreqPlotMode);
        if strcmp(app.freqPlotMode, 'Subplots')
            app.holdPlots = false;
            set(btnHold, 'Value', 0, 'String', 'Hold: Off');
        end
        setApp(app);
        updateHoldControlState();
        autoPlotCurrentSelection();
    end

    function onFreqChannelsChanged(~, ~)
        autoPlotCurrentSelection();
    end

    function onFreqXAxisChanged(~, ~)
        app = getApp();
        app.freqXAxisMode = getPopupSelectedString(ddFreqXAxis);
        setApp(app);
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
        clearFrequencyRenderArea(true);
        clearLogRenderArea(true);
        app = getApp();
        app.lastFreqRender = [];
        app.lastLogRender = [];
        setApp(app);
        setStatus('Status: cleared all plots.');
    end

    function onOpenCurrentLogViewFigure(~, ~)
        app = getApp();
        if isempty(app.lastLogRender)
            setStatus('Status: no current log view to open.');
            return;
        end
        renderCurrentLogViewInFigure(app.lastLogRender);
    end

    function onOpenCurrentFrequencyViewFigure(viewKind)
        app = getApp();
        if isempty(app.lastFreqRender)
            setStatus('Status: no current frequency view to open.');
            return;
        end
        renderCurrentFrequencyViewInFigure(app.lastFreqRender, viewKind);
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

        statusY = 18;
        statusH = 78;
        actionY = statusY + statusH + 12;
        actionW = floor((contentW - 2 * btnGap) / 3);
        set(btnPlot, 'Position', [xPad actionY actionW rowH]);
        set(btnDemean, 'Position', [xPad + actionW + btnGap actionY actionW rowH]);
        set(btnHold, 'Position', [xPad + 2 * (actionW + btnGap) actionY actionW rowH]);
        set(lblStatus, 'Position', [xPad statusY contentW statusH]);

        sharedBottom = actionY + rowH + 14;
        sharedTop = fsRowY - 64;
        sharedH = max(160, sharedTop - sharedBottom);
        set(grpFreq, 'Position', [xPad sharedBottom contentW sharedH]);
        set(grpLog, 'Position', [xPad sharedBottom contentW sharedH]);

        freqH = sharedH;
        set(lblFreqPlotMode, 'Position', [12 freqH - 44 60 16]);
        set(ddFreqPlotMode, 'Position', [76 freqH - 46 contentW - 86 21]);
        set(lblFreqXAxis, 'Position', [12 freqH - 72 50 16]);
        set(ddFreqXAxis, 'Position', [76 freqH - 74 contentW - 86 21]);
        set(lblFreqChannels, 'Position', [12 freqH - 100 55 16]);
        set(lstFreqPairs, 'Position', [12 12 contentW - 20 max(42, freqH - 114)]);

        logH = sharedH;

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
        axW = tw - 60;
        freqAreaY = bottomMargin;
        freqAreaH = th - topMargin - bottomMargin;
        [freqModeName, ~] = getCurrentFrequencySelection(getApp().files, getSelectedFileIds());
        if strcmp(freqModeName, 'signal')
            set(pnlMagArea, 'Position', [24 freqAreaY axW freqAreaH], 'Visible', 'on');
            set(pnlPhaseArea, 'Position', [24 0 1 1], 'Visible', 'off');
            set(btnPhaseFigure, 'Position', [tw - rightInset figBtnY figBtnW 26], 'Enable', 'off');
        elseif strcmp(getPopupSelectedString(ddFreqPlotMode), 'Subplots')
            set(pnlMagArea, 'Position', [24 freqAreaY axW freqAreaH], 'Visible', 'on');
            set(pnlPhaseArea, 'Position', [24 0 1 1], 'Visible', 'off');
            set(btnPhaseFigure, 'Position', [tw - rightInset figBtnY figBtnW 26], 'Enable', 'on');
        else
            usableH = freqAreaH - midGap;
            axH = max(250, floor(usableH / 2));
            phaseY = bottomMargin;
            magY = phaseY + axH + midGap;
            set(pnlMagArea, 'Position', [24 magY axW axH], 'Visible', 'on');
            set(pnlPhaseArea, 'Position', [24 phaseY axW axH], 'Visible', 'on');
            set(btnPhaseFigure, 'Position', [tw - rightInset phaseY + axH + 16 figBtnW 26], 'Enable', 'on');
        end
        set(lblLogSelected, 'Position', [24 topLabelY tw - 190 18]);
        set(lblLogContext, 'Position', [24 topLabelY - 18 tw - 190 16]);
        set(btnLogFigure, 'Position', [tw - rightInset figBtnY figBtnW 26]);
        set(pnlLogArea, 'Position', [20 45 axW th - 132]);
        layoutFrequencyAxes();
        layoutLogAxes();
    end

    function plotFrequencyPage()
        app = getApp();
        [freqMode, freqIdx, freqNote] = getCurrentFrequencySelection(app.files, getSelectedFileIds());
        if isempty(freqIdx)
            setStatus('Status: select one or more frequency files first.');
            return;
        end
        onResize();
        if strcmp(freqMode, 'signal')
            renderIvsaSignalPage(freqIdx, freqNote);
            return;
        end

        pairLabels = getSelectedFrequencyPairLabels(app.files, freqIdx, lstFreqPairs);
        if isempty(pairLabels)
            pairLabels = collectFrequencyPairLabels(app.files, freqIdx);
        end
        if isempty(pairLabels)
            setStatus('Status: no available channel pairs for the selected frequency files.');
            return;
        end

        [freqRender, plotted, skipped] = collectFrequencyRenderData(app.files, freqIdx, pairLabels);
        if strcmp(app.freqPlotMode, 'Subplots')
            renderFrequencySubplots(freqRender);
        else
            renderFrequencyOverlay(freqRender);
        end
        app = getApp();
        app.lastFreqRender = struct( ...
            'mode', app.freqPlotMode, ...
            'fileIds', cellfun(@(F) F.id, app.files(freqIdx)), ...
            'pairLabels', {pairLabels}, ...
            'layout', chooseTightGrid(numel(pairLabels)), ...
            'summary', summarizeFrequencySelection(pairLabels, numel(freqIdx)));
        setApp(app);

        if isempty(skipped)
            setStatus(sprintf('Status: plotted %d frequency curve set(s) for %d channel(s).', plotted, numel(pairLabels)));
        else
            setStatus(sprintf('Status: plotted %d frequency curve set(s), skipped %d.', plotted, numel(skipped)));
        end
    end

    function renderIvsaSignalPage(freqIdx, freqNote)
        app = getApp();
        F = app.files{freqIdx(1)};
        labels = getSelectedIvsaSignalLabels(app.files, freqIdx, lstFreqPairs);
        if isempty(labels)
            labels = collectIvsaSignalSelectionItems(app.files, freqIdx);
        end
        if isempty(labels) || (numel(labels) == 1 && strcmp(labels{1}, '(none)'))
            setStatus('Status: no available signal channels for the selected file.');
            return;
        end
        [xData, Y, names, groupName, xLabelText] = buildIvsaSignalPlotData(F, labels, app.freqXAxisMode);
        if isempty(Y)
            setStatus('Status: no plottable signal channels were selected.');
            return;
        end
        if strcmp(app.freqPlotMode, 'Subplots')
            clearFrequencyRenderArea(false);
            axMag = [];
            axPhase = [];
            layout = chooseTightGrid(size(Y, 2));
            renderSignalSubplotGridToParent(pnlMagArea, xData, Y, names, layout, groupName, xLabelText);
        else
            clearFrequencyRenderArea(false);
            axMag = createSignalHostAxis(pnlMagArea, F.displayName, xLabelText);
            axPhase = [];
            hold(axMag, 'on');
            for i = 1:size(Y, 2)
                plot(axMag, xData, Y(:, i), 'LineWidth', 1.0, 'DisplayName', names{i});
            end
            hold(axMag, 'off');
            grid(axMag, 'on');
            xlabel(axMag, xLabelText);
            ylabel(axMag, 'Value');
            applySignalXLimits(axMag, xData);
            title(axMag, F.displayName, 'Interpreter', 'none');
            legend(axMag, 'show', 'Location', 'northeast');
        end
        app = getApp();
        app.lastFreqRender = struct( ...
            'kind', 'signal', ...
            'mode', app.freqPlotMode, ...
            'fileIds', F.id, ...
            'fileName', F.displayName, ...
            'signalKind', F.signalKind, ...
            'selectedLabels', {labels}, ...
            'displayNames', {names}, ...
            'layout', chooseTightGrid(size(Y, 2)), ...
            'groupName', groupName, ...
            'xAxisMode', app.freqXAxisMode, ...
            'summary', summarizeFrequencySelection(labels, 1));
        setApp(app);
        if isempty(freqNote)
            setStatus(sprintf('Status: plotted %d signal channel(s) from %s in %s mode.', size(Y, 2), F.displayName, lower(app.freqPlotMode)));
        else
            setStatus(sprintf('Status: plotted %d signal channel(s) from %s in %s mode (%s).', size(Y, 2), F.displayName, lower(app.freqPlotMode), freqNote));
        end
    end

    function renderFrequencyOverlay(freqRender)
        app = getApp();
        hasOverlayView = isstruct(app.lastFreqRender) && isfield(app.lastFreqRender, 'mode') && strcmp(app.lastFreqRender.mode, 'Overlay');
        if ~app.holdPlots || isempty(axMag) || ~ishghandle(axMag) || ~hasOverlayView
            clearFrequencyRenderArea(false);
            axMag = createFrequencyHostAxis(pnlMagArea, 'Magnitude (dB)', 'Magnitude (dB)');
            axPhase = createFrequencyHostAxis(pnlPhaseArea, 'Phase (deg)', 'Phase (deg)');
        end
        hold(axMag, 'on');
        hold(axPhase, 'on');
        xMin = inf;
        xMax = -inf;
        for i = 1:numel(freqRender)
            for j = 1:numel(freqRender(i).curves)
                C = freqRender(i).curves(j);
                semilogx(axMag, C.freq, C.magDb, 'LineWidth', 1.1, 'DisplayName', C.displayName);
                semilogx(axPhase, C.freq, C.phaseDeg, 'LineWidth', 1.1, 'DisplayName', C.displayName);
                xMin = min(xMin, min(C.freq));
                xMax = max(xMax, max(C.freq));
            end
        end
        hold(axMag, 'off');
        hold(axPhase, 'off');
        title(axMag, 'Magnitude (dB)', 'Interpreter', 'none');
        title(axPhase, 'Phase (deg)', 'Interpreter', 'none');
        applyFrequencyOverlayAxisStyle(axMag, xMin, xMax, 'Magnitude (dB)');
        applyFrequencyOverlayAxisStyle(axPhase, xMin, xMax, 'Phase (deg)');
    end

    function renderFrequencySubplots(freqRender)
        clearFrequencyRenderArea(false);
        axMag = [];
        axPhase = [];
        if isempty(freqRender)
            return;
        end
        layout = chooseTightGrid(numel(freqRender));
        renderFrequencyGridToParent(pnlMagArea, freqRender, layout, 'mag');
        renderFrequencyGridToParent(pnlPhaseArea, freqRender, layout, 'phase');
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

    function renderCurrentFrequencyViewInFigure(renderInfo, viewKind)
        app = getApp();
        if isfield(renderInfo, 'kind') && strcmp(renderInfo.kind, 'signal')
            F = getFileById(app.files, renderInfo.fileIds(1));
            if isempty(F)
                setStatus('Status: source signal file is no longer loaded.');
                return;
            end
            [xData, Y, names, groupName, xLabelText] = buildIvsaSignalPlotData(F, renderInfo.selectedLabels, renderInfo.xAxisMode);
            hFig = figure('Name', sprintf('Signal View - %s', renderInfo.fileName), ...
                'NumberTitle', 'off', 'Color', 'w');
            if strcmp(renderInfo.mode, 'Subplots')
                renderSignalSubplotGridToFigure(hFig, xData, Y, names, renderInfo.layout, renderInfo.fileName, groupName, xLabelText);
            else
                ax = axes('Parent', hFig, 'Units', 'normalized', ...
                    'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
                for i = 1:size(Y, 2)
                    plot(ax, xData, Y(:, i), 'LineWidth', 1.0, 'DisplayName', names{i});
                    hold(ax, 'on');
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, xLabelText);
                ylabel(ax, 'Value');
                applySignalXLimits(ax, xData);
                title(ax, renderInfo.fileName, 'Interpreter', 'none');
                legend(ax, 'show', 'Location', 'northeast');
            end
            return;
        end
        freqIdx = findFilesByIdsAndType(app.files, renderInfo.fileIds, 'freq');
        if isempty(freqIdx)
            setStatus('Status: source frequency files are no longer loaded.');
            return;
        end
        freqRender = collectFrequencyRenderData(app.files, freqIdx, renderInfo.pairLabels);
        hFig = figure('Name', sprintf('Frequency %s - %s', upper(viewKind), renderInfo.summary), ...
            'NumberTitle', 'off', 'Color', 'w');
        if strcmp(renderInfo.mode, 'Subplots')
            renderFrequencyGridToFigure(hFig, freqRender, renderInfo.layout, viewKind);
        else
            ax = axes('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
            renderFrequencyOverlayToAxis(ax, freqRender, viewKind);
        end
    end

    function clearFrequencyRenderArea(showPlaceholder)
        if nargin < 1
            showPlaceholder = false;
        end
        delete(findall(pnlMagArea, 'Type', 'axes'));
        delete(findall(pnlPhaseArea, 'Type', 'axes'));
        axMag = [];
        axPhase = [];
        if showPlaceholder
            axMag = createFrequencyHostAxis(pnlMagArea, 'Magnitude (dB)', 'Magnitude (dB)');
            axPhase = createFrequencyHostAxis(pnlPhaseArea, 'Phase (deg)', 'Phase (deg)');
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

    function layoutFrequencyAxes()
        app = getApp();
        layoutFrequencyAreaAxes(pnlMagArea, app.lastFreqRender);
        layoutFrequencyAreaAxes(pnlPhaseArea, app.lastFreqRender);
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
        [~, freqIdx] = getCurrentFrequencySelection(app.files, selIds);
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
        refreshFrequencyPairSelection([]);
        refreshLogPresetItems();
        refreshLogChannelSelection([]);
        updateLogRangeControls();
        updateTabControlVisibility();
        updateTabSummaries();
        setPopupItemsCompat(ddFreqPlotMode, {'Overlay', 'Subplots'}, app.freqPlotMode);
        setPopupItemsCompat(ddFreqXAxis, {'Sample Index', 'Time (s)'}, app.freqXAxisMode);
        setPopupItemsCompat(ddPlotMode, {'Subplots', 'Overlay'}, app.logPlotMode);
        updateFrequencyControlVisibility();
        updateHoldControlState();
        updateDemeanControlState();
    end

    function refreshFrequencyPairItems()
        app = getApp();
        [freqMode, freqIdx] = getCurrentFrequencySelection(app.files, getSelectedFileIds());
        if strcmp(freqMode, 'frf')
            items = collectFrequencyPairLabels(app.files, freqIdx);
        elseif strcmp(freqMode, 'signal')
            items = collectIvsaSignalSelectionItems(app.files, freqIdx);
        else
            items = {};
        end
        if isempty(items)
            items = {'(none)'};
        end
        set(lstFreqPairs, 'String', items);
    end

    function refreshFrequencyPairSelection(preferredNames)
        if nargin < 1
            preferredNames = [];
        end
        items = getListboxItems(lstFreqPairs);
        if isempty(items) || (numel(items) == 1 && strcmp(items{1}, '(none)'))
            set(lstFreqPairs, 'Value', 1);
            return;
        end
        if isempty(preferredNames)
            value = 1:numel(items);
        else
            value = mapNamesToIndices(items, preferredNames);
            if isempty(value)
                value = 1:numel(items);
            end
        end
        set(lstFreqPairs, 'Value', value);
    end

    function refreshLogPresetItems()
        app = getApp();
        [F, note] = getCurrentLogFile(app.files, getSelectedFileIds());
        prev = getPopupSelectedString(ddPreset);
        if isempty(F)
            setPopupItemsCompat(ddPreset, {'(none)'}, '(none)');
            set(lblLogSelected, 'String', 'Active log file: (none)');
            set(lblLogContext, 'String', 'Category / preset / mode');
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
        updateFrequencyControlVisibility();
        updateHoldControlState();
        updateDemeanControlState();
    end

    function updateTabSummaries()
        app = getApp();
        selIds = getSelectedFileIds();
        [freqMode, freqIdx, freqNote] = getCurrentFrequencySelection(app.files, selIds);
        if isempty(freqIdx)
            set(lblFreqSelected, 'String', 'Selected frequency channels: (no frequency files selected)');
        elseif strcmp(freqMode, 'frf')
            pairLabels = getSelectedFrequencyPairLabels(app.files, freqIdx, lstFreqPairs);
            if isempty(pairLabels)
                pairLabels = collectFrequencyPairLabels(app.files, freqIdx);
            end
            set(lblFreqSelected, 'String', sprintf('Selected frequency channels: %s | mode: %s | files: %d', ...
                summarizeFrequencySelection(pairLabels), app.freqPlotMode, numel(freqIdx)));
        else
            labels = getSelectedIvsaSignalLabels(app.files, freqIdx, lstFreqPairs);
            if isempty(labels)
                labels = collectIvsaSignalSelectionItems(app.files, freqIdx);
            end
            txt = sprintf('Selected signal channels: %s | mode: %s | x-axis: %s | files: %d', ...
                summarizeFrequencySelection(labels), app.freqPlotMode, app.freqXAxisMode, numel(freqIdx));
            if ~isempty(freqNote)
                txt = sprintf('%s (%s)', txt, freqNote);
            end
            set(lblFreqSelected, 'String', txt);
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
        [freqMode, ~] = getCurrentFrequencySelection(app.files, getSelectedFileIds());
        isFreqSubplots = strcmp(app.activeTab, 'freq') && strcmp(getPopupSelectedString(ddFreqPlotMode), 'Subplots');
        isFreqSignal = strcmp(app.activeTab, 'freq') && strcmp(freqMode, 'signal');
        isLogSubplots = strcmp(app.activeTab, 'log') && strcmp(getPopupSelectedString(ddPlotMode), 'Subplots');
        if isFreqSubplots || isLogSubplots || isFreqSignal
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

    function updateFrequencyControlVisibility()
        [freqMode, ~] = getCurrentFrequencySelection(getApp().files, getSelectedFileIds());
        isSignal = strcmp(freqMode, 'signal');
        set(lblFreqXAxis, 'Visible', ternaryText(isSignal, 'on', 'off'));
        set(ddFreqXAxis, 'Visible', ternaryText(isSignal, 'on', 'off'));
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
        [~, freqIdx] = getCurrentFrequencySelection(getApp().files, getSelectedFileIds());
        tf = ~isempty(freqIdx);
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
app.freqPlotMode = 'Overlay';
app.freqXAxisMode = 'Sample Index';
app.logPlotMode = 'Subplots';
app.logDemean = false;
app.logRangeFileId = 0;
app.lastFreqRender = [];
app.lastLogRender = [];
end

function F = loadOneAnalysisFile(filePath)
[~, fileName, ext] = fileparts(filePath);
ext = lower(ext);
if ~ismember(ext, {'.dat', '.txt', '.csv'})
    error('Unsupported file type: %s', ext);
end

scanLines = readTextLinesCompat(filePath, 256);
signalKind = detectIvsaSignalKind(scanLines, fileName);
kind = detectAnalysisFileType(scanLines, fileName);
switch kind
    case 'ivsa_signal'
        lines = readTextLinesCompat(filePath);
        F = parseIvsaSignalAnalysisFile(filePath, lines, signalKind);
    case 'freq'
        lines = readTextLinesCompat(filePath);
        F = parseFrequencyAnalysisFile(filePath, lines);
    case 'log'
        F = parseWideLogAnalysisFile(filePath, scanLines);
    otherwise
        error('Unsupported analysis file type.');
end

F.filePath = filePath;
F.fileName = [fileName, ext];
F.displayName = F.fileName;
end

function kind = detectAnalysisFileType(lines, fileName)
kind = 'log';
signalKind = detectIvsaSignalKind(lines, fileName);
if ~isempty(signalKind)
    kind = 'ivsa_signal';
    return;
end
hasUpdate = false;
has12NumericLine = false;
maxScan = min(numel(lines), 60);
for i = 1:maxScan
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    if ~isempty(regexpi(line, '^\s*Update(?:\s+Rate)?\s*:', 'once'))
        hasUpdate = true;
    end
    [~, ok] = parseFixedNumericLine(line, 12);
    if ok
        has12NumericLine = true;
    end
end
if hasUpdate && has12NumericLine
    kind = 'freq';
elseif ~isempty(regexpi(fileName, '^IVH[FS]A?_', 'once'))
    kind = 'freq';
end
end

function signalKind = detectIvsaSignalKind(lines, fileName)
signalKind = '';
nameLower = lower(fileName);
for i = 1:min(numel(lines), 24)
    s = strtrim(lines{i});
    if isempty(s)
        continue;
    end
    if contains(lower(s), 'sine test')
        signalKind = 'sine';
        return;
    end
    if contains(lower(s), 'feedforward signal test')
        signalKind = 'sff';
        return;
    end
    toks = tokenizeWhitespace(s);
    if numel(toks) >= 6 && any(contains(lower(toks), '_prox')) && any(contains(lower(toks), '_geo')) && any(contains(lower(toks), '_noise'))
        signalKind = 'sine';
        return;
    end
    if numel(toks) >= 4 && any(strcmpi(toks, 'X_Acc[um/s^2]')) && any(strcmpi(toks, 'Y_Position[um]'))
        signalKind = 'sff';
        return;
    end
end
if contains(nameLower, '_sine_')
    signalKind = 'sine';
elseif contains(nameLower, '_sff_')
    signalKind = 'sff';
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
        if isnan(v)
            v = parseHeaderScalar(line, 'Update Rate');
        end
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

function F = parseIvsaSignalAnalysisFile(~, lines, signalKind)
dataStart = 0;
update = NaN;
samples = NaN;
nCols = NaN;
headerTokens = {};

for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    if isnan(update)
        v = parseHeaderScalar(line, 'Update');
        if isnan(v)
            v = parseHeaderScalar(line, 'Update Rate');
        end
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
    [row, ok] = parseAnyNumericLine(line);
    if ok
        dataStart = i;
        nCols = numel(row);
        break;
    end
end

if dataStart < 1 || ~isfinite(nCols) || nCols < 1
    error('No numeric signal block found.');
end
if ~isfinite(update) || update <= 0
    error('Cannot find a valid Update value in file header.');
end

for i = dataStart - 1:-1:1
    toks = tokenizeWhitespace(lines{i});
    if numel(toks) >= nCols && sum(cellfun(@containsLetterCompat, toks(1:nCols))) >= max(2, floor(nCols / 2))
        headerTokens = toks(1:nCols);
        break;
    end
end
if isempty(headerTokens)
    headerTokens = createGenericHeaders(nCols);
end

data = zeros(0, nCols);
for i = dataStart:numel(lines)
    [row, ok] = parseFixedNumericLine(lines{i}, nCols);
    if ok
        data(end + 1, :) = row; %#ok<AGROW>
    end
end
if isempty(data)
    error('Signal data block is empty.');
end

if strcmp(signalKind, 'sine')
    [axisGroups, channelDefs] = buildIvsaSineSignalDefs(headerTokens);
else
    [axisGroups, channelDefs] = buildIvsaSffSignalDefs(headerTokens);
end

F = struct();
F.type = 'ivsa_signal';
F.signalKind = signalKind;
F.update = update;
F.samples = samples;
F.dataMatrix = data;
F.headerNames = headerTokens;
F.sampleIndex = (1:size(data, 1))';
F.axisGroups = axisGroups;
F.channelDefs = channelDefs;
F.fsNumerator = 5000;
F.fs = F.fsNumerator / F.update;
end

function F = parseWideLogAnalysisFile(filePath, lines)
scan = locateWideLogStructure(lines);
if ~scan.ok
    fullLines = readTextLinesCompat(filePath);
    scan = locateWideLogStructure(fullLines);
else
    fullLines = {};
end
if ~scan.ok
    error('Cannot find numeric log rows.');
end

nNumeric = scan.nNumeric;
dataStart = scan.dataStart;
rawHeaderNames = scan.rawHeaderNames;
headerNames = normalizeHeaderNames(rawHeaderNames, nNumeric);

[timeText, data, fastOk] = readWideLogDataBlockFast(filePath, dataStart, nNumeric);
if ~fastOk
    if isempty(fullLines)
        fullLines = readTextLinesCompat(filePath);
    end
    [timeText, data] = readWideLogDataBlockSlow(fullLines, dataStart, nNumeric);
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

function scan = locateWideLogStructure(lines)
scan = struct('ok', false, 'headerIdx', 0, 'dataStart', 0, 'nNumeric', NaN, 'rawHeaderNames', {{}});
headerIdx = findFirstNonEmptyLine(lines);
if headerIdx < 1
    return;
end

[~, firstNums, firstIsData] = parseWideDataLine(lines{headerIdx}, []);
if firstIsData
    scan.ok = true;
    scan.headerIdx = headerIdx;
    scan.dataStart = headerIdx;
    scan.nNumeric = numel(firstNums);
    scan.rawHeaderNames = createGenericHeaders(scan.nNumeric);
    return;
end

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
    return;
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

scan.ok = true;
scan.headerIdx = headerIdx;
scan.dataStart = dataStart;
scan.nNumeric = nNumeric;
scan.rawHeaderNames = rawHeaderNames;
end

function [timeText, data, ok] = readWideLogDataBlockFast(filePath, dataStart, nNumeric)
timeText = {};
data = zeros(0, nNumeric);
ok = false;
try
    opts = delimitedTextImportOptions( ...
        'NumVariables', nNumeric + 2, ...
        'Delimiter', {' ', sprintf('\t')}, ...
        'ConsecutiveDelimitersRule', 'join', ...
        'LeadingDelimitersRule', 'ignore');
    opts.DataLines = [dataStart Inf];
    opts.ExtraColumnsRule = 'ignore';
    opts.EmptyLineRule = 'read';
    opts.VariableTypes = [repmat({'string'}, 1, 2), repmat({'double'}, 1, nNumeric)];
    T = readtable(filePath, opts);
catch
    return;
end
if isempty(T) || size(T, 2) < nNumeric + 2
    return;
end

raw = T{:, 3:(nNumeric + 2)};
if isempty(raw)
    return;
end
data = double(raw);
if isempty(data) || size(data, 2) ~= nNumeric
    return;
end
dateCol = string(T{:, 1});
timeCol = string(T{:, 2});
valid = all(isfinite(data), 2);
if ~any(valid)
    data = zeros(0, nNumeric);
    timeText = {};
    return;
end
data = data(valid, :);
dateCol = dateCol(valid);
timeCol = timeCol(valid);
timeText = cellstr(dateCol + " " + timeCol);
ok = true;
end

function [timeText, data] = readWideLogDataBlockSlow(lines, dataStart, nNumeric)
timeText = {};
data = zeros(0, nNumeric);
for i = dataStart:numel(lines)
    [txt, nums, ok] = parseWideDataLine(lines{i}, nNumeric);
    if ok
        timeText{end + 1, 1} = txt; %#ok<AGROW>
        data(end + 1, :) = nums; %#ok<AGROW>
    end
end
end

function lines = readTextLinesCompat(filePath, maxLines)
if nargin < 2
    maxLines = inf;
end
fid = fopen(filePath, 'r');
if fid < 0
    error('Cannot open file: %s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
C = textscan(fid, '%s', maxLines, 'Delimiter', '\n', 'Whitespace', '');
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

function [row, ok] = parseAnyNumericLine(line)
row = [];
ok = false;
toks = tokenizeWhitespace(line);
if isempty(toks)
    return;
end
nums = str2double(toks);
if all(isfinite(nums))
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

function [axisGroups, channelDefs] = buildIvsaSineSignalDefs(headerTokens)
axisNames = {};
channelDefs = struct('axisName', {}, 'signalName', {}, 'displayName', {}, 'columnIdx', {});
for i = 1:numel(headerTokens)
    tok = headerTokens{i};
    cleanTok = regexprep(tok, '\[[^\]]*\]', '');
    m = regexp(cleanTok, '^([VH]\d+)_([A-Za-z]+)$', 'tokens', 'once');
    if isempty(m)
        continue;
    end
    axisName = upperLeadingLetter(upper(strrep(m{1}, ' ', '')));
    signalName = lower(strtrim(m{2}));
    if ~any(strcmp(axisNames, axisName))
        axisNames{end + 1} = axisName; %#ok<AGROW>
    end
    channelDefs(end + 1).axisName = axisName; %#ok<AGROW>
    channelDefs(end).signalName = signalName;
    channelDefs(end).displayName = sprintf('%s | %s', axisName, signalName);
    channelDefs(end).columnIdx = i;
end
axisGroups = struct('name', {}, 'columnIdx', {}, 'displayNames', {});
for i = 1:numel(axisNames)
    mask = strcmp({channelDefs.axisName}, axisNames{i});
    defs = channelDefs(mask);
    order = orderIvsaSineSignals({defs.signalName});
    defs = defs(order);
    channelDefs(mask) = defs;
    axisGroups(end + 1).name = axisNames{i}; %#ok<AGROW>
    axisGroups(end).columnIdx = [defs.columnIdx];
    axisGroups(end).displayNames = {defs.displayName};
end
end

function [axisGroups, channelDefs] = buildIvsaSffSignalDefs(headerTokens)
channelDefs = struct('axisName', {}, 'signalName', {}, 'displayName', {}, 'columnIdx', {});
displayNames = cell(1, numel(headerTokens));
for i = 1:numel(headerTokens)
    displayNames{i} = formatIvsaSffDisplayName(headerTokens{i});
    channelDefs(end + 1).axisName = displayNames{i}; %#ok<AGROW>
    channelDefs(end).signalName = '';
    channelDefs(end).displayName = displayNames{i};
    channelDefs(end).columnIdx = i;
end
axisGroups = struct('name', 'SFF Signals', 'columnIdx', 1:numel(headerTokens), 'displayNames', {displayNames});
end

function order = orderIvsaSineSignals(signalNames)
target = {'prox', 'geo', 'noise'};
score = zeros(1, numel(signalNames));
for i = 1:numel(signalNames)
    hit = find(strcmp(target, signalNames{i}), 1, 'first');
    if isempty(hit)
        hit = numel(target) + i;
    end
    score(i) = hit;
end
[~, order] = sort(score);
end

function txt = formatIvsaSffDisplayName(headerName)
txt = regexprep(strtrim(headerName), '\[[^\]]*\]', '');
txt = strrep(txt, '_', ' ');
txt = regexprep(txt, '\s+', ' ');
txt = strtrim(txt);
parts = regexp(lower(txt), '\s+', 'split');
for i = 1:numel(parts)
    parts{i} = upperLeadingLetter(parts{i});
end
txt = strjoin(parts, ' ');
txt = strrep(txt, 'Acc', 'Acc');
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
base = regexprep(base, '[_-]?(noise|geo|geophone|sensor|resp|response|input|output)$', '', 'ignorecase');
base = regexprep(base, '[_-]?(noise|geo|geophone|sensor|resp|response|input|output)[_-].*$', '', 'ignorecase');
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

groups = addHeaderMatchGroup(groups, 'BF Velocity', headerNames, '^(VEL_BF_|ACC_BF_)');
groups = addHeaderMatchGroup(groups, 'SF Velocity', headerNames, '^(VEL_SF_|ACC_SF_)');
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

groups = appendAutoPrefixGroups(groups, headerNames);
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
    if ~isempty(regexpi(name, '^(VEL_BF_|ACC_BF_|VEL_SF_|ACC_SF_|PROX_|VALUE\d+_|VALVE\d+_|MT_)', 'once'))
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
usePresetLayout = false;
if isfield(G, 'layout') && numel(G.layout) == 2 && prod(G.layout) >= nPlots
    if isfield(G, 'columnIdx') && nPlots == numel(G.columnIdx)
        usePresetLayout = true;
    elseif ~isfield(G, 'columnIdx')
        usePresetLayout = true;
    end
end
if usePresetLayout
    layout = G.layout;
end
if isempty(layout)
    layout = chooseTightGrid(nPlots);
end
end

function ax = createFrequencyHostAxis(parentObj, ttl, ylbl)
ax = axes('Parent', parentObj, 'Units', 'normalized', ...
    'Position', [0.08 0.12 0.88 0.80], 'Box', 'on');
title(ax, ttl, 'Interpreter', 'none');
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, ylbl);
set(ax, 'XScale', 'log');
grid(ax, 'on');
end

function layoutFrequencyAreaAxes(parentObj, renderInfo)
kids = findall(parentObj, 'Type', 'axes');
if isempty(kids)
    return;
end
if ~isempty(renderInfo) && isstruct(renderInfo) && isfield(renderInfo, 'mode') ...
        && strcmp(renderInfo.mode, 'Subplots') && numel(kids) > 1
    layout = renderInfo.layout;
    if prod(layout) < numel(kids)
        layout = chooseTightGrid(numel(kids));
    end
    applyAxesGridLayout(flipud(kids), layout);
else
    set(kids, 'Units', 'normalized');
    if isscalar(kids)
        set(kids, 'Position', [0.08 0.12 0.88 0.80]);
    end
end
end

function [freqRender, plotted, skipped] = collectFrequencyRenderData(files, freqIdx, pairLabels)
freqRender = struct('pairLabel', {}, 'curves', {});
plotted = 0;
skipped = {};
for p = 1:numel(pairLabels)
    curves = struct('freq', {}, 'magDb', {}, 'phaseDeg', {}, 'displayName', {});
    for i = 1:numel(freqIdx)
        F = files{freqIdx(i)};
        pairIdx = findPairIndexByLabel(F, pairLabels{p});
        if pairIdx < 1
            skipped{end + 1} = sprintf('%s | %s', pairLabels{p}, F.displayName); %#ok<AGROW>
            continue;
        end
        try
            [freq, magDb, phaseDeg] = computeTransferPair(F, pairIdx);
        catch ME
            skipped{end + 1} = sprintf('%s | %s (%s)', pairLabels{p}, F.displayName, ME.message); %#ok<AGROW>
            continue;
        end
        if isempty(freq)
            skipped{end + 1} = sprintf('%s | %s', pairLabels{p}, F.displayName); %#ok<AGROW>
            continue;
        end
        C = struct();
        C.freq = freq;
        C.magDb = magDb;
        C.phaseDeg = phaseDeg;
        C.displayName = pairLabels{p};
        curves(end + 1) = C; %#ok<AGROW>
        plotted = plotted + 1;
    end
    if ~isempty(curves)
        freqRender(end + 1).pairLabel = pairLabels{p}; %#ok<AGROW>
        freqRender(end).curves = curves;
    end
end
end

function renderFrequencyGridToParent(parentObj, freqRender, layout, viewKind)
axesHandles = createAxesGrid(parentObj, layout, numel(freqRender));
for i = 1:numel(axesHandles)
    renderFrequencyPairToAxis(axesHandles(i), freqRender(i), viewKind);
    styleFrequencySubplotAxis(axesHandles(i), i, layout, false, viewKind);
end
end

function renderFrequencyGridToFigure(hFig, freqRender, layout, viewKind)
axesHandles = createAxesGrid(hFig, layout, numel(freqRender));
for i = 1:numel(axesHandles)
    renderFrequencyPairToAxis(axesHandles(i), freqRender(i), viewKind);
    styleFrequencySubplotAxis(axesHandles(i), i, layout, true, viewKind);
end
ttl = ternaryText(strcmp(viewKind, 'mag'), 'Frequency Magnitude', 'Frequency Phase');
try
    sgtitle(hFig, ttl, 'Interpreter', 'none');
catch
end
end

function renderFrequencyPairToAxis(ax, pairInfo, viewKind)
cla(ax);
hold(ax, 'on');
xMin = inf;
xMax = -inf;
for j = 1:numel(pairInfo.curves)
    C = pairInfo.curves(j);
    if strcmp(viewKind, 'mag')
        semilogx(ax, C.freq, C.magDb, 'LineWidth', 1.1, 'DisplayName', C.displayName);
    else
        semilogx(ax, C.freq, C.phaseDeg, 'LineWidth', 1.1, 'DisplayName', C.displayName);
    end
    xMin = min(xMin, min(C.freq));
    xMax = max(xMax, max(C.freq));
end
hold(ax, 'off');
grid(ax, 'on');
set(ax, 'XScale', 'log');
applyFrequencyXLimits(ax, xMin, xMax);
    if strcmp(viewKind, 'mag')
        title(ax, pairInfo.pairLabel, 'Interpreter', 'none');
        ylabel(ax, 'Magnitude (dB)');
    else
        title(ax, pairInfo.pairLabel, 'Interpreter', 'none');
        ylabel(ax, 'Phase (deg)');
    end
    if numel(pairInfo.curves) > 1 && numel(unique(getCurveDisplayNames(pairInfo.curves))) > 1
        legend(ax, 'show', 'Location', 'northeast');
    else
        legend(ax, 'off');
    end
end

function renderFrequencyOverlayToAxis(ax, freqRender, viewKind)
cla(ax);
hold(ax, 'on');
xMin = inf;
xMax = -inf;
for i = 1:numel(freqRender)
    for j = 1:numel(freqRender(i).curves)
        C = freqRender(i).curves(j);
        if strcmp(viewKind, 'mag')
            semilogx(ax, C.freq, C.magDb, 'LineWidth', 1.1, 'DisplayName', C.displayName);
        else
            semilogx(ax, C.freq, C.phaseDeg, 'LineWidth', 1.1, 'DisplayName', C.displayName);
        end
        xMin = min(xMin, min(C.freq));
        xMax = max(xMax, max(C.freq));
    end
end
    hold(ax, 'off');
    grid(ax, 'on');
    set(ax, 'XScale', 'log');
    applyFrequencyXLimits(ax, xMin, xMax);
    if strcmp(viewKind, 'mag')
        title(ax, 'Magnitude (dB)', 'Interpreter', 'none');
        ylabel(ax, 'Magnitude (dB)');
    else
        title(ax, 'Phase (deg)', 'Interpreter', 'none');
        ylabel(ax, 'Phase (deg)');
    end
    xlabel(ax, 'Frequency (Hz)');
if ~isempty(freqRender)
    legend(ax, 'show', 'Location', 'northeast');
else
    legend(ax, 'off');
end
end

function applyFrequencyOverlayAxisStyle(ax, xMin, xMax, yLabelText)
grid(ax, 'on');
set(ax, 'XScale', 'log');
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, yLabelText);
applyFrequencyXLimits(ax, xMin, xMax);
legend(ax, 'show', 'Location', 'northeast');
end

function applyFrequencyXLimits(ax, xMin, xMax)
if isfinite(xMin) && isfinite(xMax) && xMax > xMin
    xlim(ax, [xMin xMax]);
else
    set(ax, 'XLimMode', 'auto');
end
end

function styleFrequencySubplotAxis(ax, idx, layout, isExportFigure, viewKind)
nRows = layout(1);
nCols = layout(2);
row = ceil(idx / nCols);
col = mod(idx - 1, nCols) + 1;
if row == nRows
    xlabel(ax, 'Frequency (Hz)');
else
    xlabel(ax, '');
end
if col == 1
    if strcmp(viewKind, 'mag')
        ylabel(ax, 'Magnitude (dB)');
    else
        ylabel(ax, 'Phase (deg)');
    end
else
    ylabel(ax, '');
end
if isExportFigure
    set(ax, 'FontSize', 10, 'TitleFontSizeMultiplier', 0.95);
else
    set(ax, 'FontSize', 9, 'TitleFontSizeMultiplier', 0.90);
end
end

function pairLabels = getSelectedFrequencyPairLabels(files, freqIdx, hList)
items = getListboxItems(hList);
if isempty(items) || (numel(items) == 1 && strcmp(items{1}, '(none)'))
    pairLabels = {};
    return;
end
sel = getListSelectionIndices(hList, numel(items));
if isempty(sel)
    pairLabels = collectFrequencyPairLabels(files, freqIdx);
else
    pairLabels = items(sel);
end
end

function txt = summarizeFrequencySelection(pairLabels, nFiles)
if isempty(pairLabels)
    txt = '(none)';
elseif numel(pairLabels) == 1
    txt = pairLabels{1};
elseif numel(pairLabels) == 2
    txt = sprintf('%s, %s', pairLabels{1}, pairLabels{2});
else
    txt = sprintf('%s and %d more', pairLabels{1}, numel(pairLabels) - 1);
end
if nargin >= 2 && nFiles > 0
    txt = sprintf('%s | files: %d', txt, nFiles);
end
end

function txt = summarizeFrequencyPairNames(freqRender)
pairLabels = cell(1, numel(freqRender));
for i = 1:numel(freqRender)
    pairLabels{i} = freqRender(i).pairLabel;
end
txt = summarizeFrequencySelection(pairLabels);
end

function names = getCurveDisplayNames(curves)
names = cell(1, numel(curves));
for i = 1:numel(curves)
    names{i} = curves(i).displayName;
end
end

function ax = createSignalHostAxis(parentObj, ttl, xLabelText)
ax = axes('Parent', parentObj, 'Units', 'normalized', ...
    'Position', [0.07 0.08 0.89 0.84], 'Box', 'on');
title(ax, ttl, 'Interpreter', 'none');
xlabel(ax, xLabelText);
ylabel(ax, 'Value');
grid(ax, 'on');
end

function renderSignalSubplotGridToParent(parentObj, xData, Y, names, layout, groupName, xLabelText)
axesHandles = createAxesGrid(parentObj, layout, size(Y, 2));
for i = 1:numel(axesHandles)
    plot(axesHandles(i), xData, Y(:, i), 'LineWidth', 1.0);
    grid(axesHandles(i), 'on');
    title(axesHandles(i), names{i}, 'Interpreter', 'none');
    styleSignalSubplotAxis(axesHandles(i), i, layout, false, xLabelText);
    applySignalXLimits(axesHandles(i), xData);
end
end

function renderSignalSubplotGridToFigure(hFig, xData, Y, names, layout, figTitle, groupName, xLabelText)
axesHandles = createAxesGrid(hFig, layout, size(Y, 2));
for i = 1:numel(axesHandles)
    plot(axesHandles(i), xData, Y(:, i), 'LineWidth', 1.0);
    grid(axesHandles(i), 'on');
    title(axesHandles(i), names{i}, 'Interpreter', 'none');
    styleSignalSubplotAxis(axesHandles(i), i, layout, true, xLabelText);
    applySignalXLimits(axesHandles(i), xData);
end
try
    sgtitle(hFig, figTitle, 'Interpreter', 'none');
catch
end
end

function styleSignalSubplotAxis(ax, idx, layout, isExportFigure, xLabelText)
nRows = layout(1);
nCols = layout(2);
row = ceil(idx / nCols);
col = mod(idx - 1, nCols) + 1;
if row == nRows
    xlabel(ax, xLabelText);
else
    xlabel(ax, '');
end
if col == 1
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

function applySignalXLimits(ax, xData)
applyLogXLimits(ax, xData);
end

function items = getListboxItems(h)
raw = get(h, 'String');
if isempty(raw)
    items = {};
elseif ischar(raw)
    items = {raw};
else
    items = raw(:).';
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
valuePrefixes = { ...
    {'VALUE1_', 'VALVE1_'}, ...
    {'VALUE2_', 'VALVE2_'}, ...
    {'VALUE3_', 'VALVE3_'}, ...
    {'VALUE4_', 'VALVE4_'}};
for i = 1:numel(valuePrefixes)
    prefixSet = valuePrefixes{i};
    exprParts = cell(1, numel(prefixSet));
    for j = 1:numel(prefixSet)
        exprParts{j} = ['^', regexptranslate('escape', prefixSet{j})];
    end
    name = ['Valve Output ', num2str(i)];
    groups = addHeaderMatchGroup(groups, name, headerNames, strjoin(exprParts, '|'));
end
groups = addHeaderMatchGroup(groups, 'Valve Output All', headerNames, '^(VALUE\d+_|VALVE\d+_)');
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

function groups = appendAutoPrefixGroups(groups, headerNames)
prefixMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(headerNames)
    prefix = deriveAutoGroupPrefix(headerNames{i});
    if isempty(prefix)
        continue;
    end
    if isKey(prefixMap, prefix)
        item = prefixMap(prefix);
        item.idx(end + 1) = i; %#ok<AGROW>
        item.names{end + 1} = headerNames{i}; %#ok<AGROW>
        prefixMap(prefix) = item;
    else
        prefixMap(prefix) = struct('idx', i, 'names', {{headerNames{i}}});
    end
end
keysList = keys(prefixMap);
for i = 1:numel(keysList)
    prefix = keysList{i};
    item = prefixMap(prefix);
    if numel(item.idx) < 2
        continue;
    end
    groupName = ['Auto ', prefix];
    groups = appendGroupIfMissing(groups, groupName, item.idx, item.names, chooseTightGrid(numel(item.idx)));
end
end

function prefix = deriveAutoGroupPrefix(headerName)
prefix = upper(strtrim(headerName));
prefix = regexprep(prefix, '\(.*$', '');
prefix = regexprep(prefix, '\s+', '');
if isempty(prefix)
    prefix = '';
    return;
end
parts = regexp(prefix, '[_-]', 'split');
if numel(parts) >= 2
    prefix = [parts{1}, '_', parts{2}];
elseif ~isempty(regexp(prefix, '^[A-Z]+\d+', 'once'))
    tok = regexp(prefix, '^([A-Z]+)\d+', 'tokens', 'once');
    prefix = tok{1};
else
    tok = regexp(prefix, '^([A-Z]+)', 'tokens', 'once');
    if isempty(tok)
        prefix = '';
    else
        prefix = tok{1};
    end
end
prefix = strtrim(prefix);
if isempty(prefix) || numel(prefix) < 2 || strcmp(prefix, 'AUTO')
    prefix = '';
end
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
elseif strcmp(F.type, 'ivsa_signal')
    label = sprintf('[SIG] %s | %s | Update=%g | FsNum=%g', F.displayName, upper(F.signalKind), F.update, F.fsNumerator);
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

function [freqMode, idx, note] = getCurrentFrequencySelection(files, selectedIds)
freqMode = 'none';
idx = [];
note = '';
if isempty(files)
    return;
end
selectedFiles = filesByIds(files, selectedIds);
selectedTypes = {};
for i = 1:numel(selectedFiles)
    if any(strcmp(selectedFiles{i}.type, {'freq', 'ivsa_signal'}))
        selectedTypes{end + 1} = selectedFiles{i}.type; %#ok<AGROW>
    end
end
if isempty(selectedTypes)
    allSignal = findFilesByType(files, 'ivsa_signal');
    if ~isempty(allSignal)
        freqMode = 'signal';
        idx = allSignal(1);
        return;
    end
    allFreq = findFilesByType(files, 'freq');
    if ~isempty(allFreq)
        freqMode = 'frf';
        idx = allFreq;
    end
    return;
end
primaryType = selectedTypes{1};
if strcmp(primaryType, 'freq')
    freqMode = 'frf';
else
    freqMode = 'signal';
end
for i = 1:numel(files)
    if any(files{i}.id == selectedIds) && strcmp(files{i}.type, primaryType)
        idx(end + 1) = i; %#ok<AGROW>
    end
end
if numel(unique(selectedTypes)) > 1
    note = 'mixed file types selected, using the first supported type';
end
if strcmp(freqMode, 'signal') && numel(idx) > 1
    idx = idx(1);
    if isempty(note)
        note = 'multiple signal files selected, using the first one';
    end
end
end

function items = collectIvsaSignalSelectionItems(files, signalIdx)
items = {};
if isempty(signalIdx)
    return;
end
F = files{signalIdx(1)};
if strcmp(F.signalKind, 'sine')
    for i = 1:numel(F.axisGroups)
        items{end + 1} = F.axisGroups(i).name; %#ok<AGROW>
    end
else
    items = {F.channelDefs.displayName};
end
end

function labels = getSelectedIvsaSignalLabels(files, signalIdx, hList)
items = getListboxItems(hList);
if isempty(items) || (numel(items) == 1 && strcmp(items{1}, '(none)'))
    labels = {};
    return;
end
sel = getListSelectionIndices(hList, numel(items));
if isempty(sel)
    labels = collectIvsaSignalSelectionItems(files, signalIdx);
else
    labels = items(sel);
end
end

function [xData, Y, names, groupName, xLabelText] = buildIvsaSignalPlotData(F, selectedLabels, xAxisMode)
colIdx = [];
names = {};
if strcmp(F.signalKind, 'sine')
    for i = 1:numel(selectedLabels)
        G = findIvsaSignalAxisGroup(F, selectedLabels{i});
        if isempty(G)
            continue;
        end
        colIdx = [colIdx, G.columnIdx]; %#ok<AGROW>
        names = [names, G.displayNames]; %#ok<AGROW>
    end
    groupName = 'Sine Signals';
else
    for i = 1:numel(selectedLabels)
        dIdx = find(strcmp({F.channelDefs.displayName}, selectedLabels{i}), 1, 'first');
        if isempty(dIdx)
            continue;
        end
        colIdx(end + 1) = F.channelDefs(dIdx).columnIdx; %#ok<AGROW>
        names{end + 1} = F.channelDefs(dIdx).displayName; %#ok<AGROW>
    end
    groupName = 'SFF Signals';
end
if isempty(colIdx)
    xData = [];
    Y = [];
    xLabelText = 'Sample Index';
    return;
end
xData = F.sampleIndex;
if strcmp(xAxisMode, 'Time (s)')
    xData = (double(F.sampleIndex) - 1) ./ F.fs;
    xLabelText = 'Time (s)';
else
    xLabelText = 'Sample Index';
end
Y = F.dataMatrix(:, colIdx);
end

function G = findIvsaSignalAxisGroup(F, groupName)
G = [];
for i = 1:numel(F.axisGroups)
    if strcmp(F.axisGroups(i).name, groupName)
        G = F.axisGroups(i);
        return;
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
