function view_modal_shape()
%VIEW_MODAL_SHAPE 提取模态振型并导出动画。
% 独立于现有振动 GUI，面向 .vna 模态测试数据。
% 主要功能：
% 1. 加载单个文件或整个文件夹内的 .vna 文件。
% 2. 用表格管理测点、三方向通道和空间坐标。
% 3. 自动推断测点骨架连线，并允许手工修正。
% 4. 基于复数 FRF 提取目标频率下的工程振型。
% 5. 预览骨架振型并导出 GIF 动画。
    app = struct();
    app.files = struct('name', {}, 'path', {}, 'freq', {}, 'xcmeas', {}, 'eu', {}, 'coh', {}, 'nResp', {});
    app.points = defaultPointRows();
    app.lines = defaultLineRows();
    app.lastDir = pwd;
    app.currentFrf = struct('freq', [], 'db', [], 'smoothDb', [], 'peaks', [], 'pickedFreq', NaN, 'displayFreqs', []);
    app.activeModeFreq = NaN;
    app.manualPeaks = [];
    app.lastMode = [];
    app.selectedPointRows = [];
    app.selectedLineRows = [];
    app.selectedFiles = [];
    app.previewTimer = [];
    app.previewPhaseIndex = 0;

    fig = figure( ...
        'Name', 'Modal Shape Viewer', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', [0.94 0.94 0.94], ...
        'Units', 'normalized', ...
        'Position', [0.05 0.05 0.90 0.86], ...
        'CloseRequestFcn', @onCloseFigure);

    pnlLeft = uipanel( ...
        'Parent', fig, ...
        'Title', 'Controls', ...
        'Units', 'normalized', ...
        'Position', [0.01 0.01 0.34 0.98]);

    pnlRight = uipanel( ...
        'Parent', fig, ...
        'Title', 'Preview', ...
        'Units', 'normalized', ...
        'Position', [0.36 0.01 0.63 0.98]);

    pnlMode = uipanel( ...
        'Parent', pnlRight, ...
        'Title', 'Mode', ...
        'Units', 'normalized', ...
        'Position', [0.67 0.56 0.29 0.38]);

    btnLoadFiles = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Load Files', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.95 0.22 0.04], ...
        'Callback', @onLoadFiles); %#ok<NASGU>

    btnLoadFolder = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Load Folder', ...
        'Units', 'normalized', ...
        'Position', [0.27 0.95 0.22 0.04], ...
        'Callback', @onLoadFolder); %#ok<NASGU>

    btnDeleteFiles = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Delete Files', ...
        'Units', 'normalized', ...
        'Position', [0.51 0.95 0.44 0.04], ...
        'Callback', @onDeleteFiles); %#ok<NASGU>

    lstFiles = uicontrol( ...
        'Parent', pnlLeft, ...
        'Style', 'listbox', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.82 0.92 0.11], ...
        'Min', 0, ...
        'Max', 20, ...
        'String', {'No file loaded'}, ...
        'Value', 1, ...
        'Callback', @onFileSelectionChanged);

    txtFileHint = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'text', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.805 0.92 0.018], ...
        'String', 'Point table binds each PointID directly to a loaded file name.'); %#ok<NASGU>

    txtPointTitle = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'text', ...
        'String', 'Point Table', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.775 0.40 0.022]); %#ok<NASGU>

    btnAddPoint = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Add Point', ...
        'Units', 'normalized', ...
        'Position', [0.62 0.784 0.15 0.028], ...
        'Callback', @onAddPointRow); %#ok<NASGU>

    btnDeletePoint = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Del Point', ...
        'Units', 'normalized', ...
        'Position', [0.79 0.784 0.16 0.028], ...
        'Callback', @onDeletePointRows); %#ok<NASGU>

    tblPoints = uitable( ...
        'Parent', pnlLeft, ...
        'Units', 'normalized', ...
        'Position', [0.03 0.44 0.92 0.34], ...
        'ColumnName', {'Use', 'PointID', 'FileName', 'XCh', 'YCh', 'ZCh', 'X', 'Y', 'Z'}, ...
        'ColumnWidth', {42, 64, 96, 46, 46, 46, 54, 54, 54}, ...
        'ColumnEditable', true(1, 9), ...
        'ColumnFormat', {'logical', 'char', 'char', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric', 'numeric'}, ...
        'CellEditCallback', @onPointTableEdited, ...
        'CellSelectionCallback', @onPointTableSelected);

    txtLineTitle = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'text', ...
        'String', 'Line Table', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.40 0.36 0.020]); %#ok<NASGU>

    btnAutoLines = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Auto Lines', ...
        'Units', 'normalized', ...
        'Position', [0.42 0.40 0.22 0.026], ...
        'Callback', @onAutoBuildLines); %#ok<NASGU>

    btnAddLine = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Add Line', ...
        'Units', 'normalized', ...
        'Position', [0.66 0.40 0.13 0.026], ...
        'Callback', @onAddLineRow); %#ok<NASGU>

    btnDeleteLine = uicontrol( ... %#ok<NASGU>
        'Parent', pnlLeft, ...
        'Style', 'pushbutton', ...
        'String', 'Del Line', ...
        'Units', 'normalized', ...
        'Position', [0.81 0.40 0.14 0.026], ...
        'Callback', @onDeleteLineRows); %#ok<NASGU>

    tblLines = uitable( ...
        'Parent', pnlLeft, ...
        'Units', 'normalized', ...
        'Position', [0.03 0.04 0.92 0.35], ...
        'ColumnName', {'Use', 'StartPointID', 'EndPointID', 'Source'}, ...
        'ColumnEditable', true(1, 4), ...
        'ColumnFormat', {'logical', 'char', 'char', 'char'}, ...
        'CellEditCallback', @onLineTableEdited, ...
        'CellSelectionCallback', @onLineTableSelected);

    txtModeTitle = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'text', ...
        'String', 'Mode Frequency', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.95 0.40 0.03]);

    edtModeFreq = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'edit', ...
        'String', '', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.875 0.36 0.05], ...
        'Callback', @onModeFreqEdited);

    btnApplyFreq = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Apply Freq', ...
        'Units', 'normalized', ...
        'Position', [0.45 0.875 0.28 0.05], ...
        'Callback', @onApplyFreq);

    btnFindPeaks = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Find Peaks', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.18 0.21 0.035], ...
        'Callback', @onFindPeaks);

    btnExtractMode = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Extract', ...
        'Units', 'normalized', ...
        'Position', [0.29 0.18 0.18 0.035], ...
        'Callback', @onExtractMode);

    btnPreview = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Preview', ...
        'Units', 'normalized', ...
        'Position', [0.50 0.18 0.18 0.035], ...
        'Callback', @onPreviewMode);

    btnExportGif = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Export GIF', ...
        'Units', 'normalized', ...
        'Position', [0.71 0.18 0.24 0.035], ...
        'Callback', @onExportGif);

    txtCandidateTitle = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'text', ...
        'String', 'Mode Candidates', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.80 0.45 0.025]);

    lstCandidates = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'listbox', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.34 0.90 0.44], ...
        'String', {'(none)'}, ...
        'Value', 1, ...
        'Callback', @onCandidateSelected);

    btnDeletePeak = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'pushbutton', ...
        'String', 'Del Peak', ...
        'Units', 'normalized', ...
        'Position', [0.71 0.135 0.24 0.03], ...
        'Callback', @onDeleteSelectedPeak);

    txtPeakHint = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'text', ...
        'HorizontalAlignment', 'left', ...
        'String', 'Click FRF to fill Mode Frequency, then press Apply.', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.095 0.62 0.025]);

    txtStatus = uicontrol( ...
        'Parent', pnlMode, ...
        'Style', 'text', ...
        'HorizontalAlignment', 'left', ...
        'String', 'Status: ready', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.035 0.90 0.02]);

    axFrf = axes( ...
        'Parent', pnlRight, ...
        'Units', 'normalized', ...
        'Position', [0.06 0.56 0.58 0.38], ...
        'ButtonDownFcn', @onFrfAxisClicked);
    title(axFrf, 'Modal FRF Candidate View');
    xlabel(axFrf, 'Frequency (Hz)');
    ylabel(axFrf, 'Magnitude (dB)');
    set(axFrf, 'XScale', 'log', 'Box', 'on');
    grid(axFrf, 'on');

    axLayout = axes( ...
        'Parent', pnlRight, ...
        'Units', 'normalized', ...
        'Position', [0.06 0.08 0.40 0.40]);
    title(axLayout, 'Point Layout');
    xlabel(axLayout, 'X');
    ylabel(axLayout, 'Y');
    zlabel(axLayout, 'Z');
    set(axLayout, 'Box', 'on');
    view(axLayout, 3);

    axMode = axes( ...
        'Parent', pnlRight, ...
        'Units', 'normalized', ...
        'Position', [0.54 0.08 0.40 0.40]);
    title(axMode, 'Mode Shape Preview');
    xlabel(axMode, 'X');
    ylabel(axMode, 'Y');
    zlabel(axMode, 'Z');
    set(axMode, 'Box', 'on');
    view(axMode, 3);

    applyCompactFonts();
    layoutModePanel();
    rotate3d(fig, 'on');
    set(fig, 'ResizeFcn', @onFigureResized);
    refreshAll();

    function refreshAll()
        layoutModePanel();
        refreshFileList();
        refreshPointTable();
        refreshLineTable();
        updateFreqSummary(NaN);
        refreshFrfAxis();
        refreshPointAxis();
        refreshModeAxis();
    end

    function applyCompactFonts()
        handles = findall(fig);
        for iHandle = 1:numel(handles)
            try
                if isprop(handles(iHandle), 'FontSize')
                    set(handles(iHandle), 'FontSize', 9);
                end
            catch
            end
        end
        try
            set(tblPoints, 'FontSize', 9);
        catch
        end
        try
            set(tblLines, 'FontSize', 9);
        catch
        end
        try
            set([txtModeTitle, edtModeFreq, btnApplyFreq, txtCandidateTitle, ...
                lstCandidates, btnFindPeaks, btnExtractMode, btnPreview, btnExportGif, ...
                btnDeletePeak, txtPeakHint, txtStatus], 'FontSize', 8);
        catch
        end
    end

    function onFigureResized(~, ~)
        layoutModePanel();
    end

    function layoutModePanel()
        if ~ishandle(pnlMode)
            return;
        end

        oldUnits = get(pnlMode, 'Units');
        set(pnlMode, 'Units', 'pixels');
        pnlPos = get(pnlMode, 'Position');
        set(pnlMode, 'Units', oldUnits);

        panelW = pnlPos(3);
        panelH = pnlPos(4);
        pad = 10;
        titleGap = 22;
        labelH = 18;
        fieldH = 26;
        btnH = 24;
        gap = 6;
        statusH = 16;

        contentW = max(120, panelW - 2 * pad);
        yTop = panelH - titleGap - pad;

        setPixelRect(txtModeTitle, [pad, yTop - labelH, contentW, labelH]);
        yTop = yTop - labelH - 4;

        editW = max(90, floor(contentW * 0.46));
        btnW = max(84, min(floor(contentW * 0.36), contentW - editW - gap));
        setPixelRect(edtModeFreq, [pad, yTop - fieldH, editW, fieldH]);
        setPixelRect(btnApplyFreq, [pad + editW + gap, yTop - fieldH, btnW, fieldH]);
        yTop = yTop - fieldH - 8;

        setPixelRect(txtCandidateTitle, [pad, yTop - labelH, contentW, labelH]);
        yTop = yTop - labelH - 4;

        statusY = 4;
        row2Y = statusY + statusH + 4;
        row1Y = row2Y + btnH + 4;
        listY = row1Y + btnH + 8;
        listH = max(70, yTop - listY);
        setPixelRect(lstCandidates, [pad, listY, contentW, listH]);

        colW = floor((contentW - 2 * gap) / 3);
        setPixelRect(btnFindPeaks, [pad, row1Y, colW, btnH]);
        setPixelRect(btnExtractMode, [pad + colW + gap, row1Y, colW, btnH]);
        setPixelRect(btnPreview, [pad + 2 * (colW + gap), row1Y, colW, btnH]);

        halfW = floor((contentW - gap) / 2);
        setPixelRect(btnExportGif, [pad, row2Y, halfW, btnH]);
        setPixelRect(btnDeletePeak, [pad + halfW + gap, row2Y, halfW, btnH]);

        set(txtPeakHint, 'Visible', 'off');
        setPixelRect(txtStatus, [pad, statusY, contentW, statusH]);
    end

    function setPixelRect(h, rect)
        if ~ishandle(h)
            return;
        end
        set(h, 'Units', 'pixels', 'Position', rect);
    end

    function onLoadFiles(~, ~)
        startDir = getValidStartDir();
        [files, folder] = uigetfile({'*.vna', 'VNA Files (*.vna)'}, 'Load VNA Files', startDir, 'MultiSelect', 'on');
        if isequal(files, 0)
            return;
        end
        app.lastDir = folder;
        if ischar(files)
            files = {files};
        end
        addFilesFromPaths(fullfileCell(folder, files));
    end

    function onLoadFolder(~, ~)
        startDir = getValidStartDir();
        folder = uigetdir(startDir, 'Load VNA Folder');
        if isequal(folder, 0)
            return;
        end
        app.lastDir = folder;
        dd = dir(fullfile(folder, '*.vna'));
        if isempty(dd)
            updateStatus('No .vna files found in selected folder.');
            return;
        end
        filePaths = cell(numel(dd), 1);
        for i = 1:numel(dd)
            filePaths{i} = fullfile(folder, dd(i).name);
        end
        addFilesFromPaths(filePaths);
    end

    function addFilesFromPaths(filePaths)
        added = 0;
        messages = {};
        for iFile = 1:numel(filePaths)
            filePath = filePaths{iFile};
            [~, baseName, ~] = fileparts(filePath);
            if hasLoadedFile(baseName)
                messages{end+1} = sprintf('Skip duplicate file: %s', baseName); %#ok<AGROW>
                continue;
            end
            try
                F = parseModalVnaFile(filePath);
                app.files(end+1) = F;
                added = added + 1;
            catch ME
                messages{end+1} = sprintf('Failed to load %s: %s', baseName, ME.message); %#ok<AGROW>
            end
        end
        if isempty(app.points)
            app.points = defaultPointRows();
        end
        if added > 0 && isempty(nonemptyPointBindings(app.points))
            app.points(1).fileName = app.files(1).name;
        end
        if activePointCount() >= 2 && isempty(app.lines)
            app.lines = mergeAutoLines(app.lines, inferAutoLines(app.points));
        elseif isempty(app.lines)
            app.lines = defaultLineRows();
        end
        invalidateFrfState();
        invalidateModeState();
        refreshAll();
        if isempty(messages)
            updateStatus(sprintf('Loaded %d file(s).', added));
        else
            updateStatus(strjoin(messages, ' | '));
        end
    end

    function tf = hasLoadedFile(baseName)
        tf = false;
        for i = 1:numel(app.files)
            if strcmpi(app.files(i).name, baseName)
                tf = true;
                return;
            end
        end
    end

    function onDeleteFiles(~, ~)
        if isempty(app.files)
            return;
        end
        idx = get(lstFiles, 'Value');
        if isempty(idx)
            return;
        end
        idx = unique(idx(:)');
        keep = true(1, numel(app.files));
        keep(idx) = false;
        removedNames = {app.files(idx).name};
        app.files = app.files(keep);
        app.points = removePointsBoundToFiles(app.points, removedNames);
        app.lines = removeInvalidLines(app.lines, app.points);
        if isempty(app.files)
            app.activeModeFreq = NaN;
            app.currentFrf = struct('freq', [], 'db', [], 'smoothDb', [], 'peaks', [], 'pickedFreq', NaN, 'displayFreqs', []);
        end
        invalidateFrfState();
        invalidateModeState();
        refreshAll();
        updateStatus(sprintf('Deleted %d file(s).', numel(idx)));
    end

    function onFileSelectionChanged(~, ~)
        app.selectedFiles = get(lstFiles, 'Value');
    end

    function onAddPointRow(~, ~)
        app.points = parsePointTableData(get(tblPoints, 'Data'));
        newRow = defaultPointRow();
        newRow.pointId = nextPointId(app.points);
        if ~isempty(app.files)
            fileIdx = getPreferredFileIndex();
            if fileIdx >= 1 && fileIdx <= numel(app.files)
                newRow.fileName = app.files(fileIdx).name;
            else
                newRow.fileName = app.files(1).name;
            end
        end
        app.points(end+1) = newRow;
        invalidateFrfState();
        refreshPointTable();
        refreshPointAxis();
        invalidateModeState();
        updateStatus('Added point row.');
    end

    function onDeletePointRows(~, ~)
        app.points = parsePointTableData(get(tblPoints, 'Data'));
        rows = unique(app.selectedPointRows);
        if isempty(rows)
            ud = get(tblPoints, 'UserData');
            if isnumeric(ud) && ~isempty(ud)
                rows = unique(ud(:).');
            end
        end
        if isempty(rows) && ~isempty(app.points)
            rows = 1;
        end
        if isempty(rows)
            updateStatus('Select one or more point rows to delete.');
            return;
        end
        rows = rows(rows >= 1 & rows <= numel(app.points));
        if isempty(rows)
            updateStatus('Selected point rows are invalid.');
            return;
        end
        keep = true(1, numel(app.points));
        keep(rows) = false;
        app.points = app.points(keep);
        app.lines = removeInvalidLines(app.lines, app.points);
        app.selectedPointRows = [];
        set(tblPoints, 'UserData', []);
        invalidateFrfState();
        invalidateModeState();
        refreshPointTable();
        refreshLineTable();
        refreshPointAxis();
        refreshModeAxis();
        updateStatus(sprintf('Deleted %d point row(s).', numel(rows)));
    end

    function onPointTableEdited(~, ~)
        app.points = parsePointTableData(get(tblPoints, 'Data'));
        app.lines = removeInvalidLines(app.lines, app.points);
        if isempty(app.lines) || ~hasManualLine(app.lines)
            app.lines = mergeAutoLines(app.lines, inferAutoLines(app.points));
        end
        invalidateFrfState();
        invalidateModeState();
        refreshLineTable();
        refreshFrfAxis();
        refreshPointAxis();
        refreshModeAxis();
        updateStatus('Point table updated.');
    end

    function onPointTableSelected(~, event)
        app.selectedPointRows = selectionRows(event);
        set(tblPoints, 'UserData', app.selectedPointRows);
    end

    function onAddLineRow(~, ~)
        app.lines = parseLineTableData(get(tblLines, 'Data'));
        newLine = defaultLineRow();
        pointIds = validPointIdList(app.points);
        if numel(pointIds) >= 2
            newLine.startPointId = pointIds{1};
            newLine.endPointId = pointIds{2};
        end
        app.lines(end+1) = newLine;
        refreshLineTable();
        refreshPointAxis();
        refreshModeAxis();
        updateStatus('Added line row.');
    end

    function onDeleteLineRows(~, ~)
        app.lines = parseLineTableData(get(tblLines, 'Data'));
        rows = unique(app.selectedLineRows);
        if isempty(rows)
            return;
        end
        keep = true(1, numel(app.lines));
        keep(rows) = false;
        app.lines = app.lines(keep);
        if isempty(app.lines)
            app.lines = defaultLineRows();
        end
        refreshLineTable();
        refreshPointAxis();
        refreshModeAxis();
        updateStatus(sprintf('Deleted %d line row(s).', numel(rows)));
    end

    function onLineTableEdited(~, ~)
        app.lines = parseLineTableData(get(tblLines, 'Data'));
        refreshPointAxis();
        refreshModeAxis();
        updateStatus('Line table updated.');
    end

    function onLineTableSelected(~, event)
        app.selectedLineRows = selectionRows(event);
    end

    function onAutoBuildLines(~, ~)
        app.points = parsePointTableData(get(tblPoints, 'Data'));
        autoLines = inferAutoLines(app.points);
        app.lines = mergeAutoLines(app.lines, autoLines);
        refreshLineTable();
        refreshPointAxis();
        refreshModeAxis();
        updateStatus(sprintf('Auto-built %d line(s).', numel(autoLines)));
    end

    function onApplyFreq(~, ~)
        ok = syncActiveFreqFromEdit(true, false);
        if ok
            return;
        end
    end

    function ok = syncActiveFreqFromEdit(showStatus, snapToCurve)
        if nargin < 1
            showStatus = false;
        end
        if nargin < 2
            snapToCurve = false;
        end
        ok = false;
        freqText = strtrim(get(edtModeFreq, 'String'));
        if isempty(freqText)
            if showStatus
                updateStatus('Mode Freq is empty.');
            end
            return;
        end
        freqVal = str2double(freqText);
        if ~isfinite(freqVal) || freqVal <= 0
            if showStatus
                updateStatus('Mode Freq must be a positive number.');
            end
            return;
        end
        if isempty(app.currentFrf.freq)
            [freq, dbCurve] = buildAggregateFrfCurve();
            app.currentFrf.freq = freq;
            app.currentFrf.db = dbCurve;
        end
        if snapToCurve && ~isempty(app.currentFrf.freq)
            freqVal = snapFrequencyToCurve(freqVal, app.currentFrf.freq);
        end
        addManualPeak(freqVal);
        refreshCandidateList(app.currentFrf.peaks);
        selectCandidateByFrequency(freqVal, 'manual/apply', showStatus);
        ok = true;
    end

    function onModeFreqEdited(src, ~)
        freqVal = str2double(get(src, 'String'));
        if ~isfinite(freqVal) || freqVal <= 0
            updateStatus('Mode Freq must be a positive number.');
            return;
        end
        updateStatus(sprintf('Mode Freq edited to %.8g Hz. Press Apply Freq to add/select it.', freqVal));
    end

    function onFindPeaks(~, ~)
        stopPreviewAnimation(true, true);
        [freq, dbCurve] = buildAggregateFrfCurve();
        if numel(freq) < 3
            updateStatus('Not enough valid FRF data to find peaks.');
            app.currentFrf = struct('freq', [], 'db', [], 'smoothDb', [], 'peaks', [], 'pickedFreq', app.activeModeFreq, 'displayFreqs', []);
            app.manualPeaks = [];
            refreshFrfAxis();
            refreshCandidateList([]);
            return;
        end
        [peakFreqsMain, smoothDb] = findProminentPeaks(freq, dbCurve, 12);
        peakFreqsLocal = collectIndividualFrfPeakFreqs(4);
        peakFreqs = mergePeakFrequencyLists(peakFreqsMain, peakFreqsLocal, 24);
        app.currentFrf.freq = freq;
        app.currentFrf.db = dbCurve;
        app.currentFrf.smoothDb = smoothDb;
        app.currentFrf.peaks = peakFreqs;
        app.currentFrf.pickedFreq = app.activeModeFreq;
        refreshCandidateList(peakFreqs);
        refreshFrfAxis();
        if ~isempty(peakFreqs)
            updateStatus(sprintf('Found %d peak candidate(s) from aggregate + local FRFs. Click a candidate in the list to update the mode frequency.', numel(peakFreqs)));
        else
            updateStatus('No clear peak candidates found.');
        end
    end

    function onCandidateSelected(src, ~)
        freqs = app.currentFrf.displayFreqs;
        if isempty(freqs)
            return;
        end
        idx = get(src, 'Value');
        if idx < 1 || idx > numel(freqs)
            return;
        end
        selectCandidateByFrequency(freqs(idx), 'candidate list', true);
    end

    function onDeleteSelectedPeak(~, ~)
        labels = get(lstCandidates, 'String');
        if isempty(labels)
            updateStatus('No candidate selected.');
            return;
        end
        idx = get(lstCandidates, 'Value');
        if iscell(labels)
            if idx < 1 || idx > numel(labels)
                updateStatus('No candidate selected.');
                return;
            end
            label = labels{idx};
        else
            label = labels;
        end
        if strcmp(label, '(none)')
            updateStatus('No candidate available to delete.');
            return;
        end
        freqs = app.currentFrf.displayFreqs;
        if idx < 1 || idx > numel(freqs)
            updateStatus('Selected candidate is invalid.');
            return;
        end
        freqToDelete = freqs(idx);
        tol = max(1e-9, 1e-6 * max(1, abs(freqToDelete)));
        deletingCurrent = isfinite(app.activeModeFreq) && abs(app.activeModeFreq - freqToDelete) <= tol;
        deleted = false;
        if ~isempty(strfind(label, '[Manual]')) %#ok<STREMP>
            if ~isempty(app.manualPeaks)
                keepManual = abs(app.manualPeaks(:) - freqToDelete) > tol;
                deleted = any(~keepManual);
                app.manualPeaks = app.manualPeaks(keepManual).';
            end
        else
            peaks = app.currentFrf.peaks(:);
            if isempty(peaks)
                updateStatus('No stored peak candidates to delete.');
                return;
            end
            keep = abs(peaks - freqToDelete) > tol;
            deleted = any(~keep);
            app.currentFrf.peaks = peaks(keep).';
        end
        if ~deleted
            updateStatus('Selected item is not a deletable candidate.');
            return;
        end
        refreshCandidateList(app.currentFrf.peaks);
        remainingFreqs = app.currentFrf.displayFreqs;
        if deletingCurrent
            if isempty(remainingFreqs)
                app.activeModeFreq = NaN;
                app.lastMode = [];
                updateFreqSummary(NaN);
                refreshFrfAxis();
                refreshModeAxis();
                updateStatus(sprintf('Deleted candidate %.8g Hz. No candidate remains.', freqToDelete));
                return;
            end
            fallbackIdx = min(max(idx, 1), numel(remainingFreqs));
            selectCandidateByFrequency(remainingFreqs(fallbackIdx), 'candidate fallback', true);
            return;
        end
        refreshFrfAxis();
        updateStatus(sprintf('Deleted peak candidate %.8g Hz.', freqToDelete));
    end

    function onFrfAxisClicked(~, ~)
        stopPreviewAnimation(true, true);
        freqVal = getClickedFrequency();
        if ~isfinite(freqVal) || freqVal <= 0
            return;
        end
        if isempty(app.currentFrf.freq)
            [freq, dbCurve] = buildAggregateFrfCurve();
            app.currentFrf.freq = freq;
            app.currentFrf.db = dbCurve;
        end
        freqVal = snapFrequencyToCurve(freqVal, app.currentFrf.freq);
        set(edtModeFreq, 'String', sprintf('%.8g', freqVal));
        app.currentFrf.pickedFreq = freqVal;
        refreshFrfAxis();
        updateStatus(sprintf('Picked %.8g Hz from FRF. Press Apply Freq to add it.', freqVal));
    end

    function freqVal = getClickedFrequency()
        cp = get(axFrf, 'CurrentPoint');
        freqVal = cp(1, 1);
    end

    function freqSnap = snapFrequencyToCurve(freqVal, freqAxis)
        freqSnap = freqVal;
        if isempty(freqAxis)
            return;
        end
        freqAxis = freqAxis(:);
        valid = isfinite(freqAxis) & freqAxis > 0;
        freqAxis = freqAxis(valid);
        if isempty(freqAxis)
            return;
        end
        [~, idxMin] = min(abs(freqAxis - freqVal));
        freqSnap = freqAxis(idxMin);
    end

    function onExtractMode(~, ~)
        mode = ensureModeExtracted();
        if isempty(mode)
            return;
        end
        updateFreqSummary(mode.actualFreq);
        refreshModeAxis();
        updateStatus(sprintf('Extracted mode near %.8g Hz (actual %.8g Hz).', mode.requestedFreq, mode.actualFreq));
    end

    function onPreviewMode(~, ~)
        mode = ensureModeExtracted();
        if isempty(mode)
            return;
        end
        updateFreqSummary(mode.actualFreq);
        startPreviewAnimation(mode);
        updateStatus(sprintf('Previewing mode at %.8g Hz.', mode.actualFreq));
    end

    function onExportGif(~, ~)
        mode = ensureModeExtracted();
        if isempty(mode)
            return;
        end
        updateFreqSummary(mode.actualFreq);
        [fileName, folder] = uiputfile({'*.gif', 'GIF Files (*.gif)'}, 'Export Mode Shape GIF', fullfile(getValidStartDir(), 'mode_shape.gif'));
        if isequal(fileName, 0)
            return;
        end
        gifPath = fullfile(folder, fileName);
        try
            exportModeGif(gifPath, mode);
            updateStatus(sprintf('Exported GIF: %s', gifPath));
        catch ME
            updateStatus(sprintf('GIF export failed: %s', ME.message));
        end
    end

    function mode = ensureModeExtracted()
        mode = [];
        if ~isfinite(app.activeModeFreq) || app.activeModeFreq <= 0
            updateStatus('Select a candidate frequency first.');
            return;
        end
        if ~isempty(app.lastMode) && abs(app.lastMode.requestedFreq - app.activeModeFreq) <= max(1e-9, 1e-6 * app.activeModeFreq)
            mode = app.lastMode;
            return;
        end
        try
            mode = extractCurrentMode(app.activeModeFreq);
            app.lastMode = mode;
        catch ME
            updateStatus(sprintf('Mode extraction failed: %s', ME.message));
        end
    end

    function mode = extractCurrentMode(targetFreq)
        app.points = parsePointTableData(get(tblPoints, 'Data'));
        app.lines = parseLineTableData(get(tblLines, 'Data'));
        validRows = getUsablePointRows(app.points, app.files);
        pointGroups = aggregatePointRowsById(validRows);
        if isempty(pointGroups)
            error('No valid point rows with bound files and coordinates.');
        end

        pointIds = cell(numel(pointGroups), 1);
        coords = zeros(numel(pointGroups), 3);
        dispComplex = nan(numel(pointGroups), 3);
        cohVals = nan(numel(pointGroups), 3);
        actualFreqs = nan(numel(pointGroups), 1);
        fileNames = cell(numel(pointGroups), 1);

        for iGroup = 1:numel(pointGroups)
            group = pointGroups(iGroup);
            pointIds{iGroup} = group.pointId;
            coords(iGroup, :) = group.coords;
            [vec, cohVec, actualFreq, fileNameLabel] = extractGroupedPointModeVector(group.rows, targetFreq);
            dispComplex(iGroup, :) = vec;
            cohVals(iGroup, :) = cohVec;
            actualFreqs(iGroup) = actualFreq;
            fileNames{iGroup} = fileNameLabel;
        end

        refVal = firstReferenceValue(dispComplex);
        if ~isfinite(refVal) || abs(refVal) == 0
            error('No valid complex FRF value found at the requested frequency.');
        end

        dispComplex = dispComplex ./ refVal;
        invalidMask = ~isfinite(real(dispComplex)) | ~isfinite(imag(dispComplex));
        dispComplex(invalidMask) = 0;
        dispReal = real(dispComplex);
        scale = computeDisplayScale(coords, dispReal);

        mode = struct();
        mode.requestedFreq = targetFreq;
        mode.actualFreq = median(actualFreqs(isfinite(actualFreqs)));
        if ~isfinite(mode.actualFreq)
            mode.actualFreq = targetFreq;
        end
        mode.pointIds = pointIds;
        mode.fileNames = fileNames;
        mode.coords = coords;
        mode.dispComplex = dispComplex;
        mode.dispReal = dispReal;
        mode.coh = cohVals;
        mode.scale = scale;
        mode.lines = activeLineRows(app.lines);
    end

    function [vec, cohVec, actualFreq, fileNameLabel] = extractGroupedPointModeVector(rows, targetFreq)
        vec = nan(1, 3);
        cohVec = nan(1, 3);
        actualLocal = nan(numel(rows), 1);
        nameList = cell(numel(rows), 1);
        for iRow = 1:numel(rows)
            row = rows(iRow);
            fileIdx = findFileIndexByName(app.files, row.fileName);
            if fileIdx == 0
                continue;
            end
            F = app.files(fileIdx);
            [vecLocal, cohLocal, actualOne] = extractPointModeVector(F, row, targetFreq);
            actualLocal(iRow) = actualOne;
            nameList{iRow} = row.fileName;
            for k = 1:3
                if ~isfinite(real(vecLocal(k))) || ~isfinite(imag(vecLocal(k))) || abs(vecLocal(k)) == 0
                    continue;
                end
                if ~isfinite(real(vec(k))) || ~isfinite(imag(vec(k))) || abs(vec(k)) == 0
                    vec(k) = vecLocal(k);
                    cohVec(k) = cohLocal(k);
                else
                    cohNew = cohLocal(k);
                    cohOld = cohVec(k);
                    if (~isfinite(cohOld) && isfinite(cohNew)) || (isfinite(cohNew) && cohNew > cohOld)
                        vec(k) = vecLocal(k);
                        cohVec(k) = cohNew;
                    end
                end
            end
        end
        actualFreq = median(actualLocal(isfinite(actualLocal)));
        if ~isfinite(actualFreq)
            actualFreq = targetFreq;
        end
        fileNameLabel = strjoin(unique(nameList(~cellfun('isempty', nameList))), ', ');
    end

    function [vec, cohVec, actualFreq] = extractPointModeVector(F, row, targetFreq)
        channels = [row.xCh, row.yCh, row.zCh];
        vec = nan(1, 3);
        cohVec = nan(1, 3);
        actualFreq = NaN;
        if isempty(F.freq)
            return;
        end
        freq = F.freq(:);
        validFreq = isfinite(freq) & freq > 0;
        if ~any(validFreq)
            return;
        end
        freqValid = freq(validFreq);
        [~, idxMin] = min(abs(freqValid - targetFreq));
        freqIdx = find(validFreq);
        idx = freqIdx(idxMin);
        actualFreq = freq(idx);
        for k = 1:3
            ch = channels(k);
            if ~isfinite(ch) || ch < 1 || ch > F.nResp
                continue;
            end
            [xfer, coh] = getCorrectedXfer(F, 1, ch);
            [freqAligned, xferAligned, cohAligned] = alignFreqAndSeries(F.freq, xfer, coh);
            if isempty(freqAligned) || isempty(xferAligned)
                continue;
            end
            [~, idxLocal] = min(abs(freqAligned - targetFreq));
            actualFreq = freqAligned(idxLocal);
            vec(k) = xferAligned(idxLocal);
            if ~isempty(cohAligned) && idxLocal <= numel(cohAligned)
                cohVec(k) = cohAligned(idxLocal);
            end
        end
    end

    function refreshFileList()
        if isempty(app.files)
            set(lstFiles, 'String', {'No file loaded'}, 'Value', 1);
            return;
        end
        names = cell(numel(app.files), 1);
        for i = 1:numel(app.files)
            names{i} = app.files(i).name;
        end
        keepSelection = getSafeSelection(get(lstFiles, 'Value'), numel(names));
        if isempty(keepSelection)
            keepSelection = 1;
        end
        set(lstFiles, 'String', names, 'Value', keepSelection);
    end

    function refreshPointTable()
        set(tblPoints, 'Data', buildPointTableData(app.points));
    end

    function refreshLineTable()
        set(tblLines, 'Data', buildLineTableData(app.lines));
    end

    function refreshCandidateList(peakFreqs)
        if nargin < 1
            peakFreqs = app.currentFrf.peaks;
        end
        prevFreqs = app.currentFrf.displayFreqs;
        prevValue = get(lstCandidates, 'Value');
        selectedFreq = NaN;
        if ~isempty(prevFreqs) && prevValue >= 1 && prevValue <= numel(prevFreqs)
            selectedFreq = prevFreqs(prevValue);
        end
        if isfinite(app.activeModeFreq) && app.activeModeFreq > 0
            selectedFreq = app.activeModeFreq;
        end
        displayFreqs = [];
        items = {};
        for i = 1:numel(app.manualPeaks)
            f = app.manualPeaks(i);
            if ~isempty(displayFreqs) && any(abs(displayFreqs - f) <= max(1e-9, 1e-6 * max(max(abs(displayFreqs)), abs(f))))
                continue;
            end
            displayFreqs(end + 1, 1) = f; %#ok<AGROW>
            items{end + 1, 1} = sprintf('[Manual] %.8g Hz', f); %#ok<AGROW>
        end
        for i = 1:numel(peakFreqs)
            f = peakFreqs(i);
            if ~isempty(displayFreqs) && any(abs(displayFreqs - f) <= max(1e-9, 1e-6 * max(max(abs(displayFreqs)), abs(f))))
                continue;
            end
            displayFreqs(end + 1, 1) = f; %#ok<AGROW>
            items{end + 1, 1} = sprintf('Peak %02d: %.8g Hz', i, f); %#ok<AGROW>
        end
        app.currentFrf.displayFreqs = displayFreqs;
        if isempty(displayFreqs)
            set(lstCandidates, 'String', {'(none)'}, 'Value', 1);
            return;
        end
        selIdx = 1;
        if isfinite(selectedFreq)
            [foundIdx, found] = findMatchingFrequencyIndex(displayFreqs, selectedFreq);
            if found
                selIdx = foundIdx;
            end
        end
        set(lstCandidates, 'String', items, 'Value', selIdx);
    end

    function refreshFrfAxis()
        cla(axFrf);
        if isempty(app.currentFrf.freq) || isempty(app.currentFrf.db)
            [freq, dbCurve] = buildAggregateFrfCurve();
            app.currentFrf.freq = freq;
            app.currentFrf.db = dbCurve;
            app.currentFrf.smoothDb = [];
            app.currentFrf.peaks = [];
            app.currentFrf.pickedFreq = app.activeModeFreq;
        end
        freq = app.currentFrf.freq;
        dbCurve = app.currentFrf.db;
        if isempty(freq) || isempty(dbCurve)
            title(axFrf, 'Modal FRF Candidate View');
            xlabel(axFrf, 'Frequency (Hz)');
            ylabel(axFrf, 'Magnitude (dB)');
            set(axFrf, 'XScale', 'log', 'YGrid', 'on', 'XGrid', 'on');
            return;
        end
        validX = freq(isfinite(freq) & freq > 0);
        if isempty(validX)
            validX = [0.1; 1];
        end
        xRange = [min(validX(:)), max(validX(:))];
        if xRange(2) <= xRange(1)
            xRange = xRange .* [0.9, 1.1];
            if xRange(1) <= 0
                xRange(1) = max(xRange(2) / 10, eps);
            end
        end

        hMain = semilogx(axFrf, freq, dbCurve, 'Color', [0 0.447 0.741], 'LineWidth', 1.2);
        set(hMain, 'ButtonDownFcn', @onFrfAxisClicked);
        hold(axFrf, 'on');
        if ~isempty(app.currentFrf.smoothDb)
            hSmooth = semilogx(axFrf, freq, app.currentFrf.smoothDb, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
            set(hSmooth, 'ButtonDownFcn', @onFrfAxisClicked);
        end
        if ~isempty(app.currentFrf.peaks)
            peakFreqs = app.currentFrf.peaks;
            peakDb = interp1(freq, dbCurve, peakFreqs, 'linear', 'extrap');
            hPeak = semilogx(axFrf, peakFreqs, peakDb, 'ro', 'MarkerFaceColor', 'w', 'LineStyle', 'none', 'MarkerSize', 6, 'LineWidth', 1.0);
            set(hPeak, 'ButtonDownFcn', @onFrfAxisClicked);
        end
        if ~isempty(app.manualPeaks)
            manualFreqs = app.manualPeaks(:);
            manualFreqs = manualFreqs(isfinite(manualFreqs) & manualFreqs > 0);
            if ~isempty(manualFreqs)
                if isfinite(app.activeModeFreq) && app.activeModeFreq > 0
                    tolActive = max(1e-9, 1e-6 * max(1, abs(app.activeModeFreq)));
                    manualFreqs = manualFreqs(abs(manualFreqs - app.activeModeFreq) > tolActive);
                end
                if isfinite(app.currentFrf.pickedFreq) && app.currentFrf.pickedFreq > 0
                    tolPicked = max(1e-9, 1e-6 * max(1, abs(app.currentFrf.pickedFreq)));
                    manualFreqs = manualFreqs(abs(manualFreqs - app.currentFrf.pickedFreq) > tolPicked);
                end
                if ~isempty(manualFreqs)
                    manualDb = interp1(freq, dbCurve, manualFreqs, 'linear', 'extrap');
                    hManual = semilogx(axFrf, manualFreqs, manualDb, 'd', ...
                        'Color', [0 0.6 0], ...
                        'MarkerFaceColor', [0.85 1.0 0.85], ...
                        'MarkerSize', 7, ...
                        'LineWidth', 1.0, ...
                        'LineStyle', 'none');
                    set(hManual, 'ButtonDownFcn', @onFrfAxisClicked);
                end
            end
        end
        if isfinite(app.currentFrf.pickedFreq) && app.currentFrf.pickedFreq > 0 && ...
                (~isfinite(app.activeModeFreq) || abs(app.currentFrf.pickedFreq - app.activeModeFreq) > max(1e-9, 1e-6 * max(1, abs(app.currentFrf.pickedFreq))))
            ylPick = [min(dbCurve(:)), max(dbCurve(:))];
            if diff(ylPick) < 1e-6
                ylPick = ylPick + [-1, 1];
            else
                padPick = 0.08 * diff(ylPick);
                ylPick = ylPick + [-padPick, padPick];
            end
            pickedFreqPlot = snapFrequencyToCurve(app.currentFrf.pickedFreq, freq);
            pickedDb = interp1(freq, dbCurve, pickedFreqPlot, 'linear', 'extrap');
            hPendingLine = semilogx(axFrf, [pickedFreqPlot pickedFreqPlot], ylPick, '--', 'Color', [0 0.6 0], 'LineWidth', 1.2);
            set(hPendingLine, 'ButtonDownFcn', @onFrfAxisClicked);
            hPending = semilogx(axFrf, pickedFreqPlot, pickedDb, 's', ...
                'Color', [0 0.6 0], ...
                'MarkerFaceColor', [0.65 0.95 0.65], ...
                'MarkerSize', 7, ...
                'LineWidth', 1.2, ...
                'LineStyle', 'none');
            set(hPending, 'ButtonDownFcn', @onFrfAxisClicked);
        end
        if isfinite(app.activeModeFreq) && app.activeModeFreq > 0
            yl = [min(dbCurve(:)), max(dbCurve(:))];
            if diff(yl) < 1e-6
                yl = yl + [-1, 1];
            else
                pad = 0.08 * diff(yl);
                yl = yl + [-pad, pad];
            end
            hPick = semilogx(axFrf, [app.activeModeFreq app.activeModeFreq], yl, '-', 'Color', [0.85 0.1 0.1], 'LineWidth', 1.5);
            set(hPick, 'ButtonDownFcn', @onFrfAxisClicked);
            activeFreqPlot = app.activeModeFreq;
            if ~isempty(freq)
                activeFreqPlot = snapFrequencyToCurve(app.activeModeFreq, freq);
            end
            activeDb = interp1(freq, dbCurve, activeFreqPlot, 'linear', 'extrap');
            hActive = semilogx(axFrf, activeFreqPlot, activeDb, 'o', ...
                'Color', [0.85 0.1 0.1], ...
                'MarkerFaceColor', [0.85 0.1 0.1], ...
                'MarkerSize', 8, ...
                'LineWidth', 1.5, ...
                'LineStyle', 'none');
            set(hActive, 'ButtonDownFcn', @onFrfAxisClicked);
            ylim(axFrf, yl);
        end
        hold(axFrf, 'off');
        set(axFrf, 'ButtonDownFcn', @onFrfAxisClicked, 'XScale', 'log', 'Box', 'on');
        xlim(axFrf, xRange);
        grid(axFrf, 'on');
        xlabel(axFrf, 'Frequency (Hz)');
        ylabel(axFrf, 'Magnitude (dB)');
        if isfinite(app.activeModeFreq) && app.activeModeFreq > 0
            title(axFrf, sprintf('Modal FRF Candidate View - Selected %.8g Hz', app.activeModeFreq));
        else
            title(axFrf, 'Modal FRF Candidate View');
        end
    end

    function refreshPointAxis()
        cla(axLayout);
        rows = getUsablePointRows(app.points, app.files, false);
        pointGroups = aggregatePointRowsById(rows);
        if isempty(pointGroups)
            title(axLayout, 'Point Layout');
            view(axLayout, 3);
            axis(axLayout, 'equal');
            return;
        end
        coords = zeros(numel(pointGroups), 3);
        pointIds = cell(numel(pointGroups), 1);
        bound = false(numel(pointGroups), 1);
        for i = 1:numel(pointGroups)
            pointIds{i} = pointGroups(i).pointId;
            coords(i, :) = pointGroups(i).coords;
            bound(i) = any(pointGroups(i).boundMask);
        end

        lineInfo = buildRenderableLines(app.lines, pointIds, coords);
        hold(axLayout, 'on');
        plotSkeleton(axLayout, lineInfo.validEdges, coords, [0.35 0.35 0.35], 1.6);
        plot3(axLayout, coords(bound, 1), coords(bound, 2), coords(bound, 3), 'bo', 'MarkerFaceColor', [0 0.447 0.741], 'MarkerSize', 7);
        plot3(axLayout, coords(~bound, 1), coords(~bound, 2), coords(~bound, 3), 'ro', 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 7);
        for i = 1:size(coords, 1)
            text(coords(i, 1), coords(i, 2), coords(i, 3), ['  ' pointIds{i}], 'Parent', axLayout, 'FontSize', 9, 'Color', [0.1 0.1 0.1]);
        end
        hold(axLayout, 'off');
        styleStructureAxis(axLayout, coords);
        title(axLayout, sprintf('Point Layout (%d lines)', size(lineInfo.validEdges, 1)));
        if lineInfo.invalidCount > 0
            updateStatus(sprintf('Ignored %d invalid line(s) during layout preview.', lineInfo.invalidCount));
        end
    end

    function refreshModeAxis()
        cla(axMode);
        if isempty(app.lastMode)
            title(axMode, 'Mode Shape Preview');
            axis(axMode, 'equal');
            view(axMode, 3);
            hidePreviewAxis(axMode);
            return;
        end
        renderModeSkeleton(axMode, app.lastMode, 1, true, false);
    end

    function renderModeSkeleton(ax, mode, phaseValue, showLabels, preserveView)
        if nargin < 4
            showLabels = false;
        end
        if nargin < 5
            preserveView = false;
        end
        if preserveView
            [az, el] = view(ax);
            viewState = [az el];
        else
            viewState = [];
        end
        coords = mode.coords;
        dispNow = mode.scale * real(mode.dispComplex * exp(1i * phaseValue));
        coordsDef = coords + dispNow;
        pointIds = mode.pointIds;
        lineInfo = buildRenderableLines(mode.lines, pointIds, coords);

        cla(ax);
        hold(ax, 'on');
        plotSkeleton(ax, lineInfo.validEdges, coords, [0.70 0.70 0.70], 1.2);
        plotSkeleton(ax, lineInfo.validEdges, coordsDef, [0 0.447 0.741], 2.0);
        plot3(ax, coords(:, 1), coords(:, 2), coords(:, 3), 'o', 'Color', [0.55 0.55 0.55], 'MarkerFaceColor', [0.85 0.85 0.85], 'MarkerSize', 6);
        plot3(ax, coordsDef(:, 1), coordsDef(:, 2), coordsDef(:, 3), 'o', 'Color', [0.1 0.1 0.1], 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 8);
        if showLabels
            for i = 1:size(coords, 1)
                text(coords(i, 1), coords(i, 2), coords(i, 3), ['  ' pointIds{i}], 'Parent', ax, 'FontSize', 8, 'Color', [0.15 0.15 0.15]);
            end
        end
        hold(ax, 'off');
        styleStructureAxis(ax, [coords; coordsDef], viewState);
        hidePreviewAxis(ax);
        title(ax, sprintf('Mode Shape Preview - Request %.4g Hz / Actual %.4g Hz', mode.requestedFreq, mode.actualFreq));
    end

    function animateMode(ax, mode, exportOnly, gifPath)
        if nargin < 3
            exportOnly = false;
        end
        nFrame = 24;
        delay = 0.08;
        if exportOnly
            figGif = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 680]);
            axGif = axes('Parent', figGif, 'Position', [0.08 0.08 0.86 0.86]);
        else
            axGif = ax;
            figGif = ancestor(ax, 'figure');
        end

        for k = 1:nFrame
            phaseValue = 2 * pi * (k - 1) / nFrame;
            renderModeSkeleton(axGif, mode, phaseValue, false, false);
            drawnow;
            if exportOnly
                frame = getframe(figGif);
                [img, map] = rgb2ind(frame2im(frame), 256);
                if k == 1
                    imwrite(img, map, gifPath, 'gif', 'LoopCount', inf, 'DelayTime', delay);
                else
                    imwrite(img, map, gifPath, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
                end
            end
        end

        if exportOnly && ishghandle(figGif)
            close(figGif);
        end
    end

    function startPreviewAnimation(mode)
        stopPreviewAnimation(false, false);
        app.previewPhaseIndex = 0;
        renderModeSkeleton(axMode, mode, 0, false, true);
        app.previewTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', 0.08, ...
            'BusyMode', 'drop', ...
            'TimerFcn', @onPreviewTimerTick, ...
            'ErrorFcn', @onPreviewTimerError);
        start(app.previewTimer);
    end

    function onPreviewTimerTick(~, ~)
        if ~ishandle(fig) || ~ishandle(axMode) || isempty(app.lastMode)
            stopPreviewAnimation(false, false);
            return;
        end
        app.previewPhaseIndex = app.previewPhaseIndex + 1;
        phaseValue = 2 * pi * mod(app.previewPhaseIndex, 24) / 24;
        renderModeSkeleton(axMode, app.lastMode, phaseValue, false, true);
        drawnow;
    end

    function onPreviewTimerError(~, ~)
        stopPreviewAnimation(false, false);
    end

    function stopPreviewAnimation(resetToStatic, resetView)
        if nargin < 1
            resetToStatic = true;
        end
        if nargin < 2
            resetView = false;
        end
        if ~isempty(app.previewTimer)
            try
                stop(app.previewTimer);
            catch
            end
            try
                delete(app.previewTimer);
            catch
            end
            app.previewTimer = [];
        end
        app.previewPhaseIndex = 0;
        if resetView && ishghandle(axMode)
            view(axMode, 3);
        end
        if resetToStatic && ishghandle(axMode)
            refreshModeAxis();
        end
    end

    function onCloseFigure(~, ~)
        stopPreviewAnimation(false, false);
        delete(fig);
    end

    function exportModeGif(gifPath, mode)
        animateMode([], mode, true, gifPath);
    end

    function [freq, dbCurve] = buildAggregateFrfCurve()
        freq = [];
        dbCurve = [];
        rows = getUsablePointRows(app.points, app.files);
        if isempty(rows)
            return;
        end

        magStack = [];
        refFreq = [];
        for iRow = 1:numel(rows)
            row = rows(iRow);
            fileIdx = findFileIndexByName(app.files, row.fileName);
            if fileIdx == 0
                continue;
            end
            F = app.files(fileIdx);
            channels = [row.xCh, row.yCh, row.zCh];
            for k = 1:numel(channels)
                ch = channels(k);
                if ~isfinite(ch) || ch < 1 || ch > F.nResp
                    continue;
                end
                [xfer, ~] = getCorrectedXfer(F, 1, ch);
                if isempty(xfer)
                    continue;
                end
                [f, xferAligned] = alignFreqAndSeries(F.freq, xfer, []);
                if isempty(f) || isempty(xferAligned)
                    continue;
                end
                valid = isfinite(f) & isfinite(xferAligned) & abs(xferAligned) > 0 & f > 0;
                if nnz(valid) < 8
                    continue;
                end
                f = f(valid);
                mag = abs(xferAligned(valid));
                if isempty(refFreq)
                    refFreq = f;
                    magStack = mag(:);
                else
                    magInterp = interp1(f, mag, refFreq, 'linear', NaN);
                    if ~isempty(magInterp)
                        magStack(:, end + 1) = magInterp(:); %#ok<AGROW>
                    end
                end
            end
        end
        if isempty(refFreq) || isempty(magStack)
            return;
        end
        magMean = nanmeanColumns(magStack);
        valid = isfinite(refFreq) & isfinite(magMean) & magMean > 0;
        freq = refFreq(valid);
        dbCurve = 20 * log10(magMean(valid));
    end

    function [peakFreqs, smoothDb] = findProminentPeaks(freq, dbCurve, maxCount)
        peakFreqs = [];
        smoothDb = [];
        valid = isfinite(freq) & isfinite(dbCurve) & freq > 0;
        freq = freq(valid);
        dbCurve = dbCurve(valid);
        if numel(freq) < 8
            return;
        end

        logFreq = log10(freq(:));
        logGrid = linspace(logFreq(1), logFreq(end), max(1200, numel(freq)));
        dbGrid = interp1(logFreq, dbCurve(:), logGrid, 'linear', 'extrap');

        smoothShort = smoothCurve(dbGrid, 9);
        smoothLong = smoothCurve(dbGrid, 71);
        prominence = smoothShort - smoothLong;
        smoothDb = interp1(logGrid, smoothShort, logFreq, 'linear', 'extrap');

        logRange = logGrid(end) - logGrid(1);
        minSpacing = max(0.018, 0.05 * logRange / max(1, maxCount));
        localWindow = max(9, round(numel(logGrid) / 80));
        if mod(localWindow, 2) == 0
            localWindow = localWindow + 1;
        end
        localHalf = floor(localWindow / 2);

        candidateIdx = [];
        candidateScore = [];
        globalProm = max(prominence) - min(prominence);
        if ~isfinite(globalProm) || globalProm <= 0
            globalProm = 1;
        end
        baseThreshold = max(1.5, 0.10 * globalProm);

        for i = 2:(numel(logGrid) - 1)
            if smoothShort(i) < smoothShort(i - 1) || smoothShort(i) < smoothShort(i + 1)
                continue;
            end
            left = max(1, i - localHalf);
            right = min(numel(logGrid), i + localHalf);
            localProm = prominence(i);
            localFloor = min(prominence(left:right));
            localPeak = max(prominence(left:right));
            localThreshold = max(baseThreshold, 0.35 * (localPeak - localFloor));
            if localProm < localThreshold
                continue;
            end
            candidateIdx(end + 1) = i; %#ok<AGROW>
            candidateScore(end + 1) = localProm; %#ok<AGROW>
        end

        if isempty(candidateIdx)
            return;
        end

        [~, order] = sort(candidateScore, 'descend');
        selectedIdx = [];
        for ii = 1:numel(order)
            idx = candidateIdx(order(ii));
            if isempty(selectedIdx) || all(abs(logGrid(idx) - logGrid(selectedIdx)) >= minSpacing)
                selectedIdx(end + 1) = idx; %#ok<AGROW>
            end
            if numel(selectedIdx) >= maxCount
                break;
            end
        end
        selectedIdx = sort(selectedIdx);
        peakFreqs = 10 .^ logGrid(selectedIdx);
        peakFreqs = refinePeakFreqsToRawMax(freq, dbCurve, peakFreqs);

        % Keep one low-frequency candidate when there is a clear low-band bump.
        lowBand = find(freq <= min(freq) * 8);
        if ~isempty(lowBand)
            [peakFreqs, ~] = ensureLowFrequencyPeak(peakFreqs, freq, smoothDb, lowBand);
        end
        peakFreqs = refinePeakFreqsToRawMax(freq, dbCurve, peakFreqs);
    end

    function peakFreqs = collectIndividualFrfPeakFreqs(maxPerCurve)
        peakFreqs = [];
        rows = getUsablePointRows(app.points, app.files);
        if isempty(rows)
            return;
        end
        for iRow = 1:numel(rows)
            row = rows(iRow);
            fileIdx = findFileIndexByName(app.files, row.fileName);
            if fileIdx == 0
                continue;
            end
            F = app.files(fileIdx);
            channels = [row.xCh, row.yCh, row.zCh];
            for k = 1:numel(channels)
                ch = channels(k);
                if ~isfinite(ch) || ch < 1 || ch > F.nResp
                    continue;
                end
                [xfer, ~] = getCorrectedXfer(F, 1, ch);
                if isempty(xfer)
                    continue;
                end
                [f, xferAligned] = alignFreqAndSeries(F.freq, xfer, []);
                if isempty(f) || isempty(xferAligned)
                    continue;
                end
                valid = isfinite(f) & isfinite(xferAligned) & abs(xferAligned) > 0 & f > 0;
                if nnz(valid) < 8
                    continue;
                end
                f = f(valid);
                dbLocal = 20 * log10(abs(xferAligned(valid)));
                localPeaks = findProminentPeaks(f, dbLocal, maxPerCurve);
                if ~isempty(localPeaks)
                    peakFreqs = [peakFreqs(:); localPeaks(:)]; %#ok<AGROW>
                end
            end
        end
        peakFreqs = peakFreqs(:);
    end

    function merged = mergePeakFrequencyLists(primaryFreqs, extraFreqs, maxCount)
        if nargin < 3 || ~isfinite(maxCount) || maxCount < 1
            maxCount = inf;
        end
        merged = [];
        primaryFreqs = primaryFreqs(:);
        extraFreqs = extraFreqs(:);
        for i = 1:numel(primaryFreqs)
            merged = appendUniqueFrequency(merged, primaryFreqs(i));
        end
        for i = 1:numel(extraFreqs)
            merged = appendUniqueFrequency(merged, extraFreqs(i));
        end
        if numel(merged) > maxCount
            merged = merged(1:maxCount);
        end
        merged = sort(merged(:));
    end

    function freqList = appendUniqueFrequency(freqList, freqVal)
        if ~isfinite(freqVal) || freqVal <= 0
            return;
        end
        if isempty(freqList)
            freqList = freqVal;
            return;
        end
        tolLog = 0.015;
        if all(abs(log10(freqList(:)) - log10(freqVal)) > tolLog)
            freqList(end + 1, 1) = freqVal; %#ok<AGROW>
        end
    end

    function [peakFreqs, inserted] = ensureLowFrequencyPeak(peakFreqs, freq, smoothDb, lowBand)
        inserted = false;
        if isempty(lowBand)
            return;
        end
        idxCandidates = lowBand(:);
        peakIdx = [];
        peakVal = -inf;
        for i = 2:(numel(idxCandidates) - 1)
            idx = idxCandidates(i);
            if smoothDb(idx) >= smoothDb(idx - 1) && smoothDb(idx) >= smoothDb(idx + 1)
                if smoothDb(idx) > peakVal
                    peakVal = smoothDb(idx);
                    peakIdx = idx;
                end
            end
        end
        if isempty(peakIdx)
            return;
        end
        lowFreq = freq(peakIdx);
        if isempty(peakFreqs)
            peakFreqs = lowFreq;
            inserted = true;
            return;
        end
        if all(abs(log10(peakFreqs(:)) - log10(lowFreq)) > 0.03)
            peakFreqs = sort([peakFreqs(:); lowFreq]);
            inserted = true;
        end
    end

    function peakFreqs = refinePeakFreqsToRawMax(freq, dbCurve, peakFreqs)
        if isempty(peakFreqs)
            return;
        end
        freq = freq(:);
        dbCurve = dbCurve(:);
        valid = isfinite(freq) & isfinite(dbCurve) & freq > 0;
        freq = freq(valid);
        dbCurve = dbCurve(valid);
        if numel(freq) < 3
            peakFreqs = sort(unique(peakFreqs(:))).';
            return;
        end

        logFreq = log10(freq);
        dLog = diff(logFreq);
        dLog = dLog(isfinite(dLog) & dLog > 0);
        if isempty(dLog)
            searchHalfWidth = 0.025;
        else
            searchHalfWidth = max(0.015, 6 * median(dLog));
        end

        refined = nan(numel(peakFreqs), 1);
        for iPeak = 1:numel(peakFreqs)
            f0 = peakFreqs(iPeak);
            if ~isfinite(f0) || f0 <= 0
                continue;
            end
            logF0 = log10(f0);
            inWin = abs(logFreq - logF0) <= searchHalfWidth;
            idxWin = find(inWin);
            if isempty(idxWin)
                [~, idxNearest] = min(abs(freq - f0));
                idxWin = max(1, idxNearest - 3):min(numel(freq), idxNearest + 3);
            end
            dbWin = dbCurve(idxWin);
            [~, idxLocal] = max(dbWin);
            idxBest = idxWin(idxLocal);

            left = idxBest;
            while left > idxWin(1) && dbCurve(left - 1) <= dbCurve(left)
                left = left - 1;
                if left <= 1
                    break;
                end
            end
            right = idxBest;
            while right < idxWin(end) && dbCurve(right + 1) <= dbCurve(right)
                right = right + 1;
                if right >= numel(freq)
                    break;
                end
            end
            [~, idxPeak] = max(dbCurve(left:right));
            refined(iPeak) = freq(left + idxPeak - 1);
        end

        refined = refined(isfinite(refined) & refined > 0);
        if isempty(refined)
            peakFreqs = [];
            return;
        end
        refined = sort(refined(:));
        keep = true(size(refined));
        for i = 2:numel(refined)
            tolLog = max(0.006, 2 * searchHalfWidth / 3);
            if abs(log10(refined(i)) - log10(refined(i - 1))) < tolLog
                if interp1(freq, dbCurve, refined(i), 'linear', -inf) <= interp1(freq, dbCurve, refined(i - 1), 'linear', -inf)
                    keep(i) = false;
                else
                    keep(i - 1) = false;
                end
            end
        end
        peakFreqs = refined(keep).';
    end

    function applyActiveModeFreq(freqVal, ~)
        if ~isfinite(freqVal) || freqVal <= 0
            return;
        end
        stopPreviewAnimation(true, true);
        app.activeModeFreq = freqVal;
        set(edtModeFreq, 'String', sprintf('%.8g', freqVal));
        updateFreqSummary(NaN);
        app.currentFrf.pickedFreq = freqVal;
        app.lastMode = [];
        refreshCandidateList(app.currentFrf.peaks);
        refreshFrfAxis();
    end

    function selectCandidateByFrequency(freqVal, ~, showStatus)
        if nargin < 3
            showStatus = true;
        end
        if ~isfinite(freqVal) || freqVal <= 0
            return;
        end
        applyActiveModeFreq(freqVal, []);
        mode = ensureModeExtracted();
        if isempty(mode)
            refreshModeAxis();
            if showStatus
                updateStatus(sprintf('Selected candidate %.8g Hz but mode extraction failed.', freqVal));
            end
            return;
        end
        updateFreqSummary(mode.actualFreq);
        refreshModeAxis();
        if showStatus
            updateStatus(sprintf('Loaded candidate %.8g Hz (actual %.8g Hz).', freqVal, mode.actualFreq));
        end
    end

    function updateFreqSummary(~)
    end

    function addManualPeak(freqVal)
        tol = max(1e-9, 1e-6 * max(1, abs(freqVal)));
        if isfinite(app.activeModeFreq) && abs(app.activeModeFreq - freqVal) <= tol
            return;
        end
        allFreqs = [app.manualPeaks(:); app.currentFrf.peaks(:)];
        if ~isempty(allFreqs) && any(abs(allFreqs - freqVal) <= tol)
            return;
        end
        app.manualPeaks(end + 1) = freqVal;
        app.manualPeaks = sort(app.manualPeaks);
    end

    function [idxOut, found] = findMatchingFrequencyIndex(freqList, freqVal)
        idxOut = 1;
        found = false;
        if isempty(freqList) || ~isfinite(freqVal)
            return;
        end
        tol = max(1e-9, 1e-6 * max([1; abs(freqList(:)); abs(freqVal)]));
        idx = find(abs(freqList(:) - freqVal) <= tol, 1, 'first');
        if isempty(idx)
            return;
        end
        idxOut = idx;
        found = true;
    end

    function invalidateModeState()
        stopPreviewAnimation(true, true);
        app.lastMode = [];
        if isfinite(app.activeModeFreq)
            app.currentFrf.pickedFreq = app.activeModeFreq;
        else
            app.currentFrf.pickedFreq = NaN;
        end
    end

    function invalidateFrfState()
        app.currentFrf.freq = [];
        app.currentFrf.db = [];
        app.currentFrf.smoothDb = [];
        app.currentFrf.peaks = [];
        app.currentFrf.pickedFreq = app.activeModeFreq;
        app.currentFrf.displayFreqs = [];
        app.manualPeaks = [];
    end

    function updateStatus(msg)
        set(txtStatus, 'String', ['Status: ' msg]);
        drawnow;
    end

    function idx = getPreferredFileIndex()
        idx = 1;
        fileSel = get(lstFiles, 'Value');
        if ~isempty(fileSel)
            idx = fileSel(1);
        end
    end

    function pathOut = getValidStartDir()
        pathOut = app.lastDir;
        if isempty(pathOut) || ~exist(pathOut, 'dir')
            pathOut = pwd;
        end
    end

    function styleStructureAxis(ax, coords, viewState)
        if nargin < 3
            viewState = [];
        end
        if isempty(coords)
            axis(ax, 'equal');
            if numel(viewState) ~= 2 || any(~isfinite(viewState))
                view(ax, 3);
            else
                view(ax, viewState(1), viewState(2));
            end
            grid(ax, 'off');
            return;
        end
        mins = min(coords, [], 1);
        maxs = max(coords, [], 1);
        span = max(maxs - mins);
        if ~isfinite(span) || span <= 0
            span = 1;
        end
        center = 0.5 * (mins + maxs);
        half = 0.60 * span;
        xlim(ax, center(1) + [-half half]);
        ylim(ax, center(2) + [-half half]);
        zlim(ax, center(3) + [-half half]);
        axis(ax, 'equal');
        if numel(viewState) ~= 2 || any(~isfinite(viewState))
            view(ax, 3);
        else
            view(ax, viewState(1), viewState(2));
        end
        grid(ax, 'off');
    end

    function hidePreviewAxis(ax)
        axis(ax, 'off');
        set(ax, ...
            'Visible', 'off', ...
            'Color', 'none', ...
            'XColor', 'none', ...
            'YColor', 'none', ...
            'ZColor', 'none', ...
            'XTick', [], ...
            'YTick', [], ...
            'ZTick', [], ...
            'Box', 'off');
        xlabel(ax, '');
        ylabel(ax, '');
        zlabel(ax, '');
    end

    function rows = getUsablePointRows(points, files, requireBound)
        if nargin < 3
            requireBound = true;
        end
        rows = struct('use', {}, 'pointId', {}, 'fileName', {}, 'xCh', {}, 'yCh', {}, 'zCh', {}, 'x', {}, 'y', {}, 'z', {});
        for i = 1:numel(points)
            row = points(i);
            if ~row.use
                continue;
            end
            if isempty(strtrim(row.pointId))
                continue;
            end
            if ~all(isfinite([row.x, row.y, row.z]))
                continue;
            end
            if requireBound && findFileIndexByName(files, row.fileName) == 0
                continue;
            end
            rows(end + 1) = row; %#ok<AGROW>
        end
    end

    function ids = validPointIdList(points)
        rows = getUsablePointRows(points, app.files, false);
        groups = aggregatePointRowsById(rows);
        ids = cell(numel(groups), 1);
        for i = 1:numel(groups)
            ids{i} = groups(i).pointId;
        end
    end

    function tf = hasManualLine(lines)
        tf = false;
        for i = 1:numel(lines)
            if strcmpi(strtrim(lines(i).source), 'manual')
                tf = true;
                return;
            end
        end
    end

    function linesOut = mergeAutoLines(existingLines, autoLines)
        existingLines = sanitizeLineRows(existingLines);
        autoLines = sanitizeLineRows(autoLines);
        manualLines = existingLines(~isAutoLineMask(existingLines));
        linesOut = [manualLines autoLines];
        linesOut = deduplicateLines(linesOut);
        if isempty(linesOut)
            linesOut = defaultLineRows();
        end
    end

    function mask = isAutoLineMask(lines)
        mask = false(1, numel(lines));
        for i = 1:numel(lines)
            mask(i) = strcmpi(strtrim(lines(i).source), 'auto');
        end
    end

    function linesOut = deduplicateLines(lines)
        linesOut = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        keys = {};
        for i = 1:numel(lines)
            row = lines(i);
            a = strtrim(row.startPointId);
            b = strtrim(row.endPointId);
            if isempty(a) || isempty(b) || strcmpi(a, b)
                continue;
            end
            pair = sort({a, b});
            key = [lower(pair{1}) '|' lower(pair{2})];
            if any(strcmp(keys, key))
                continue;
            end
            keys{end + 1} = key; %#ok<AGROW>
            linesOut(end + 1) = row; %#ok<AGROW>
        end
    end

    function linesOut = inferAutoLines(points)
        rows = getUsablePointRows(points, app.files, false);
        rows = aggregatePointRowsById(rows);
        linesOut = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        if numel(rows) < 2
            return;
        end

        pointIds = cell(numel(rows), 1);
        coords = zeros(numel(rows), 3);
        for i = 1:numel(rows)
            pointIds{i} = rows(i).pointId;
            coords(i, :) = rows(i).coords;
        end

        distMat = pairwiseDistances(coords);
        edges = minimumSpanningEdges(distMat);
        if isempty(edges)
            return;
        end

        nnDist = minPositiveRows(distMat);
        nnDist = nnDist(isfinite(nnDist));
        if isempty(nnDist)
            distLimit = inf;
        else
            distLimit = 1.8 * median(nnDist);
        end
        degree = zeros(numel(rows), 1);
        for i = 1:size(edges, 1)
            degree(edges(i, 1)) = degree(edges(i, 1)) + 1;
            degree(edges(i, 2)) = degree(edges(i, 2)) + 1;
        end

        candidate = [];
        for i = 1:numel(rows)
            [sortedDist, order] = sort(distMat(i, :), 'ascend');
            for j = 1:numel(order)
                other = order(j);
                if other == i || ~isfinite(sortedDist(j))
                    continue;
                end
                if sortedDist(j) > distLimit
                    break;
                end
                if degree(i) >= 2
                    break;
                end
                if degree(other) >= 3
                    continue;
                end
                pair = sort([i other]);
                if edgeExists(edges, pair) || edgeExists(candidate, pair)
                    continue;
                end
                candidate(end + 1, :) = pair; %#ok<AGROW>
                degree(i) = degree(i) + 1;
                degree(other) = degree(other) + 1;
                break;
            end
        end
        edges = [edges; candidate];
        edges = unique(edges, 'rows');

        for i = 1:size(edges, 1)
            row = defaultLineRow();
            row.startPointId = pointIds{edges(i, 1)};
            row.endPointId = pointIds{edges(i, 2)};
            row.source = 'auto';
            linesOut(end + 1) = row; %#ok<AGROW>
        end
    end

    function tf = edgeExists(edgeList, pair)
        tf = false;
        if isempty(edgeList)
            return;
        end
        for i = 1:size(edgeList, 1)
            if all(edgeList(i, :) == pair)
                tf = true;
                return;
            end
        end
    end

    function d = pairwiseDistances(coords)
        n = size(coords, 1);
        d = nan(n, n);
        for i = 1:n
            for j = i:n
                if i == j
                    d(i, j) = inf;
                else
                    val = norm(coords(i, :) - coords(j, :));
                    d(i, j) = val;
                    d(j, i) = val;
                end
            end
        end
    end

    function edges = minimumSpanningEdges(distMat)
        n = size(distMat, 1);
        edges = zeros(0, 2);
        if n < 2
            return;
        end
        used = false(n, 1);
        used(1) = true;
        while nnz(used) < n
            bestI = 0;
            bestJ = 0;
            bestD = inf;
            for i = find(used(:)).'
                for j = find(~used(:)).'
                    if distMat(i, j) < bestD
                        bestD = distMat(i, j);
                        bestI = i;
                        bestJ = j;
                    end
                end
            end
            if ~isfinite(bestD)
                break;
            end
            edges(end + 1, :) = sort([bestI bestJ]); %#ok<AGROW>
            used(bestJ) = true;
        end
    end

    function lineInfo = buildRenderableLines(lines, pointIds, coords)
        lines = activeLineRows(lines);
        validEdges = zeros(0, 2);
        invalidCount = 0;
        for i = 1:numel(lines)
            a = findPointIdIndex(pointIds, lines(i).startPointId);
            b = findPointIdIndex(pointIds, lines(i).endPointId);
            if a == 0 || b == 0 || a == b
                invalidCount = invalidCount + 1;
                continue;
            end
            validEdges(end + 1, :) = [a b]; %#ok<AGROW>
        end
        lineInfo = struct('validEdges', validEdges, 'invalidCount', invalidCount, 'coords', coords);
    end

    function plotSkeleton(ax, edges, coords, colorVal, lineWidth)
        if isempty(edges)
            return;
        end
        for i = 1:size(edges, 1)
            idx1 = edges(i, 1);
            idx2 = edges(i, 2);
            plot3(ax, ...
                coords([idx1 idx2], 1), ...
                coords([idx1 idx2], 2), ...
                coords([idx1 idx2], 3), ...
                '-', 'Color', colorVal, 'LineWidth', lineWidth, 'HitTest', 'off');
        end
    end

    function idx = findPointIdIndex(pointIds, pointId)
        idx = 0;
        key = strtrim(pointId);
        for i = 1:numel(pointIds)
            if strcmpi(strtrim(pointIds{i}), key)
                idx = i;
                return;
            end
        end
        for i = 1:numel(pointIds)
            if strcmpi(strtrim(pointIds{i}), strtrim(pointId))
                idx = i;
                return;
            end
        end
    end

    function linesOut = activeLineRows(lines)
        linesOut = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        for i = 1:numel(lines)
            if ~lines(i).use
                continue;
            end
            if isempty(strtrim(lines(i).startPointId)) || isempty(strtrim(lines(i).endPointId))
                continue;
            end
            linesOut(end + 1) = lines(i); %#ok<AGROW>
        end
    end

    function rowsOut = removePointsBoundToFiles(rowsIn, removedNames)
        rowsOut = struct('use', {}, 'pointId', {}, 'fileName', {}, 'xCh', {}, 'yCh', {}, 'zCh', {}, 'x', {}, 'y', {}, 'z', {});
        for i = 1:numel(rowsIn)
            if any(strcmpi(strtrim(rowsIn(i).fileName), removedNames))
                continue;
            end
            rowsOut(end + 1) = rowsIn(i); %#ok<AGROW>
        end
        if isempty(rowsOut)
            rowsOut = defaultPointRows();
        end
    end

    function linesOut = removeInvalidLines(linesIn, points)
        pointIds = validPointIdList(points);
        linesOut = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        for i = 1:numel(linesIn)
            row = linesIn(i);
            if isempty(strtrim(row.startPointId)) || isempty(strtrim(row.endPointId))
                continue;
            end
            if findPointIdIndex(pointIds, row.startPointId) == 0 || findPointIdIndex(pointIds, row.endPointId) == 0
                continue;
            end
            linesOut(end + 1) = row; %#ok<AGROW>
        end
        if isempty(linesOut)
            linesOut = defaultLineRows();
        end
    end

    function [xfer, coh] = getCorrectedXfer(F, exciteCh, respCh)
        xfer = [];
        coh = [];
        if exciteCh < 1 || respCh < 1 || exciteCh > size(F.xcmeas, 1) || respCh > size(F.xcmeas, 2)
            return;
        end
        cellVal = F.xcmeas(exciteCh, respCh);
        if ~isfield(cellVal, 'xfer')
            return;
        end
        xfer = cellVal.xfer(:);
        euExc = safeEuValue(F.eu, exciteCh);
        euResp = safeEuValue(F.eu, respCh);
        xfer = xfer .* (euResp / euExc);
        if isfield(cellVal, 'coh')
            coh = cellVal.coh(:);
        end
    end

    function groups = aggregatePointRowsById(rows)
        groups = struct('pointId', {}, 'coords', {}, 'rows', {}, 'boundMask', {});
        if isempty(rows)
            return;
        end
        keys = {};
        for i = 1:numel(rows)
            row = rows(i);
            key = upper(strtrim(row.pointId));
            if isempty(key)
                continue;
            end
            idx = find(strcmp(keys, key), 1, 'first');
            isBound = findFileIndexByName(app.files, row.fileName) > 0;
            if isempty(idx)
                idx = numel(keys) + 1;
                keys{idx} = key; %#ok<AGROW>
                groups(idx).pointId = row.pointId; %#ok<AGROW>
                groups(idx).coords = [row.x, row.y, row.z];
                groups(idx).rows = row;
                groups(idx).boundMask = isBound;
            else
                groups(idx).rows(end + 1) = row; %#ok<AGROW>
                groups(idx).boundMask(end + 1) = isBound; %#ok<AGROW>
            end
        end
    end

    function [freqAligned, seriesAligned, auxAligned] = alignFreqAndSeries(freqRaw, seriesRaw, auxRaw)
        freqAligned = [];
        seriesAligned = [];
        auxAligned = [];
        if isempty(freqRaw) || isempty(seriesRaw)
            return;
        end

        freqVec = freqRaw(:);
        seriesVec = seriesRaw(:);
        if isempty(freqVec) || isempty(seriesVec)
            return;
        end

        nSeries = numel(seriesVec);
        nFreq = numel(freqVec);
        if nFreq == nSeries
            freqUse = freqVec;
        elseif nFreq > nSeries
            freqUse = freqVec(1:nSeries);
        else
            seriesVec = seriesVec(1:nFreq);
            nSeries = nFreq;
            freqUse = freqVec;
        end

        if nargin >= 3 && ~isempty(auxRaw)
            auxVec = auxRaw(:);
            if numel(auxVec) >= nSeries
                auxAligned = auxVec(1:nSeries);
            else
                auxAligned = [];
            end
        end

        valid = isfinite(freqUse) & isfinite(seriesVec) & freqUse > 0;
        freqAligned = freqUse(valid);
        seriesAligned = seriesVec(valid);
        if ~isempty(auxAligned)
            auxAligned = auxAligned(valid);
        end
    end

    function val = safeEuValue(eu, idx)
        val = 1;
        if idx >= 1 && idx <= numel(eu) && isfinite(eu(idx)) && eu(idx) ~= 0
            val = eu(idx);
        end
    end

    function refVal = firstReferenceValue(dispComplex)
        refVal = NaN;
        for i = 1:size(dispComplex, 1)
            for j = 1:size(dispComplex, 2)
                val = dispComplex(i, j);
                if isfinite(real(val)) && isfinite(imag(val)) && abs(val) > 0
                    refVal = val;
                    return;
                end
            end
        end
    end

    function scale = computeDisplayScale(coords, dispReal)
        span = max(max(coords, [], 1) - min(coords, [], 1));
        if ~isfinite(span) || span <= 0
            span = 1;
        end
        maxDef = max(abs(dispReal(:)));
        if ~isfinite(maxDef) || maxDef <= 0
            scale = 0.1 * span;
        else
            scale = 0.18 * span / maxDef;
        end
    end

    function F = parseModalVnaFile(filePath)
        S = load(filePath, '-mat');
        if isfield(S, 'SLm')
            SLm = S.SLm;
        else
            vars = fieldnames(S);
            if isempty(vars)
                error('No variables found in file.');
            end
            SLm = S.(vars{1});
        end
        if ~isfield(SLm, 'fdxvec') || ~isfield(SLm, 'xcmeas') || ~isfield(SLm, 'scmeas')
            error('File does not contain required fields fdxvec / xcmeas / scmeas.');
        end
        [~, baseName, ~] = fileparts(filePath);
        eu = nan(1, numel(SLm.scmeas));
        for i = 1:numel(SLm.scmeas)
            eu(i) = normalizeEuValue(SLm.scmeas(i));
        end
        F = struct();
        F.name = baseName;
        F.path = filePath;
        F.freq = SLm.fdxvec(:);
        F.xcmeas = SLm.xcmeas;
        F.eu = eu;
        F.nResp = numel(SLm.scmeas);
        F.coh = [];
    end

    function val = normalizeEuValue(scRow)
        val = 1;
        if ~isstruct(scRow) || ~isfield(scRow, 'eu_val')
            return;
        end
        raw = scRow.eu_val;
        if isempty(raw) || ~isnumeric(raw)
            return;
        end
        raw = raw(:);
        raw = raw(isfinite(raw) & raw ~= 0);
        if isempty(raw)
            return;
        end
        val = raw(1);
    end

    function pointRows = defaultPointRows()
        pointRows = struct('use', {}, 'pointId', {}, 'fileName', {}, 'xCh', {}, 'yCh', {}, 'zCh', {}, 'x', {}, 'y', {}, 'z', {});
        pointRows(1) = defaultPointRow();
    end

    function row = defaultPointRow()
        row = struct('use', true, 'pointId', 'P1', 'fileName', '', 'xCh', 2, 'yCh', 3, 'zCh', 4, 'x', 0, 'y', 0, 'z', 0);
    end

    function lineRows = defaultLineRows()
        lineRows = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
    end

    function row = defaultLineRow()
        row = struct('use', true, 'startPointId', '', 'endPointId', '', 'source', 'manual');
    end

    function data = buildPointTableData(points)
        data = cell(numel(points), 9);
        for i = 1:numel(points)
            data{i, 1} = logical(points(i).use);
            data{i, 2} = points(i).pointId;
            data{i, 3} = points(i).fileName;
            data{i, 4} = points(i).xCh;
            data{i, 5} = points(i).yCh;
            data{i, 6} = points(i).zCh;
            data{i, 7} = points(i).x;
            data{i, 8} = points(i).y;
            data{i, 9} = points(i).z;
        end
    end

    function rows = parsePointTableData(data)
        rows = struct('use', {}, 'pointId', {}, 'fileName', {}, 'xCh', {}, 'yCh', {}, 'zCh', {}, 'x', {}, 'y', {}, 'z', {});
        if isempty(data)
            return;
        end
        for i = 1:size(data, 1)
            row = defaultPointRow();
            row.use = logicalFromValue(data{i, 1});
            row.pointId = normalizeText(data{i, 2});
            row.fileName = normalizeFileName(normalizeText(data{i, 3}), app.files);
            row.xCh = numericFromValue(data{i, 4}, row.xCh);
            row.yCh = numericFromValue(data{i, 5}, row.yCh);
            row.zCh = numericFromValue(data{i, 6}, row.zCh);
            row.x = numericFromValue(data{i, 7}, row.x);
            row.y = numericFromValue(data{i, 8}, row.y);
            row.z = numericFromValue(data{i, 9}, row.z);
            rows(end + 1) = row; %#ok<AGROW>
        end
    end

    function data = buildLineTableData(lines)
        if isempty(lines)
            data = cell(0, 4);
            return;
        end
        data = cell(numel(lines), 4);
        for i = 1:numel(lines)
            data{i, 1} = logical(lines(i).use);
            data{i, 2} = lines(i).startPointId;
            data{i, 3} = lines(i).endPointId;
            data{i, 4} = lines(i).source;
        end
    end

    function rows = parseLineTableData(data)
        rows = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        if isempty(data)
            return;
        end
        for i = 1:size(data, 1)
            row = defaultLineRow();
            row.use = logicalFromValue(data{i, 1});
            row.startPointId = normalizeText(data{i, 2});
            row.endPointId = normalizeText(data{i, 3});
            row.source = normalizeText(data{i, 4});
            if isempty(row.source)
                row.source = 'manual';
            end
            rows(end + 1) = row; %#ok<AGROW>
        end
        rows = sanitizeLineRows(rows);
    end

    function rows = sanitizeLineRows(rows)
        cleaned = struct('use', {}, 'startPointId', {}, 'endPointId', {}, 'source', {});
        for i = 1:numel(rows)
            row = rows(i);
            row.startPointId = normalizeText(row.startPointId);
            row.endPointId = normalizeText(row.endPointId);
            row.source = normalizeText(row.source);
            if isempty(row.source)
                row.source = 'manual';
            end
            if isempty(row.startPointId) || isempty(row.endPointId)
                continue;
            end
            if strcmpi(row.startPointId, row.endPointId)
                continue;
            end
            cleaned(end + 1) = row; %#ok<AGROW>
        end
        rows = cleaned;
    end

    function txt = normalizeText(val)
        if ischar(val)
            txt = strtrim(val);
        elseif isnumeric(val) && isscalar(val) && isfinite(val)
            txt = sprintf('%.15g', val);
        else
            txt = '';
        end
    end

    function tf = logicalFromValue(val)
        if islogical(val)
            tf = val;
        elseif isnumeric(val)
            tf = val ~= 0;
        elseif ischar(val)
            tf = ~isempty(regexpi(strtrim(val), '^(true|1|yes|on)$', 'once'));
        else
            tf = false;
        end
    end

    function num = numericFromValue(val, defaultVal)
        num = defaultVal;
        if isnumeric(val) && isscalar(val) && isfinite(val)
            num = val;
        elseif ischar(val)
            tmp = str2double(strtrim(val));
            if isfinite(tmp)
                num = tmp;
            end
        end
    end

    function fileName = normalizeFileName(fileName, files)
        if isempty(fileName)
            return;
        end
        for i = 1:numel(files)
            if strcmpi(files(i).name, fileName)
                fileName = files(i).name;
                return;
            end
        end
    end

    function idx = findFileIndexByName(files, fileName)
        idx = 0;
        fileName = strtrim(fileName);
        for i = 1:numel(files)
            if strcmpi(files(i).name, fileName)
                idx = i;
                return;
            end
        end
    end

    function rows = selectionRows(event)
        rows = [];
        if isempty(event) || ~isfield(event, 'Indices') || isempty(event.Indices)
            return;
        end
        rows = unique(event.Indices(:, 1));
    end

    function nextId = nextPointId(points)
        nums = zeros(1, numel(points));
        count = 0;
        for i = 1:numel(points)
            txt = upper(strtrim(points(i).pointId));
            token = regexp(txt, '^P(\d+)$', 'tokens', 'once');
            if ~isempty(token)
                count = count + 1;
                nums(count) = str2double(token{1});
            end
        end
        if count == 0
            nextId = 'P1';
        else
            nextId = sprintf('P%d', max(nums(1:count)) + 1);
        end
    end

    function cells = fullfileCell(folder, names)
        cells = cell(numel(names), 1);
        for i = 1:numel(names)
            cells{i} = fullfile(folder, names{i});
        end
    end

    function values = nanmeanColumns(mat)
        values = nan(size(mat, 1), 1);
        for i = 1:size(mat, 1)
            row = mat(i, :);
            valid = isfinite(row);
            if any(valid)
                values(i) = mean(row(valid));
            end
        end
    end

    function y = smoothCurve(x, win)
        if isempty(x)
            y = x;
            return;
        end
        win = max(1, round(win));
        if mod(win, 2) == 0
            win = win + 1;
        end
        kernel = ones(1, win) / win;
        y = conv(x(:).', kernel, 'same');
        y = y(:);
    end

    function values = minPositiveRows(mat)
        values = nan(size(mat, 1), 1);
        for i = 1:size(mat, 1)
            row = mat(i, :);
            valid = row(isfinite(row) & row > 0);
            if ~isempty(valid)
                values(i) = min(valid);
            end
        end
    end

    function sel = getSafeSelection(selIn, nMax)
        sel = selIn(:)';
        sel = sel(sel >= 1 & sel <= nMax);
    end

    function n = activePointCount()
        rows = getUsablePointRows(app.points, app.files, false);
        n = numel(rows);
    end

    function bindings = nonemptyPointBindings(points)
        bindings = {};
        for i = 1:numel(points)
            if ~isempty(strtrim(points(i).fileName))
                bindings{end + 1} = points(i).fileName; %#ok<AGROW>
            end
        end
    end

end

