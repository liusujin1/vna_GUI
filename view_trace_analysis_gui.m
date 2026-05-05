function varargout = view_trace_analysis_gui(varargin)
% GUI for IDE/HAC trace analysis.
% - IDE Trace: time domain + PSD for text trace files
% - HAC Trace: time domain browsing for CSV trace files

if nargin > 0 && (ischar(varargin{1}) || (isstring(varargin{1}) && isscalar(varargin{1})))
    [varargout{1:nargout}] = dispatchTraceAction(char(varargin{1}), varargin{2:end});
    return;
end

screenSz = get(0, 'ScreenSize');
figW = max(1380, min(round(screenSz(3) * 0.94), 1540));
figH = max(860, min(round(screenSz(4) * 0.90), 980));
figX = max(20, round((screenSz(3) - figW) / 2));
figY = max(20, round((screenSz(4) - figH) / 2));

fig = figure( ...
    'Name', 'Trace Analysis GUI', ...
    'NumberTitle', 'off', ...
    'Position', [figX figY figW figH], ...
    'Color', get(0, 'DefaultUicontrolBackgroundColor'), ...
    'MenuBar', 'figure', ...
    'ToolBar', 'figure', ...
    'Resize', 'on');

app = initTraceAppState();
setappdata(fig, 'app', app);

if nargout > 0
    varargout{1} = fig;
end

panel = uipanel('Parent', fig, 'Title', 'Controls', 'Units', 'pixels', ...
    'Position', [15 15 380 860]);

btnLoad = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Load Files', ...
    'Position', [15 815 110 30], ...
    'Callback', @onLoadFiles);
btnDelete = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Delete Selected', ...
    'Position', [135 815 110 30], ...
    'Callback', @onDeleteSelected);
btnClear = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Clear Plots', ...
    'Position', [255 815 110 30], ...
    'Callback', @onClearPlots);

edtFile = uicontrol('Parent', panel, 'Style', 'edit', ...
    'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'String', 'No file loaded', ...
    'Position', [15 776 350 28]);

lblLoadedFiles = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Loaded Files:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 750 100 18]);
lstFiles = uicontrol('Parent', panel, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [15 555 350 192], ...
    'Callback', @onFileSelectionChanged);

grpIde = uipanel('Parent', panel, 'Title', 'IDE Trace Settings', ...
    'Units', 'pixels', 'Position', [15 170 350 370]);
lblIdeXAxis = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'X Axis:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 336 55 18]);
ddIdeXAxis = uicontrol('Parent', grpIde, 'Style', 'popupmenu', ...
    'String', {'Sample Index', 'Time (s)'}, ...
    'BackgroundColor', 'w', ...
    'Position', [72 332 260 24], ...
    'Callback', @onIdeXAxisChanged);
lblIdePlotMode = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'Plot Mode:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 306 60 18]);
ddIdePlotMode = uicontrol('Parent', grpIde, 'Style', 'popupmenu', ...
    'String', {'Overlay', 'Subplots'}, ...
    'BackgroundColor', 'w', ...
    'Position', [72 302 260 24], ...
    'Callback', @onIdePlotModeChanged);
lblIdeRange = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'Range:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 276 52 18]);
edtIdeStart = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [72 272 76 24], ...
    'Callback', @onIdeRangeChanged);
lblIdeRangeSep = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', '~', ...
    'HorizontalAlignment', 'center', ...
    'Position', [152 275 14 18]);
edtIdeEnd = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [170 272 76 24], ...
    'Callback', @onIdeRangeChanged);
lblIdeRangeHint = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'Sample index range', ...
    'HorizontalAlignment', 'left', ...
    'Position', [252 275 82 18]);
lblIdeChannels = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'Channels:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 246 60 18]);
lstIdeChannels = uicontrol('Parent', grpIde, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [12 124 320 118], ...
    'Callback', @onIdeChannelSelectionChanged);
lblEuTable = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'EU Configuration:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 100 110 18]);
lblEuGroup = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'EU by Suffix:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 80 110 18]);
lblEuProx = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'Prox:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 58 36 18]);
edtEuProx = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'Position', [50 56 68 22]);
lblEuFb = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'FB:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [132 58 28 18]);
edtEuFb = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'Position', [160 56 68 22]);
lblEuAcc = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'ACC:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 34 36 18]);
edtEuAcc = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'Position', [50 32 68 22]);
lblEuPos = uicontrol('Parent', grpIde, 'Style', 'text', ...
    'String', 'POS:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [132 34 28 18]);
edtEuPos = uicontrol('Parent', grpIde, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'Position', [160 32 68 22]);
btnIdeEuSuffixApply = uicontrol('Parent', grpIde, 'Style', 'pushbutton', ...
    'String', 'Apply by Suffix', ...
    'Position', [238 32 94 46], ...
    'Callback', @onIdeEuSuffixApply);
tblIdeEu = uitable('Parent', grpIde, ...
    'Data', cell(0, 3), ...
    'ColumnName', {'Channel', 'EU', 'Enabled'}, ...
    'ColumnEditable', [false true true], ...
    'ColumnFormat', {'char', 'numeric', 'logical'}, ...
    'RowName', [], ...
    'CellEditCallback', @onIdeEuEdited, ...
    'Position', [12 12 320 86]);

grpHac = uipanel('Parent', panel, 'Title', 'HAC Trace Settings', ...
    'Units', 'pixels', 'Position', [15 170 350 370]);
lblHacPreset = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', 'Preset:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 336 52 18]);
ddHacPreset = uicontrol('Parent', grpHac, 'Style', 'popupmenu', ...
    'String', {'(none)'}, ...
    'BackgroundColor', 'w', ...
    'Position', [72 332 260 24], ...
    'Callback', @onHacPresetChanged);
lblHacPlotMode = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', 'Plot Mode:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 306 60 18]);
ddHacPlotMode = uicontrol('Parent', grpHac, 'Style', 'popupmenu', ...
    'String', {'Overlay', 'Subplots'}, ...
    'BackgroundColor', 'w', ...
    'Position', [72 302 260 24], ...
    'Callback', @onHacPlotModeChanged);
lblHacRange = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', 'Range:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 276 52 18]);
edtHacStart = uicontrol('Parent', grpHac, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [72 272 76 24], ...
    'Callback', @onHacRangeChanged);
lblHacRangeSep = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', '~', ...
    'HorizontalAlignment', 'center', ...
    'Position', [152 275 14 18]);
edtHacEnd = uicontrol('Parent', grpHac, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'Position', [170 272 76 24], ...
    'Callback', @onHacRangeChanged);
lblHacRangeHint = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', 'Sample index range', ...
    'HorizontalAlignment', 'left', ...
    'Position', [252 275 82 18]);
lblHacChannels = uicontrol('Parent', grpHac, 'Style', 'text', ...
    'String', 'Channels:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [12 246 60 18]);
lstHacChannels = uicontrol('Parent', grpHac, 'Style', 'listbox', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Min', 0, ...
    'Max', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [12 12 320 230], ...
    'Callback', @onHacChannelSelectionChanged);

btnPlot = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Plot', ...
    'Position', [15 120 110 30], ...
    'Callback', @onPlot);
btnDemean = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', 'Demean: Off', ...
    'Value', 0, ...
    'Position', [135 120 110 30], ...
    'Callback', @onDemeanChanged);
btnHold = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', 'Hold: Off', ...
    'Value', 0, ...
    'Position', [255 120 110 30], ...
    'Callback', @onHoldChanged);

lblStatus = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Status: ready', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 18 350 88]);

tabGroup = uitabgroup('Parent', fig, 'Units', 'pixels', 'Position', [410 15 1110 860]);
tabIde = uitab('Parent', tabGroup, 'Title', 'IDE Trace');
tabHac = uitab('Parent', tabGroup, 'Title', 'HAC Trace');
try
    set(tabGroup, 'SelectionChangedFcn', @onTabChanged);
catch
    try
        set(tabGroup, 'SelectionChangeFcn', @onTabChanged);
    catch
    end
end

lblIdeSelected = uicontrol('Parent', tabIde, 'Style', 'text', ...
    'String', 'Active IDE file', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 812 600 18]);
lblIdeContext = uicontrol('Parent', tabIde, 'Style', 'text', ...
    'String', 'Context', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 790 800 18]);
btnIdeTimeFigure = uicontrol('Parent', tabIde, 'Style', 'pushbutton', ...
    'String', 'Time Figure', ...
    'Position', [900 808 90 26], ...
    'Callback', @onOpenIdeTimeFigure);
btnIdePsdFigure = uicontrol('Parent', tabIde, 'Style', 'pushbutton', ...
    'String', 'PSD Figure', ...
    'Position', [1000 808 90 26], ...
    'Callback', @onOpenIdePsdFigure);
pnlIdeTime = uipanel('Parent', tabIde, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 430 1050 330]);
pnlIdePsd = uipanel('Parent', tabIde, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 40 1050 330]);

lblHacSelected = uicontrol('Parent', tabHac, 'Style', 'text', ...
    'String', 'Active HAC file', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 812 600 18]);
lblHacContext = uicontrol('Parent', tabHac, 'Style', 'text', ...
    'String', 'Context', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 790 800 18]);
btnHacFigure = uicontrol('Parent', tabHac, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [1000 808 90 26], ...
    'Callback', @onOpenHacFigure);
pnlHacPlot = uipanel('Parent', tabHac, 'BorderType', 'none', ...
    'Units', 'pixels', 'Position', [20 40 1050 720]);

axIdeTime = [];
axIdePsd = [];
axHac = [];

refreshFileList([]);
refreshContextControls();
set(fig, 'ResizeFcn', @onResize);
onResize();

    function appState = getApp()
        appState = getappdata(fig, 'app');
    end

    function setApp(appState)
        setappdata(fig, 'app', appState);
    end

    function onLoadFiles(~, ~)
        appState = getApp();
        injectedFiles = getappdata(fig, 'testFilesToLoad');
        useInjected = iscell(injectedFiles) && ~isempty(injectedFiles);
        if useInjected
            fileNames = cell(1, numel(injectedFiles));
            filePaths = cell(1, numel(injectedFiles));
            for k = 1:numel(injectedFiles)
                [filePaths{k}, baseName, ext] = fileparts(injectedFiles{k});
                fileNames{k} = [baseName, ext];
            end
            rmappdata(fig, 'testFilesToLoad');
        else
            [fileNames, filePath] = uigetfile( ...
                {'*.txt;*.csv', 'Trace Files (*.txt,*.csv)'; ...
                 '*.*', 'All Files (*.*)'}, ...
                'Select trace analysis files', appState.lastOpenDir, 'MultiSelect', 'on');
            if isequal(fileNames, 0)
                return;
            end
            if ischar(fileNames)
                fileNames = {fileNames};
            end
            filePaths = repmat({filePath}, 1, numel(fileNames));
        end

        loadedEntries = struct('type', {}, 'id', {});
        failed = {};
        setStatus('Status: loading files...');
        drawnow;

        for i = 1:numel(fileNames)
            fullName = fullfile(filePaths{i}, fileNames{i});
            try
                F = loadOneTraceFile(fullName);
                F.id = appState.nextFileId;
                appState.nextFileId = appState.nextFileId + 1;
                if strcmp(F.type, 'ide_trace')
                    appState.ideFiles{end + 1} = F; %#ok<AGROW>
                else
                    appState.hacFiles{end + 1} = F; %#ok<AGROW>
                end
                appState.fileOrder(end + 1) = struct('type', F.type, 'id', F.id); %#ok<AGROW>
                loadedEntries(end + 1) = struct('type', F.type, 'id', F.id); %#ok<AGROW>
            catch ME
                failed{end + 1} = sprintf('%s: %s', fileNames{i}, ME.message); %#ok<AGROW>
            end
        end

        if ~isempty(filePaths)
            appState.lastOpenDir = filePaths{1};
        end
        if ~isempty(loadedEntries)
            lastType = loadedEntries(end).type;
            if strcmp(lastType, 'hac_trace')
                appState.activeTab = 'hac';
                try
                    set(tabGroup, 'SelectedTab', tabHac);
                catch
                end
            else
                appState.activeTab = 'ide';
                try
                    set(tabGroup, 'SelectedTab', tabIde);
                catch
                end
            end
        end
        setApp(appState);
        refreshFileList(loadedEntries);
        refreshContextControls();
        autoPlotCurrentSelection();

        if isempty(failed)
            setStatus(sprintf('Status: loaded %d file(s).', numel(loadedEntries)));
        else
            setStatus(sprintf('Status: loaded %d file(s), failed %d.', numel(loadedEntries), numel(failed)));
            showAlertCompat(fig, strjoin(failed, newline), 'Load warning');
        end
    end

    function onDeleteSelected(~, ~)
        appState = getApp();
        entries = getSelectedEntries();
        if isempty(entries)
            setStatus('Status: no loaded files selected.');
            return;
        end

        for i = 1:numel(entries)
            if strcmp(entries(i).type, 'ide_trace')
                idx = findFileIndexById(appState.ideFiles, entries(i).id);
                if idx > 0
                    appState.ideFiles(idx) = [];
                end
            else
                idx = findFileIndexById(appState.hacFiles, entries(i).id);
                if idx > 0
                    appState.hacFiles(idx) = [];
                end
            end
        end
        keep = true(1, numel(appState.fileOrder));
        for i = 1:numel(appState.fileOrder)
            for j = 1:numel(entries)
                if strcmp(appState.fileOrder(i).type, entries(j).type) && appState.fileOrder(i).id == entries(j).id
                    keep(i) = false;
                    break;
                end
            end
        end
        appState.fileOrder = appState.fileOrder(keep);
        appState.lastIdeRender = [];
        appState.lastHacRender = [];
        setApp(appState);
        clearIdeRenderArea(true);
        clearHacRenderArea(true);
        refreshFileList([]);
        refreshContextControls();
        setStatus(sprintf('Status: deleted %d file(s).', numel(entries)));
    end

    function onClearPlots(~, ~)
        clearIdeRenderArea(true);
        clearHacRenderArea(true);
        appState = getApp();
        appState.lastIdeRender = [];
        appState.lastHacRender = [];
        setApp(appState);
        setStatus('Status: cleared all plots.');
    end

    function onFileSelectionChanged(~, ~)
        appState = getApp();
        entries = getSelectedEntries();
        if numel(entries) == 1
            if strcmp(entries(1).type, 'ide_trace')
                appState.activeTab = 'ide';
                try
                    set(tabGroup, 'SelectedTab', tabIde);
                catch
                end
            elseif strcmp(entries(1).type, 'hac_trace')
                appState.activeTab = 'hac';
                try
                    set(tabGroup, 'SelectedTab', tabHac);
                catch
                end
            end
            setApp(appState);
        end
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onPlot(~, ~)
        appState = getApp();
        if strcmp(appState.activeTab, 'hac')
            plotHacPage();
        else
            plotIdePage();
        end
    end

    function onDemeanChanged(~, ~)
        appState = getApp();
        appState.demean = logical(get(btnDemean, 'Value'));
        setApp(appState);
        if appState.demean
            set(btnDemean, 'String', 'Demean: On');
        else
            set(btnDemean, 'String', 'Demean: Off');
        end
        autoPlotCurrentSelection();
    end

    function onHoldChanged(~, ~)
        appState = getApp();
        appState.holdPlots = logical(get(btnHold, 'Value'));
        setApp(appState);
        if appState.holdPlots
            set(btnHold, 'String', 'Hold: On');
        else
            set(btnHold, 'String', 'Hold: Off');
        end
    end

    function onIdePlotModeChanged(~, ~)
        appState = getApp();
        appState.idePlotMode = getPopupSelectedString(ddIdePlotMode);
        if strcmp(appState.idePlotMode, 'Subplots')
            appState.holdPlots = false;
            set(btnHold, 'Value', 0, 'String', 'Hold: Off');
        end
        setApp(appState);
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onIdeXAxisChanged(~, ~)
        appState = getApp();
        appState.ideXAxisMode = getPopupSelectedString(ddIdeXAxis);
        setApp(appState);
        autoPlotCurrentSelection();
    end

    function onIdeRangeChanged(~, ~)
        appState = getApp();
        F = getCurrentIdeFile(appState, getSelectedEntries());
        if isempty(F)
            return;
        end
        appState.ideRange = updateRangeState(appState.ideRange, F.id, edtIdeStart, edtIdeEnd, size(F.rawData, 1));
        setApp(appState);
        autoPlotCurrentSelection();
    end

    function onIdeChannelSelectionChanged(~, ~)
        autoPlotCurrentSelection();
    end

    function onIdeEuEdited(~, evt)
        appState = getApp();
        F = getCurrentIdeFile(appState, getSelectedEntries());
        if isempty(F) || isempty(evt.Indices)
            return;
        end
        rowIdx = evt.Indices(1);
        colIdx = evt.Indices(2);
        idx = findFileIndexById(appState.ideFiles, F.id);
        if idx < 1 || rowIdx < 1 || rowIdx > numel(appState.ideFiles{idx}.channelDefs)
            return;
        end
        if colIdx == 2
            newVal = evt.NewData;
            if ~isnumeric(newVal) || ~isscalar(newVal) || ~isfinite(newVal) || newVal == 0
                refreshContextControls();
                showAlertCompat(fig, 'EU must be a finite non-zero number.', 'Invalid EU');
                return;
            end
            appState.ideFiles{idx}.euPerChannel(rowIdx) = double(newVal);
        elseif colIdx == 3
            appState.ideFiles{idx}.enabledChannels(rowIdx) = logical(evt.NewData);
        end
        appState.ideFiles{idx} = applyIdeEuScaling(appState.ideFiles{idx});
        setApp(appState);
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onIdeEuSuffixApply(~, ~)
        appState = getApp();
        F = getCurrentIdeFile(appState, getSelectedEntries());
        if isempty(F)
            setStatus('Status: select an IDE trace file first.');
            return;
        end
        idx = findFileIndexById(appState.ideFiles, F.id);
        if idx < 1
            return;
        end

        suffixSpecs = { ...
            'Prox', edtEuProx; ...
            'FB', edtEuFb; ...
            'ACC', edtEuAcc; ...
            'POS', edtEuPos};
        updated = 0;
        for i = 1:size(suffixSpecs, 1)
            category = suffixSpecs{i, 1};
            hEdit = suffixSpecs{i, 2};
            raw = strtrim(get(hEdit, 'String'));
            if isempty(raw) || strcmpi(raw, 'mixed')
                continue;
            end
            euVal = str2double(raw);
            if ~isfinite(euVal) || euVal == 0
                showAlertCompat(fig, sprintf('%s EU must be a finite non-zero number.', category), 'Invalid EU');
                return;
            end
            mask = strcmp({appState.ideFiles{idx}.channelDefs.suffixCategory}, category);
            if any(mask)
                appState.ideFiles{idx}.euPerChannel(mask) = euVal;
                updated = updated + nnz(mask);
            end
        end
        if updated < 1
            setStatus('Status: no suffix-based EU changes were applied.');
            return;
        end
        appState.ideFiles{idx} = applyIdeEuScaling(appState.ideFiles{idx});
        setApp(appState);
        refreshContextControls();
        autoPlotCurrentSelection();
        setStatus(sprintf('Status: applied suffix EU settings to %d IDE channel(s).', updated));
    end

    function onHacPresetChanged(~, ~)
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onHacPlotModeChanged(~, ~)
        appState = getApp();
        appState.hacPlotMode = getPopupSelectedString(ddHacPlotMode);
        if strcmp(appState.hacPlotMode, 'Subplots')
            appState.holdPlots = false;
            set(btnHold, 'Value', 0, 'String', 'Hold: Off');
        end
        setApp(appState);
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onHacRangeChanged(~, ~)
        appState = getApp();
        F = getCurrentHacFile(appState, getSelectedEntries());
        if isempty(F)
            return;
        end
        appState.hacRange = updateRangeState(appState.hacRange, F.id, edtHacStart, edtHacEnd, size(F.dataMatrix, 1));
        setApp(appState);
        autoPlotCurrentSelection();
    end

    function onHacChannelSelectionChanged(~, ~)
        autoPlotCurrentSelection();
    end

    function onTabChanged(~, ~)
        appState = getApp();
        if isCurrentTab(tabGroup, tabHac)
            appState.activeTab = 'hac';
        else
            appState.activeTab = 'ide';
        end
        setApp(appState);
        refreshContextControls();
        autoPlotCurrentSelection();
    end

    function onOpenIdeTimeFigure(~, ~)
        appState = getApp();
        if isempty(appState.lastIdeRender)
            setStatus('Status: no current IDE view to open.');
            return;
        end
        renderCurrentIdeFigure(appState.lastIdeRender, 'time');
    end

    function onOpenIdePsdFigure(~, ~)
        appState = getApp();
        if isempty(appState.lastIdeRender)
            setStatus('Status: no current IDE view to open.');
            return;
        end
        renderCurrentIdeFigure(appState.lastIdeRender, 'psd');
    end

    function onOpenHacFigure(~, ~)
        appState = getApp();
        if isempty(appState.lastHacRender)
            setStatus('Status: no current HAC view to open.');
            return;
        end
        renderCurrentHacFigure(appState.lastHacRender);
    end

    function onResize(~, ~)
        figPos = get(fig, 'Position');
        fw = max(figPos(3), 1380);
        fh = max(figPos(4), 860);
        if figPos(3) ~= fw || figPos(4) ~= fh
            figPos(3) = fw;
            figPos(4) = fh;
            set(fig, 'Position', figPos);
        end

        outerMargin = 15;
        gap = 15;
        panelW = 380;
        panelH = fh - 2 * outerMargin;
        tabX = outerMargin + panelW + gap;
        tabW = fw - tabX - outerMargin;
        tabH = panelH;

        set(panel, 'Position', [outerMargin outerMargin panelW panelH]);
        set(tabGroup, 'Position', [tabX outerMargin tabW tabH]);

        contentW = panelW - 30;
        rowH = 28;
        topY = panelH - 64;
        btnW = floor((contentW - 20) / 3);
        set(btnLoad, 'Position', [15 topY btnW rowH]);
        set(btnDelete, 'Position', [15 + btnW + 10 topY btnW rowH]);
        set(btnClear, 'Position', [15 + 2 * (btnW + 10) topY btnW rowH]);
        set(edtFile, 'Position', [15 topY - 36 contentW 24]);
        set(lblLoadedFiles, 'Position', [15 topY - 60 100 16]);
        set(lstFiles, 'Position', [15 topY - 254 contentW 188]);

        statusY = 18;
        statusH = 88;
        actionY = statusY + statusH + 14;
        set(btnPlot, 'Position', [15 actionY btnW rowH]);
        set(btnDemean, 'Position', [15 + btnW + 10 actionY btnW rowH]);
        set(btnHold, 'Position', [15 + 2 * (btnW + 10) actionY btnW rowH]);
        set(lblStatus, 'Position', [15 statusY contentW statusH]);

        sharedBottom = actionY + 38;
        sharedTop = topY - 270;
        sharedH = max(360, sharedTop - sharedBottom);
        set(grpIde, 'Position', [15 sharedBottom contentW sharedH]);
        set(grpHac, 'Position', [15 sharedBottom contentW sharedH]);

        groupW = contentW;
        ideH = sharedH;
        set(lblIdeXAxis, 'Position', [12 ideH - 54 55 16]);
        set(ddIdeXAxis, 'Position', [72 ideH - 57 groupW - 90 22]);
        set(lblIdePlotMode, 'Position', [12 ideH - 80 60 16]);
        set(ddIdePlotMode, 'Position', [72 ideH - 83 groupW - 90 22]);
        set(lblIdeRange, 'Position', [12 ideH - 106 52 16]);
        set(edtIdeStart, 'Position', [72 ideH - 109 76 22]);
        set(lblIdeRangeSep, 'Position', [152 ideH - 106 14 16]);
        set(edtIdeEnd, 'Position', [170 ideH - 109 76 22]);
        set(lblIdeRangeHint, 'Position', [252 ideH - 106 82 16]);
        set(lblIdeChannels, 'Position', [12 ideH - 132 60 16]);
        listTop = ideH - 136;
        tableH = max(82, min(116, floor(ideH * 0.23)));
        euGroupBlockH = 76;
        channelH = max(78, listTop - tableH - euGroupBlockH - 24);
        set(lstIdeChannels, 'Position', [12 listTop - channelH 320 channelH]);
        groupLabelY = listTop - channelH - 20;
        row1Y = groupLabelY - 22;
        row2Y = row1Y - 24;
        set(lblEuGroup, 'Position', [12 groupLabelY 110 16]);
        set(lblEuProx, 'Position', [12 row1Y 36 16]);
        set(edtEuProx, 'Position', [50 row1Y - 2 68 22]);
        set(lblEuFb, 'Position', [132 row1Y 28 16]);
        set(edtEuFb, 'Position', [160 row1Y - 2 68 22]);
        set(lblEuAcc, 'Position', [12 row2Y 36 16]);
        set(edtEuAcc, 'Position', [50 row2Y - 2 68 22]);
        set(lblEuPos, 'Position', [132 row2Y 28 16]);
        set(edtEuPos, 'Position', [160 row2Y - 2 68 22]);
        set(btnIdeEuSuffixApply, 'Position', [238 row2Y - 2 94 46]);
        tableLabelY = row2Y - 28;
        set(lblEuTable, 'Position', [12 tableLabelY 110 16]);
        set(tblIdeEu, 'Position', [12 12 320 tableLabelY - 12]);

        hacH = sharedH;
        set(lblHacPreset, 'Position', [12 hacH - 54 52 16]);
        set(ddHacPreset, 'Position', [72 hacH - 57 groupW - 90 22]);
        set(lblHacPlotMode, 'Position', [12 hacH - 80 60 16]);
        set(ddHacPlotMode, 'Position', [72 hacH - 83 groupW - 90 22]);
        set(lblHacRange, 'Position', [12 hacH - 106 52 16]);
        set(edtHacStart, 'Position', [72 hacH - 109 76 22]);
        set(lblHacRangeSep, 'Position', [152 hacH - 106 14 16]);
        set(edtHacEnd, 'Position', [170 hacH - 109 76 22]);
        set(lblHacRangeHint, 'Position', [252 hacH - 106 82 16]);
        set(lblHacChannels, 'Position', [12 hacH - 132 60 16]);
        set(lstHacChannels, 'Position', [12 12 320 hacH - 150]);

        tw = tabW;
        th = tabH;
        topLabelY = th - 48;
        rightInset = 24;
        usableW = tw - 40;
        timeAreaH = max(240, floor((th - 160) / 2));
        psdAreaH = timeAreaH;
        set(lblIdeSelected, 'Position', [20 topLabelY usableW - 220 18]);
        set(lblIdeContext, 'Position', [20 topLabelY - 22 usableW - 220 18]);
        set(btnIdeTimeFigure, 'Position', [tw - rightInset - 190 topLabelY - 4 90 26]);
        set(btnIdePsdFigure, 'Position', [tw - rightInset - 90 topLabelY - 4 90 26]);
        set(pnlIdeTime, 'Position', [20 60 + psdAreaH + 30 usableW timeAreaH]);
        set(pnlIdePsd, 'Position', [20 40 usableW psdAreaH]);

        set(lblHacSelected, 'Position', [20 topLabelY usableW - 120 18]);
        set(lblHacContext, 'Position', [20 topLabelY - 22 usableW - 120 18]);
        set(btnHacFigure, 'Position', [tw - rightInset - 90 topLabelY - 4 90 26]);
        set(pnlHacPlot, 'Position', [20 40 usableW th - 130]);

        layoutAxesArea(pnlIdeTime);
        layoutAxesArea(pnlIdePsd);
        layoutAxesArea(pnlHacPlot);
    end

    function refreshFileList(preferredEntries)
        if nargin < 1
            preferredEntries = [];
        end
        appState = getApp();
        entries = buildFileListEntries(appState);
        if isempty(entries)
            set(lstFiles, 'String', {'(none)'}, 'Value', 1, 'UserData', struct('type', {}, 'id', {}, 'label', {}));
            return;
        end
        labels = {entries.label};
        value = mapPreferredEntries(entries, preferredEntries);
        if isempty(value)
            value = 1:min(1, numel(labels));
        end
        set(lstFiles, 'String', labels, 'Value', value, 'UserData', entries);
    end

    function refreshContextControls()
        appState = getApp();
        entries = getSelectedEntries();
        updateSelectedFileText(entries);
        set(grpIde, 'Visible', ternaryVisible(strcmp(appState.activeTab, 'ide')));
        set(grpHac, 'Visible', ternaryVisible(strcmp(appState.activeTab, 'hac')));
        set(ddIdePlotMode, 'Value', popupValueFromItems(ddIdePlotMode, appState.idePlotMode));
        set(ddIdeXAxis, 'Value', popupValueFromItems(ddIdeXAxis, appState.ideXAxisMode));
        set(ddHacPlotMode, 'Value', popupValueFromItems(ddHacPlotMode, appState.hacPlotMode));
        refreshIdeControls(appState, entries);
        refreshHacControls(appState, entries);
    end

    function refreshIdeControls(appState, entries)
        F = getCurrentIdeFile(appState, entries);
        if isempty(F)
            set(lstIdeChannels, 'String', {'(none)'}, 'Value', 1);
            set(tblIdeEu, 'Data', cell(0, 3));
            setIdeSuffixEuControls([]);
            set(edtIdeStart, 'String', '1');
            set(edtIdeEnd, 'String', '1');
            set(lblIdeSelected, 'String', 'Active IDE file: (none)');
            set(lblIdeContext, 'String', 'Mode / X Axis / Range / Fs');
            return;
        end

        rangeState = getRangeState(appState.ideRange, F.id, size(F.rawData, 1));
        set(edtIdeStart, 'String', num2str(rangeState.startIdx));
        set(edtIdeEnd, 'String', num2str(rangeState.endIdx));
        channelItems = {F.channelDefs.displayName};
        if isempty(channelItems)
            channelItems = {'(none)'};
            channelValue = 1;
        else
            prev = getListboxItems(lstIdeChannels);
            prevSel = getListSelectionIndices(lstIdeChannels, numel(prev));
            preferred = {};
            if ~isempty(prev) && ~isempty(prevSel) && ~(numel(prev) == 1 && strcmp(prev{1}, '(none)'))
                preferred = prev(prevSel);
            end
            channelValue = mapNamesToIndices(channelItems, preferred);
            if isempty(channelValue)
                channelValue = find(F.enabledChannels);
                if isempty(channelValue)
                    channelValue = 1:min(1, numel(channelItems));
                end
            end
        end
        set(lstIdeChannels, 'String', channelItems, 'Value', channelValue);
        tblData = cell(numel(F.channelDefs), 3);
        for i = 1:numel(F.channelDefs)
            tblData{i, 1} = F.channelDefs(i).displayName;
            tblData{i, 2} = F.euPerChannel(i);
            tblData{i, 3} = logical(F.enabledChannels(i));
        end
        set(tblIdeEu, 'Data', tblData);
        setIdeSuffixEuControls(F);
        set(lblIdeSelected, 'String', sprintf('Active IDE file: %s', F.displayName));
        set(lblIdeContext, 'String', sprintf('Mode: %s | X Axis: %s | Range: %d-%d | Fs: %.6g Hz | Channels: %d', ...
            appState.idePlotMode, appState.ideXAxisMode, rangeState.startIdx, rangeState.endIdx, F.fs, numel(F.channelDefs)));
    end

    function setIdeSuffixEuControls(F)
        handles = {edtEuProx, edtEuFb, edtEuAcc, edtEuPos};
        labels = {'Prox', 'FB', 'ACC', 'POS'};
        if isempty(F)
            for i = 1:numel(handles)
                set(handles{i}, 'String', '', 'Enable', 'off');
            end
            set(btnIdeEuSuffixApply, 'Enable', 'off');
            return;
        end

        anyEnabled = false;
        for i = 1:numel(labels)
            category = labels{i};
            mask = strcmp({F.channelDefs.suffixCategory}, category);
            if any(mask)
                anyEnabled = true;
                vals = F.euPerChannel(mask);
                if all(abs(vals - vals(1)) < 1e-12)
                    txt = num2str(vals(1));
                else
                    txt = 'mixed';
                end
                set(handles{i}, 'String', txt, 'Enable', 'on');
            else
                set(handles{i}, 'String', '', 'Enable', 'off');
            end
        end
        if anyEnabled
            set(btnIdeEuSuffixApply, 'Enable', 'on');
        else
            set(btnIdeEuSuffixApply, 'Enable', 'off');
        end
    end

    function refreshHacControls(appState, entries)
        F = getCurrentHacFile(appState, entries);
        if isempty(F)
            setPopupItemsCompat(ddHacPreset, {'(none)'}, '(none)');
            set(lstHacChannels, 'String', {'(none)'}, 'Value', 1);
            set(edtHacStart, 'String', '1');
            set(edtHacEnd, 'String', '1');
            set(lblHacSelected, 'String', 'Active HAC file: (none)');
            set(lblHacContext, 'String', 'Preset / Mode / Range / X Axis');
            return;
        end

        rangeState = getRangeState(appState.hacRange, F.id, size(F.dataMatrix, 1));
        set(edtHacStart, 'String', num2str(rangeState.startIdx));
        set(edtHacEnd, 'String', num2str(rangeState.endIdx));
        groupNames = {F.groups.name};
        if isempty(groupNames)
            groupNames = {'(none)'};
        end
        prevGroup = getPopupSelectedString(ddHacPreset);
        setPopupItemsCompat(ddHacPreset, groupNames, prevGroup);
        G = getSelectedHacGroup(F, ddHacPreset);
        if isempty(G)
            set(lstHacChannels, 'String', {'(none)'}, 'Value', 1);
        else
            items = G.displayNames;
            prev = getListboxItems(lstHacChannels);
            prevSel = getListSelectionIndices(lstHacChannels, numel(prev));
            preferred = {};
            if ~isempty(prev) && ~isempty(prevSel) && ~(numel(prev) == 1 && strcmp(prev{1}, '(none)'))
                preferred = prev(prevSel);
            end
            value = mapNamesToIndices(items, preferred);
            if isempty(value)
                value = 1:numel(items);
            end
            set(lstHacChannels, 'String', items, 'Value', value);
        end
        xSource = getHacXAxisSummary(F);
        set(lblHacSelected, 'String', sprintf('Active HAC file: %s', F.displayName));
        set(lblHacContext, 'String', sprintf('Preset: %s | Mode: %s | Range: %d-%d | X Axis: %s', ...
            getPopupSelectedString(ddHacPreset), appState.hacPlotMode, rangeState.startIdx, rangeState.endIdx, xSource));
    end

    function updateSelectedFileText(entries)
        if isempty(entries)
            set(edtFile, 'String', 'No file selected');
        elseif numel(entries) == 1
            set(edtFile, 'String', entries(1).label);
        else
            set(edtFile, 'String', sprintf('%d files selected', numel(entries)));
        end
    end

    function entries = getSelectedEntries()
        items = get(lstFiles, 'UserData');
        entries = struct('type', {}, 'id', {}, 'label', {});
        if isempty(items)
            return;
        end
        rawString = get(lstFiles, 'String');
        if ischar(rawString) && strcmp(rawString, '(none)')
            return;
        end
        sel = getListSelectionIndices(lstFiles, numel(items));
        if isempty(sel)
            return;
        end
        entries = items(sel);
    end

    function autoPlotCurrentSelection()
        appState = getApp();
        try
            if strcmp(appState.activeTab, 'hac')
                if ~isempty(getCurrentHacFile(appState, getSelectedEntries()))
                    plotHacPage();
                end
            else
                if ~isempty(getCurrentIdeFile(appState, getSelectedEntries()))
                    plotIdePage();
                end
            end
        catch
            % Ignore transient states during UI refresh.
        end
    end

    function plotIdePage()
        appState = getApp();
        F = getCurrentIdeFile(appState, getSelectedEntries());
        if isempty(F)
            setStatus('Status: select an IDE trace file first.');
            return;
        end

        items = getListboxItems(lstIdeChannels);
        if isempty(items) || (numel(items) == 1 && strcmp(items{1}, '(none)'))
            setStatus('Status: no IDE channels available.');
            return;
        end
        sel = getListSelectionIndices(lstIdeChannels, numel(items));
        if isempty(sel)
            sel = find(F.enabledChannels);
        end
        sel = sel(:).';
        if isempty(sel)
            setStatus('Status: no IDE channels selected.');
            return;
        end

        enabledMask = F.enabledChannels(sel);
        sel = sel(enabledMask);
        if isempty(sel)
            setStatus('Status: selected IDE channels are disabled.');
            return;
        end

        rangeState = updateRangeState(appState.ideRange, F.id, edtIdeStart, edtIdeEnd, size(F.rawData, 1));
        appState.ideRange = rangeState;
        setApp(appState);
        [xData, Y, names, rangeStart, rangeEnd, xLabelText] = extractIdePlotSeries(F, sel, rangeState.startIdx, rangeState.endIdx, appState.demean, appState.ideXAxisMode);
        if isempty(Y)
            setStatus('Status: no IDE samples available for plotting.');
            return;
        end

        modeName = appState.idePlotMode;
        if strcmp(modeName, 'Subplots')
            renderIdeTimeSubplots(F, xData, Y, names, xLabelText);
            renderIdePsdSubplots(F, Y, names);
        else
            renderIdeTimeOverlay(F, xData, Y, names, xLabelText, appState.holdPlots);
            renderIdePsdOverlay(F, Y, names, appState.holdPlots);
        end

        appState = getApp();
        appState.lastIdeRender = struct( ...
            'fileId', F.id, ...
            'fileName', F.displayName, ...
            'mode', modeName, ...
            'colIdx', sel, ...
            'displayNames', {names}, ...
            'layout', chooseTightGrid(numel(sel)), ...
            'xAxisMode', appState.ideXAxisMode, ...
            'rangeStart', rangeStart, ...
            'rangeEnd', rangeEnd, ...
            'demean', appState.demean);
        setApp(appState);
        set(lblIdeContext, 'String', sprintf('Mode: %s | X Axis: %s | Range: %d-%d | Fs: %.6g Hz | Channels: %d', ...
            modeName, appState.ideXAxisMode, rangeStart, rangeEnd, F.fs, numel(sel)));
        setStatus(sprintf('Status: plotted %d IDE channel(s) from %s in %s mode.', numel(sel), F.displayName, lower(modeName)));
    end

    function plotHacPage()
        appState = getApp();
        F = getCurrentHacFile(appState, getSelectedEntries());
        if isempty(F)
            setStatus('Status: select a HAC trace file first.');
            return;
        end

        G = getSelectedHacGroup(F, ddHacPreset);
        if isempty(G)
            setStatus('Status: selected HAC file has no matching preset groups.');
            return;
        end

        items = getListboxItems(lstHacChannels);
        sel = getListSelectionIndices(lstHacChannels, numel(items));
        if isempty(sel)
            sel = 1:numel(G.columnIdx);
        end
        colIdx = G.columnIdx(sel);
        names = G.displayNames(sel);
        if isempty(colIdx)
            setStatus('Status: no HAC channels selected.');
            return;
        end

        rangeState = updateRangeState(appState.hacRange, F.id, edtHacStart, edtHacEnd, size(F.dataMatrix, 1));
        appState.hacRange = rangeState;
        setApp(appState);
        [xData, Y, rangeStart, rangeEnd, xLabelText, xSource] = extractHacPlotSeries(F, colIdx, rangeState.startIdx, rangeState.endIdx, appState.demean);
        if isempty(Y)
            setStatus('Status: no HAC samples available for plotting.');
            return;
        end

        modeName = appState.hacPlotMode;
        if strcmp(modeName, 'Subplots')
            renderHacSubplots(F, G.name, xData, Y, names, xLabelText);
        else
            renderHacOverlay(F, G.name, xData, Y, names, xLabelText, appState.holdPlots);
        end

        appState = getApp();
        appState.lastHacRender = struct( ...
            'fileId', F.id, ...
            'fileName', F.displayName, ...
            'mode', modeName, ...
            'groupName', G.name, ...
            'colIdx', colIdx, ...
            'displayNames', {names}, ...
            'layout', chooseTightGrid(numel(colIdx)), ...
            'rangeStart', rangeStart, ...
            'rangeEnd', rangeEnd, ...
            'demean', appState.demean);
        setApp(appState);
        set(lblHacContext, 'String', sprintf('Preset: %s | Mode: %s | Range: %d-%d | X Axis: %s', ...
            G.name, modeName, rangeStart, rangeEnd, xSource));
        setStatus(sprintf('Status: plotted %d HAC channel(s) from %s in %s mode.', numel(colIdx), F.displayName, lower(modeName)));
    end

    function renderIdeTimeOverlay(F, xData, Y, names, xLabelText, doHold)
        appState = getApp();
        reuse = doHold && isstruct(appState.lastIdeRender) && isfield(appState.lastIdeRender, 'mode') && strcmp(appState.lastIdeRender.mode, 'Overlay') ...
            && ~isempty(axIdeTime) && ishghandle(axIdeTime);
        if ~reuse
            clearIdeRenderArea(false);
            axIdeTime = createHostAxis(pnlIdeTime, sprintf('IDE Time Domain - %s', F.displayName), xLabelText, 'Value', false);
        end
        hold(axIdeTime, 'on');
        for i = 1:size(Y, 2)
            plot(axIdeTime, xData, Y(:, i), 'LineWidth', 1.0, ...
                'DisplayName', names{i});
        end
        hold(axIdeTime, 'off');
        grid(axIdeTime, 'on');
        xlabel(axIdeTime, xLabelText);
        ylabel(axIdeTime, 'Value');
        title(axIdeTime, sprintf('IDE Time Domain - %s', F.displayName), 'Interpreter', 'none');
        applyGenericXLimits(axIdeTime, xData);
        applyOverlayLegendLayout(axIdeTime);
    end

    function renderIdePsdOverlay(F, Y, names, doHold)
        appState = getApp();
        reuse = doHold && isstruct(appState.lastIdeRender) && isfield(appState.lastIdeRender, 'mode') && strcmp(appState.lastIdeRender.mode, 'Overlay') ...
            && ~isempty(axIdePsd) && ishghandle(axIdePsd);
        if ~reuse
            clearIdePsdAreaOnly();
            axIdePsd = createHostAxis(pnlIdePsd, sprintf('IDE PSD - %s', F.displayName), 'Frequency (Hz)', 'PSD', true);
        end
        hold(axIdePsd, 'on');
        xMin = inf;
        xMax = -inf;
        for i = 1:size(Y, 2)
            [freq, pxx] = computeIdePsd(Y(:, i), F.fs);
            if isempty(freq)
                continue;
            end
            loglog(axIdePsd, freq, pxx, 'LineWidth', 1.0, ...
                'DisplayName', names{i});
            xMin = min(xMin, freq(1));
            xMax = max(xMax, freq(end));
        end
        hold(axIdePsd, 'off');
        grid(axIdePsd, 'on');
        set(axIdePsd, 'XScale', 'log', 'YScale', 'log');
        xlabel(axIdePsd, 'Frequency (Hz)');
        ylabel(axIdePsd, 'PSD');
        title(axIdePsd, sprintf('IDE PSD - %s', F.displayName), 'Interpreter', 'none');
        applyNumericXLimits(axIdePsd, xMin, xMax);
        applyOverlayLegendLayout(axIdePsd);
    end

    function renderIdeTimeSubplots(F, xData, Y, names, xLabelText)
        clearIdeTimeAreaOnly();
        axIdeTime = [];
        renderLineSubplots(pnlIdeTime, xData, Y, names, chooseTightGrid(size(Y, 2)), ...
            sprintf('IDE Time Domain - %s', F.displayName), xLabelText, 'Value');
    end

    function renderIdePsdSubplots(F, Y, names)
        clearIdePsdAreaOnly();
        axIdePsd = [];
        nPlots = size(Y, 2);
        layout = chooseTightGrid(nPlots);
        axesHandles = createAxesGrid(pnlIdePsd, layout, nPlots);
        for i = 1:nPlots
            [freq, pxx] = computeIdePsd(Y(:, i), F.fs);
            if ~isempty(freq)
                loglog(axesHandles(i), freq, pxx, 'LineWidth', 1.0);
                set(axesHandles(i), 'XScale', 'log', 'YScale', 'log');
                applyNumericXLimits(axesHandles(i), freq(1), freq(end));
            end
            grid(axesHandles(i), 'on');
            title(axesHandles(i), names{i}, 'Interpreter', 'none');
            styleSubplotAxis(axesHandles(i), i, layout, 'Frequency (Hz)', 'PSD');
        end
    end

    function renderHacOverlay(F, groupName, xData, Y, names, xLabelText, doHold)
        appState = getApp();
        reuse = doHold && isstruct(appState.lastHacRender) && isfield(appState.lastHacRender, 'mode') && strcmp(appState.lastHacRender.mode, 'Overlay') ...
            && ~isempty(axHac) && ishghandle(axHac);
        if ~reuse
            clearHacRenderArea(false);
            axHac = createHostAxis(pnlHacPlot, sprintf('HAC Time Domain - %s', F.displayName), xLabelText, 'Value', false);
        end
        hold(axHac, 'on');
        for i = 1:size(Y, 2)
            plot(axHac, xData, Y(:, i), 'LineWidth', 1.0, ...
                'DisplayName', names{i});
        end
        hold(axHac, 'off');
        grid(axHac, 'on');
        xlabel(axHac, xLabelText);
        ylabel(axHac, 'Value');
        title(axHac, sprintf('HAC Time Domain - %s | %s', groupName, F.displayName), 'Interpreter', 'none');
        applyGenericXLimits(axHac, xData);
        applyOverlayLegendLayout(axHac);
    end

    function renderHacSubplots(F, groupName, xData, Y, names, xLabelText)
        clearHacRenderArea(false);
        axHac = [];
        renderLineSubplots(pnlHacPlot, xData, Y, names, chooseTightGrid(size(Y, 2)), ...
            sprintf('HAC Time Domain - %s | %s', groupName, F.displayName), xLabelText, 'Value');
    end

    function renderCurrentIdeFigure(renderInfo, viewKind)
        appState = getApp();
        [F, ok] = getIdeFileById(appState, renderInfo.fileId);
        if ~ok
            showAlertCompat(fig, 'The source IDE file is no longer loaded.', 'Open current view');
            return;
        end
        [xData, Y, names, ~, ~, xLabelText] = extractIdePlotSeries(F, renderInfo.colIdx, renderInfo.rangeStart, renderInfo.rangeEnd, renderInfo.demean, renderInfo.xAxisMode);
        hFig = figure('Name', sprintf('%s - %s', renderInfo.fileName, upper(viewKind)), ...
            'NumberTitle', 'off', 'Color', 'w');
        if strcmp(viewKind, 'time')
            if strcmp(renderInfo.mode, 'Subplots')
                renderLineSubplots(hFig, xData, Y, names, renderInfo.layout, ...
                    sprintf('IDE Time Domain - %s', renderInfo.fileName), xLabelText, 'Value');
            else
                ax = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
                hold(ax, 'on');
                for i = 1:size(Y, 2)
                    plot(ax, xData, Y(:, i), 'LineWidth', 1.0, 'DisplayName', names{i});
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, xLabelText);
                ylabel(ax, 'Value');
                applyGenericXLimits(ax, xData);
                title(ax, sprintf('IDE Time Domain - %s', renderInfo.fileName), 'Interpreter', 'none');
                applyOverlayLegendLayout(ax);
            end
        else
            if strcmp(renderInfo.mode, 'Subplots')
                nPlots = size(Y, 2);
                axesHandles = createAxesGrid(hFig, renderInfo.layout, nPlots);
                for i = 1:nPlots
                    [freq, pxx] = computeIdePsd(Y(:, i), F.fs);
                    if ~isempty(freq)
                        loglog(axesHandles(i), freq, pxx, 'LineWidth', 1.0);
                        set(axesHandles(i), 'XScale', 'log', 'YScale', 'log');
                        applyNumericXLimits(axesHandles(i), freq(1), freq(end));
                    end
                    grid(axesHandles(i), 'on');
                    title(axesHandles(i), names{i}, 'Interpreter', 'none');
                    styleSubplotAxis(axesHandles(i), i, renderInfo.layout, 'Frequency (Hz)', 'PSD');
                end
                try
                    sgtitle(hFig, sprintf('IDE PSD - %s', renderInfo.fileName), 'Interpreter', 'none');
                catch
                end
            else
                ax = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
                hold(ax, 'on');
                xMin = inf;
                xMax = -inf;
                for i = 1:size(Y, 2)
                    [freq, pxx] = computeIdePsd(Y(:, i), F.fs);
                    if isempty(freq)
                        continue;
                    end
                    loglog(ax, freq, pxx, 'LineWidth', 1.0, 'DisplayName', names{i});
                    xMin = min(xMin, freq(1));
                    xMax = max(xMax, freq(end));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                set(ax, 'XScale', 'log', 'YScale', 'log');
                xlabel(ax, 'Frequency (Hz)');
                ylabel(ax, 'PSD');
                applyNumericXLimits(ax, xMin, xMax);
                title(ax, sprintf('IDE PSD - %s', renderInfo.fileName), 'Interpreter', 'none');
                applyOverlayLegendLayout(ax);
            end
        end
    end

    function renderCurrentHacFigure(renderInfo)
        appState = getApp();
        [F, ok] = getHacFileById(appState, renderInfo.fileId);
        if ~ok
            showAlertCompat(fig, 'The source HAC file is no longer loaded.', 'Open current view');
            return;
        end
        [xData, Y, ~, ~, xLabelText] = extractHacPlotSeries(F, renderInfo.colIdx, renderInfo.rangeStart, renderInfo.rangeEnd, renderInfo.demean);
        hFig = figure('Name', renderInfo.fileName, 'NumberTitle', 'off', 'Color', 'w');
        if strcmp(renderInfo.mode, 'Subplots')
            renderLineSubplots(hFig, xData, Y, renderInfo.displayNames, renderInfo.layout, ...
                sprintf('HAC Time Domain - %s | %s', renderInfo.groupName, renderInfo.fileName), xLabelText, 'Value');
        else
            ax = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.10 0.12 0.84 0.78], 'Box', 'on');
            hold(ax, 'on');
            for i = 1:size(Y, 2)
                plot(ax, xData, Y(:, i), 'LineWidth', 1.0, 'DisplayName', renderInfo.displayNames{i});
            end
            hold(ax, 'off');
            grid(ax, 'on');
            xlabel(ax, xLabelText);
            ylabel(ax, 'Value');
            applyGenericXLimits(ax, xData);
            title(ax, sprintf('HAC Time Domain - %s | %s', renderInfo.groupName, renderInfo.fileName), 'Interpreter', 'none');
            applyOverlayLegendLayout(ax);
        end
    end

    function clearIdeRenderArea(resetHandles)
        if nargin < 1
            resetHandles = false;
        end
        delete(findall(pnlIdeTime, 'Type', 'axes'));
        delete(findall(pnlIdePsd, 'Type', 'axes'));
        if resetHandles
            axIdeTime = [];
            axIdePsd = [];
        end
    end

    function clearIdeTimeAreaOnly()
        delete(findall(pnlIdeTime, 'Type', 'axes'));
    end

    function clearIdePsdAreaOnly()
        delete(findall(pnlIdePsd, 'Type', 'axes'));
    end

    function clearHacRenderArea(resetHandles)
        if nargin < 1
            resetHandles = false;
        end
        delete(findall(pnlHacPlot, 'Type', 'axes'));
        if resetHandles
            axHac = [];
        end
    end

    function setStatus(txt)
        set(lblStatus, 'String', txt);
    end
end

function varargout = dispatchTraceAction(action, varargin)
switch lower(strtrim(action))
    case 'loadonetracefile'
        varargout{1} = loadOneTraceFile(varargin{1});
    case 'parseidetracefile'
        varargout{1} = parseIdeTraceFile(varargin{1});
    case 'parsehactracefile'
        varargout{1} = parseHacTraceFile(varargin{1});
    otherwise
        error('Unsupported action: %s', action);
end
end

function app = initTraceAppState()
app.ideFiles = {};
app.hacFiles = {};
app.fileOrder = struct('type', {}, 'id', {});
app.nextFileId = 1;
app.lastOpenDir = pwd;
app.activeTab = 'ide';
app.idePlotMode = 'Overlay';
app.ideXAxisMode = 'Sample Index';
app.hacPlotMode = 'Overlay';
app.demean = false;
app.holdPlots = false;
app.ideRange = struct('fileId', 0, 'startIdx', 1, 'endIdx', 1);
app.hacRange = struct('fileId', 0, 'startIdx', 1, 'endIdx', 1);
app.lastIdeRender = [];
app.lastHacRender = [];
end

function F = loadOneTraceFile(filePath)
[~, fileName, ext] = fileparts(filePath);
ext = lower(ext);
if ~ismember(ext, {'.txt', '.csv'})
    error('Unsupported trace file type: %s', ext);
end

kind = detectTraceFileType(filePath);
switch kind
    case 'ide_trace'
        F = parseIdeTraceFile(filePath);
    case 'hac_trace'
        F = parseHacTraceFile(filePath);
    otherwise
        error('Unsupported trace file content.');
end

F.filePath = filePath;
F.fileName = [fileName, ext];
F.displayName = F.fileName;
end

function kind = detectTraceFileType(filePath)
kind = '';
[~, ~, ext] = fileparts(filePath);
ext = lower(ext);
if strcmp(ext, '.csv')
    kind = 'hac_trace';
    return;
end

lines = readTextLinesCompat(filePath, 8, {'utf-8', 'GBK', 'GB18030'});
if numel(lines) >= 5
    hasSample = ~isempty(regexpi(strtrim(lines{1}), '^sample frequency\s*:', 'once'));
    hasUndersample = ~isempty(regexpi(strtrim(lines{2}), '^undersample\s*:', 'once'));
    hasSignalNum = ~isempty(regexpi(strtrim(lines{3}), '^signal num\s*:', 'once'));
    hasBufferLength = ~isempty(regexpi(strtrim(lines{4}), '^buffer length\s*:', 'once'));
    if hasSample && hasUndersample && hasSignalNum && hasBufferLength
        kind = 'ide_trace';
        return;
    end
end
end

function F = parseIdeTraceFile(filePath)
lines = readTextLinesCompat(filePath, inf, {'utf-8', 'GBK', 'GB18030'});
if numel(lines) < 6
    error('IDE trace file is too short.');
end

sampleFrequency = parseHeaderScalar(lines{1}, 'sample frequency');
undersample = parseHeaderScalar(lines{2}, 'undersample');
signalNum = parseHeaderScalar(lines{3}, 'signal num');
bufferLength = parseHeaderScalar(lines{4}, 'Buffer length');
if ~isfinite(sampleFrequency) || sampleFrequency <= 0
    error('Invalid sample frequency in header.');
end
if ~isfinite(undersample) || undersample <= 0
    error('Invalid undersample value in header.');
end
if ~isfinite(signalNum) || signalNum < 1
    error('Invalid signal num in header.');
end
if ~isfinite(bufferLength) || bufferLength < 1
    error('Invalid Buffer length in header.');
end

rawHeaders = splitSemicolonLine(lines{5});
signalNum = round(signalNum);
bufferLength = round(bufferLength);
if numel(rawHeaders) < signalNum
    error('Header channel count does not match signal num.');
end
rawHeaders = rawHeaders(1:signalNum);

data = zeros(0, signalNum);
for i = 6:numel(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    row = parseWhitespaceNumericRow(line);
    if isempty(row)
        continue;
    end
    if numel(row) ~= signalNum
        error('Numeric row %d has %d columns; expected %d.', i, numel(row), signalNum);
    end
    data(end + 1, :) = row; %#ok<AGROW>
end
if size(data, 1) ~= bufferLength
    error('Data row count %d does not match Buffer length %d.', size(data, 1), bufferLength);
end

headers = normalizeHeaderNames(rawHeaders, signalNum);
channelDefs = buildIdeChannelDefs(headers);
F = struct();
F.type = 'ide_trace';
F.sampleFrequency = sampleFrequency;
F.undersample = undersample;
F.signalNum = signalNum;
F.bufferLength = bufferLength;
F.fs = sampleFrequency / undersample;
F.headerNames = headers;
F.channelDefs = channelDefs;
F.rawData = data;
F.sampleIndex = (1:size(data, 1)).';
F.timeSeconds = (double(F.sampleIndex) - 1) ./ F.fs;
F.euPerChannel = [channelDefs.defaultEu];
F.enabledChannels = true(1, numel(channelDefs));
F.scaledData = data;
F = applyIdeEuScaling(F);
end

function F = parseHacTraceFile(filePath)
lines = readTextLinesCompat(filePath, inf, {'GBK', 'GB18030', 'UTF-8'});
if numel(lines) < 3
    error('HAC trace file is too short.');
end

periodTokens = splitCsvLine(lines{1});
if numel(periodTokens) < 2 || ~strcmpi(strtrim(periodTokens{1}), 'Period(ms)')
    error('Cannot find valid Period(ms) header.');
end
periodMs = str2double(strtrim(periodTokens{2}));
if ~isfinite(periodMs) || periodMs <= 0
    error('Invalid Period(ms) value.');
end

headerTokens = splitCsvLine(lines{2});
if numel(headerTokens) < 2 || ~strcmpi(strtrim(headerTokens{1}), 'time')
    error('Cannot find valid HAC channel header line.');
end
headerTokens = headerTokens(2:end);
headerTokens = headerTokens(~cellfun(@isempty, headerTokens));
headers = normalizeHeaderNames(headerTokens, numel(headerTokens));
if isempty(headers)
    error('No HAC channels found.');
end

nCols = numel(headers);
timeText = cell(0, 1);
data = zeros(0, nCols);
for i = 3:numel(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end
    toks = splitCsvLine(line);
    while ~isempty(toks) && isempty(toks{end})
        toks(end) = [];
    end
    if numel(toks) < nCols + 1
        continue;
    end
    timeStr = strtrim(toks{1});
    nums = str2double(toks(2:(nCols + 1)));
    if ~all(isfinite(nums))
        continue;
    end
    timeText{end + 1, 1} = timeStr; %#ok<AGROW>
    data(end + 1, :) = nums(:).'; %#ok<AGROW>
end
if isempty(data)
    error('HAC data block is empty.');
end

channelDefs = buildSimpleChannelDefs(headers);
groups = buildHacGroups(channelDefs);
timeData = parseHacDateTimes(timeText);
elapsedSeconds = computeElapsedSeconds(timeData, periodMs, size(data, 1));

F = struct();
F.type = 'hac_trace';
F.periodMs = periodMs;
F.headerNames = headers;
F.channelDefs = channelDefs;
F.groups = groups;
F.rawTimeText = timeText;
F.timeData = timeData;
F.elapsedSeconds = elapsedSeconds;
F.sampleIndex = (1:size(data, 1)).';
F.dataMatrix = data;
end

function channelDefs = buildIdeChannelDefs(headers)
channelDefs = repmat(struct( ...
    'name', '', ...
    'displayName', '', ...
    'columnIdx', 0, ...
    'isProx', false, ...
    'suffixCategory', '', ...
    'defaultEu', 1.0), 1, numel(headers));
for i = 1:numel(headers)
    channelDefs(i).name = headers{i};
    channelDefs(i).displayName = headers{i};
    channelDefs(i).columnIdx = i;
    channelDefs(i).isProx = ~isempty(regexpi(headers{i}, 'prox', 'once'));
    channelDefs(i).suffixCategory = inferIdeSuffixCategory(headers{i});
    if strcmp(channelDefs(i).suffixCategory, 'Prox')
        channelDefs(i).defaultEu = 3.75;
    else
        channelDefs(i).defaultEu = 1.0;
    end
end
end

function category = inferIdeSuffixCategory(headerName)
category = '';
txt = regexprep(headerName, '\([^\)]*\)', '');
txt = regexprep(txt, '\[[^\]]*\]', '');
txt = regexprep(txt, '\s+', '');
txt = upper(txt);
if endsWith(txt, 'PROX')
    category = 'Prox';
elseif endsWith(txt, 'FB')
    category = 'FB';
elseif endsWith(txt, 'ACC')
    category = 'ACC';
elseif endsWith(txt, 'POS')
    category = 'POS';
end
end

function channelDefs = buildSimpleChannelDefs(headers)
channelDefs = repmat(struct('name', '', 'displayName', '', 'columnIdx', 0), 1, numel(headers));
for i = 1:numel(headers)
    channelDefs(i).name = headers{i};
    channelDefs(i).displayName = headers{i};
    channelDefs(i).columnIdx = i;
end
end

function groups = buildHacGroups(channelDefs)
headers = {channelDefs.displayName};
groups = struct('name', {}, 'columnIdx', {}, 'displayNames', {});
groups = appendHacGroup(groups, '位移', headers, '^位移');
groups = appendHacGroup(groups, '速度', headers, '^速度');
groups = appendHacGroup(groups, '前馈', headers, '^前馈');
groups = appendHacGroup(groups, '温度', headers, '^温度');
groups = appendHacGroup(groups, 'WS', headers, '^WS');
groups = appendHacGroup(groups, 'Motor', headers, '^Motor');
groups = appendHacGroup(groups, 'P', headers, '^P\d+');
groups = appendHacGroup(groups, 'All Channels', headers, '.*');
end

function groups = appendHacGroup(groups, name, headers, expr)
idx = find(~cellfun('isempty', regexp(headers, expr, 'once')));
if isempty(idx)
    return;
end
G = struct();
G.name = name;
G.columnIdx = idx;
G.displayNames = headers(idx);
groups(end + 1) = G; %#ok<AGROW>
end

function F = applyIdeEuScaling(F)
scaled = F.rawData;
for i = 1:size(scaled, 2)
    eu = F.euPerChannel(i);
    if ~isfinite(eu) || eu == 0
        eu = 1;
    end
    scaled(:, i) = scaled(:, i) ./ eu;
end
F.scaledData = scaled;
end

function [xData, Y, names, startIdx, endIdx, xLabelText] = extractIdePlotSeries(F, selectedCols, startRef, endRef, doDemean, xAxisMode)
nSamples = size(F.scaledData, 1);
[startIdx, endIdx] = sanitizeRange(startRef, endRef, nSamples);
selectedCols = selectedCols(:).';
selectedCols = selectedCols(selectedCols >= 1 & selectedCols <= size(F.scaledData, 2));
names = {F.channelDefs(selectedCols).displayName};
if isempty(selectedCols)
    xData = [];
    Y = [];
    xLabelText = 'Sample Index';
    return;
end
if strcmp(xAxisMode, 'Time (s)')
    xData = F.timeSeconds(startIdx:endIdx);
    xLabelText = 'Time (s)';
else
    xData = F.sampleIndex(startIdx:endIdx);
    xLabelText = 'Sample Index';
end
Y = F.scaledData(startIdx:endIdx, selectedCols);
if doDemean
    Y = removeColumnMeans(Y);
end
end

function [xData, Y, startIdx, endIdx, xLabelText, xSource] = extractHacPlotSeries(F, selectedCols, startRef, endRef, doDemean)
nSamples = size(F.dataMatrix, 1);
[startIdx, endIdx] = sanitizeRange(startRef, endRef, nSamples);
selectedCols = selectedCols(:).';
selectedCols = selectedCols(selectedCols >= 1 & selectedCols <= size(F.dataMatrix, 2));
if isempty(selectedCols)
    xData = [];
    Y = [];
    xLabelText = 'Sample Index';
    xSource = 'Sample Index';
    return;
end

if ~isempty(F.timeData) && all(~isnat(F.timeData))
    xData = F.timeData(startIdx:endIdx);
    xLabelText = 'Time';
    xSource = 'Datetime';
elseif ~isempty(F.elapsedSeconds) && all(isfinite(F.elapsedSeconds))
    xData = F.elapsedSeconds(startIdx:endIdx);
    xLabelText = 'Elapsed Time (s)';
    xSource = 'Elapsed Time (s)';
else
    xData = F.sampleIndex(startIdx:endIdx);
    xLabelText = 'Sample Index';
    xSource = 'Sample Index';
end
Y = F.dataMatrix(startIdx:endIdx, selectedCols);
if doDemean
    Y = removeColumnMeans(Y);
end
end

function [freq, pxx] = computeIdePsd(y, fs)
freq = [];
pxx = [];
y = y(:);
valid = isfinite(y);
y = y(valid);
n = numel(y);
if n < 4 || ~isfinite(fs) || fs <= 0
    return;
end
try
    [pxx, freq] = periodogram(y, hann(n), n, fs, 'onesided');
catch
    return;
end
valid = isfinite(freq) & isfinite(pxx) & freq > 0 & pxx > 0;
freq = freq(valid);
pxx = pxx(valid);
if numel(freq) > 2
    freq = freq(3:end);
    pxx = pxx(3:end);
end
end

function renderLineSubplots(parentObj, xData, Y, names, layout, figTitle, xLabelText, yLabelText)
axesHandles = createAxesGrid(parentObj, layout, size(Y, 2));
for i = 1:numel(axesHandles)
    plot(axesHandles(i), xData, Y(:, i), 'LineWidth', 1.0);
    grid(axesHandles(i), 'on');
    title(axesHandles(i), names{i}, 'Interpreter', 'none');
    styleSubplotAxis(axesHandles(i), i, layout, xLabelText, yLabelText);
    applyGenericXLimits(axesHandles(i), xData);
end
if strcmp(get(parentObj, 'Type'), 'figure')
    try
        sgtitle(parentObj, figTitle, 'Interpreter', 'none');
    catch
    end
end
end

function ax = createHostAxis(parentObj, ttl, xLabelText, yLabelText, logY)
ax = axes('Parent', parentObj, 'Units', 'normalized', ...
    'Position', [0.08 0.12 0.88 0.80], 'Box', 'on');
title(ax, ttl, 'Interpreter', 'none');
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
grid(ax, 'on');
if nargin >= 5 && logY
    set(ax, 'XScale', 'log', 'YScale', 'log');
end
end

function applyOverlayLegendLayout(ax)
if isempty(ax) || ~ishghandle(ax)
    return;
end
lines = findobj(ax, 'Type', 'line', '-not', 'Tag', 'legend');
nSeries = numel(lines);
if nSeries <= 1
    legend(ax, 'off');
    return;
end
lgd = legend(ax, 'show');
if isempty(lgd) || ~ishghandle(lgd)
    return;
end
set(ax, 'Units', 'normalized', 'Position', [0.08 0.12 0.88 0.80]);
set(lgd, 'Interpreter', 'none', 'Box', 'on');
if nSeries <= 6
    set(lgd, 'Location', 'northeast', 'FontSize', 9);
else
    try
        set(lgd, 'NumColumns', 2);
    catch
    end
    set(lgd, 'Location', 'northeast', 'FontSize', 8);
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
bottom = 0.10;
top = 0.08;
hGap = 0.05;
vGap = 0.12;
cellW = (1 - left - right - (nCols - 1) * hGap) / nCols;
cellH = (1 - top - bottom - (nRows - 1) * vGap) / nRows;
for i = 1:nAxes
    row = ceil(i / nCols);
    col = mod(i - 1, nCols) + 1;
    x = left + (col - 1) * (cellW + hGap);
    y = 1 - top - row * cellH - (row - 1) * vGap;
    set(axesHandles(i), 'Position', [x y cellW cellH]);
end
end

function styleSubplotAxis(ax, idx, layout, xLabelText, yLabelText)
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
    ylabel(ax, yLabelText);
else
    ylabel(ax, '');
end
set(ax, 'FontSize', 9, 'TitleFontSizeMultiplier', 0.90);
end

function layoutAxesArea(parentObj)
kids = findall(parentObj, 'Type', 'axes');
if isempty(kids)
    return;
end
set(kids, 'Units', 'normalized');
if isscalar(kids)
    set(kids, 'Position', [0.08 0.12 0.88 0.80]);
end
end

function applyGenericXLimits(ax, xData)
if isempty(xData)
    set(ax, 'XLimMode', 'auto');
    return;
end
if isdatetime(xData)
    if numel(xData) == 1
        xlim(ax, [xData(1) - seconds(0.5), xData(1) + seconds(0.5)]);
    else
        xlim(ax, [xData(1), xData(end)]);
    end
else
    applyNumericXLimits(ax, double(xData(1)), double(xData(end)));
end
end

function applyNumericXLimits(ax, xMin, xMax)
if isfinite(xMin) && isfinite(xMax) && xMax > xMin
    xlim(ax, [xMin xMax]);
elseif isfinite(xMin) && isfinite(xMax)
    xlim(ax, [xMin - 0.5, xMax + 0.5]);
else
    set(ax, 'XLimMode', 'auto');
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

function rangeState = updateRangeState(rangeState, fileId, edtStart, edtEnd, nSamples)
if isempty(rangeState) || ~isstruct(rangeState)
    rangeState = struct('fileId', 0, 'startIdx', 1, 'endIdx', 1);
end
[startIdx, endIdx] = sanitizeRange(get(edtStart, 'String'), get(edtEnd, 'String'), nSamples);
rangeState.fileId = fileId;
rangeState.startIdx = startIdx;
rangeState.endIdx = endIdx;
set(edtStart, 'String', num2str(startIdx));
set(edtEnd, 'String', num2str(endIdx));
end

function rangeState = getRangeState(rangeState, fileId, nSamples)
if isempty(rangeState) || ~isstruct(rangeState) || rangeState.fileId ~= fileId
    rangeState = struct('fileId', fileId, 'startIdx', 1, 'endIdx', nSamples);
else
    [rangeState.startIdx, rangeState.endIdx] = sanitizeRange(rangeState.startIdx, rangeState.endIdx, nSamples);
end
end

function [startIdx, endIdx] = sanitizeRange(startRef, endRef, nSamples)
startIdx = parsePositiveInteger(startRef, 1);
endIdx = parsePositiveInteger(endRef, nSamples);
startIdx = max(1, min(nSamples, startIdx));
endIdx = max(1, min(nSamples, endIdx));
if endIdx < startIdx
    tmp = startIdx;
    startIdx = endIdx;
    endIdx = tmp;
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

function entries = buildFileListEntries(app)
entries = struct('type', {}, 'id', {}, 'label', {});
for i = 1:numel(app.fileOrder)
    item = app.fileOrder(i);
    if strcmp(item.type, 'ide_trace')
        idx = findFileIndexById(app.ideFiles, item.id);
        if idx < 1
            continue;
        end
        label = sprintf('[IDE] %s', app.ideFiles{idx}.displayName);
    else
        idx = findFileIndexById(app.hacFiles, item.id);
        if idx < 1
            continue;
        end
        label = sprintf('[HAC] %s', app.hacFiles{idx}.displayName);
    end
    entries(end + 1) = struct('type', item.type, 'id', item.id, 'label', label); %#ok<AGROW>
end
end

function value = mapPreferredEntries(entries, preferredEntries)
value = [];
if isempty(entries) || isempty(preferredEntries)
    return;
end
for i = 1:numel(preferredEntries)
    for j = 1:numel(entries)
        if strcmp(preferredEntries(i).type, entries(j).type) && preferredEntries(i).id == entries(j).id
            value(end + 1) = j; %#ok<AGROW>
            break;
        end
    end
end
value = unique(value, 'stable');
end

function idx = findFileIndexById(files, fileId)
idx = 0;
for i = 1:numel(files)
    if files{i}.id == fileId
        idx = i;
        return;
    end
end
end

function F = getCurrentIdeFile(app, entries)
F = [];
for i = 1:numel(entries)
    if strcmp(entries(i).type, 'ide_trace')
        idx = findFileIndexById(app.ideFiles, entries(i).id);
        if idx > 0
            F = app.ideFiles{idx};
            return;
        end
    end
end
if ~isempty(app.ideFiles)
    F = app.ideFiles{1};
end
end

function F = getCurrentHacFile(app, entries)
F = [];
for i = 1:numel(entries)
    if strcmp(entries(i).type, 'hac_trace')
        idx = findFileIndexById(app.hacFiles, entries(i).id);
        if idx > 0
            F = app.hacFiles{idx};
            return;
        end
    end
end
if ~isempty(app.hacFiles)
    F = app.hacFiles{1};
end
end

function [F, ok] = getIdeFileById(app, fileId)
ok = false;
F = [];
idx = findFileIndexById(app.ideFiles, fileId);
if idx > 0
    F = app.ideFiles{idx};
    ok = true;
end
end

function [F, ok] = getHacFileById(app, fileId)
ok = false;
F = [];
idx = findFileIndexById(app.hacFiles, fileId);
if idx > 0
    F = app.hacFiles{idx};
    ok = true;
end
end

function G = getSelectedHacGroup(F, hPopup)
G = [];
if isempty(F) || ~isfield(F, 'groups') || isempty(F.groups)
    return;
end
name = getPopupSelectedString(hPopup);
for i = 1:numel(F.groups)
    if strcmp(F.groups(i).name, name)
        G = F.groups(i);
        return;
    end
end
G = F.groups(1);
end

function txt = getHacXAxisSummary(F)
if ~isempty(F.timeData) && all(~isnat(F.timeData))
    txt = 'Datetime';
elseif ~isempty(F.elapsedSeconds) && all(isfinite(F.elapsedSeconds))
    txt = 'Elapsed Time (s)';
else
    txt = 'Sample Index';
end
end

function lines = readTextLinesCompat(filePath, maxLines, encodings)
if nargin < 2 || isempty(maxLines)
    maxLines = inf;
end
if nargin < 3 || isempty(encodings)
    encodings = {'UTF-8'};
end

lastErr = [];
for i = 1:numel(encodings)
    try
        lines = readTextLinesWithEncoding(filePath, maxLines, encodings{i});
        return;
    catch ME
        lastErr = ME;
    end
end
if isempty(lastErr)
    error('Cannot read file: %s', filePath);
end
rethrow(lastErr);
end

function lines = readTextLinesWithEncoding(filePath, maxLines, encoding)
if nargin < 2 || isempty(maxLines)
    maxLines = inf;
end
fid = fopen(filePath, 'r', 'n', encoding);
if fid < 0
    error('Cannot open file: %s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
lines = {};
count = 0;
while true
    if count >= maxLines
        break;
    end
    tline = fgetl(fid);
    if ~ischar(tline)
        break;
    end
    count = count + 1;
    lines{count, 1} = tline; %#ok<AGROW>
end
end

function headers = splitSemicolonLine(line)
parts = regexp(line, ';', 'split');
parts = cellfun(@strtrim, parts, 'UniformOutput', false);
headers = parts(~cellfun(@isempty, parts));
end

function toks = splitCsvLine(line)
toks = regexp(line, ',', 'split');
toks = cellfun(@strtrim, toks, 'UniformOutput', false);
end

function row = parseWhitespaceNumericRow(line)
row = [];
toks = regexp(strtrim(line), '\S+', 'match');
if isempty(toks)
    return;
end
nums = str2double(toks);
if all(isfinite(nums))
    row = nums(:).';
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
    rawHeaders = [rawHeaders(:).', createGenericHeaders(nExpected - numel(rawHeaders))];
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

function headers = createGenericHeaders(n)
headers = cell(1, n);
for i = 1:n
    headers{i} = sprintf('Col%02d', i);
end
end

function dt = parseHacDateTimes(timeText)
dt = NaT(numel(timeText), 1);
if isempty(timeText)
    return;
end
formats = {'yyyy-MM-dd HH:mm:ss.SSS', 'yyyy-MM-dd HH:mm:ss', 'yyyy/M/d HH:mm:ss.SSS', 'yyyy/M/d HH:mm:ss'};
for i = 1:numel(formats)
    try
        dt = datetime(timeText, 'InputFormat', formats{i});
        if all(~isnat(dt))
            return;
        end
    catch
    end
end
dt = NaT(numel(timeText), 1);
for i = 1:numel(timeText)
    try
        dt(i) = datetime(timeText{i});
    catch
        dt(i) = NaT;
    end
end
end

function elapsedSeconds = computeElapsedSeconds(timeData, periodMs, nRows)
if ~isempty(timeData) && all(~isnat(timeData))
    elapsedSeconds = seconds(timeData - timeData(1));
    return;
end
elapsedSeconds = ((0:(nRows - 1)).' * periodMs) / 1000;
end

function val = parseHeaderScalar(line, key)
val = NaN;
expr = ['^\s*', regexptranslate('escape', key), '\s*:\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)'];
tok = regexp(strtrim(line), expr, 'tokens', 'once');
if ~isempty(tok)
    val = str2double(tok{1});
end
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

function sel = getListSelectionIndices(h, nItems)
sel = get(h, 'Value');
if isempty(sel)
    sel = [];
    return;
end
sel = sel(:).';
sel = sel(sel >= 1 & sel <= nItems);
end

function selected = getPopupSelectedString(h)
items = getControlItemsCompat(h);
if isempty(items)
    selected = '';
    return;
end
value = get(h, 'Value');
value = max(1, min(numel(items), value));
selected = items{value};
end

function items = getControlItemsCompat(h)
raw = get(h, 'String');
if ischar(raw)
    items = {raw};
else
    items = raw(:).';
end
end

function setPopupItemsCompat(h, items, preferred)
if isempty(items)
    items = {'(none)'};
end
set(h, 'String', items);
value = 1;
if nargin >= 3 && ~isempty(preferred)
    idx = find(strcmp(items, preferred), 1, 'first');
    if ~isempty(idx)
        value = idx;
    end
end
set(h, 'Value', value);
end

function idx = popupValueFromItems(h, preferred)
items = getControlItemsCompat(h);
idx = 1;
hit = find(strcmp(items, preferred), 1, 'first');
if ~isempty(hit)
    idx = hit;
end
end

function idx = mapNamesToIndices(items, preferredNames)
idx = [];
if isempty(items) || isempty(preferredNames)
    return;
end
for i = 1:numel(preferredNames)
    hit = find(strcmp(items, preferredNames{i}), 1, 'first');
    if ~isempty(hit)
        idx(end + 1) = hit; %#ok<AGROW>
    end
end
idx = unique(idx, 'stable');
end

function layout = chooseTightGrid(nPlots)
if nPlots <= 1
    layout = [1 1];
elseif nPlots == 2
    layout = [2 1];
elseif nPlots <= 4
    layout = [2 2];
elseif nPlots <= 6
    layout = [3 2];
elseif nPlots <= 9
    layout = [3 3];
elseif nPlots <= 12
    layout = [4 3];
else
    nCols = ceil(sqrt(nPlots));
    nRows = ceil(nPlots / nCols);
    layout = [nRows nCols];
end
end

function tf = isCurrentTab(tabGroup, targetTab)
tf = false;
try
    tf = isequal(get(tabGroup, 'SelectedTab'), targetTab);
catch
end
end

function out = ternaryVisible(cond)
if cond
    out = 'on';
else
    out = 'off';
end
end

function showAlertCompat(figHandle, msg, ttl)
try
    uialert(figHandle, msg, ttl);
catch
    try
        warndlg(msg, ttl);
    catch
    end
end
end
