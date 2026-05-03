function view_dyna_gui()
% GUI for vibration data (.vna/.mat/.txt/.dat/.csv/.xlsx)
% - channel single/multi selection
% - plot button drives time/PSD/transmissibility
% - optional low-pass/high-pass filtering in time domain

% 根据屏幕分辨率计算初始窗口尺寸（保留最小显示空间）
screenSz = get(0, 'ScreenSize');
figW = max(1220, min(round(screenSz(3) * 0.80), 1420));
figH = max(760, min(round(screenSz(4) * 0.76), 820));
figX = max(20, round((screenSz(3) - figW) / 2));
figY = max(20, round((screenSz(4) - figH) / 2));

% 创建主窗口，并关闭窗口编号显示
fig = figure( ...
    'Name', 'Vibration Viewer', ...
    'NumberTitle', 'off', ...
    'Position', [figX figY figW figH], ...
    'Color', get(0, 'DefaultUicontrolBackgroundColor'), ...
    'MenuBar', 'figure', ...
    'ToolBar', 'figure', ...
    'Resize', 'on');
% 初始化应用状态（文件列表、数据项、滤波与自定义信息）
app = initAppState();
app.lastOpenDir = pwd;
setappdata(fig, 'app', app);

% 左侧控制面板：文件加载、数据列表、重命名与滤波参数
panel = uipanel('Parent', fig, 'Title', 'Controls', 'Units', 'pixels', 'Position', [15 15 360 890]);

btnLoad = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Load Files', ...
    'Position', [15 848 100 30], ...
    'Callback', @onLoadFile);
btnLoadFolder = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Load Folder', ...
    'Position', [125 848 100 30], ...
    'Callback', @onLoadFolder);

edtFile = uicontrol('Parent', panel, 'Style', 'edit', ...
    'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'String', 'No file loaded', ...
    'Position', [15 810 330 30]);

lblFs = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Fs (Hz):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [130 852 55 22]);
edtFs = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '1000', ...
    'BackgroundColor', 'w', ...
    'Position', [175 848 70 30]);

lblTStart = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Time Start (s):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 810 90 22]);
edtTStart = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Position', [105 806 70 30]);

lblTEnd = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Time End (s):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [180 810 80 22]);
edtTEnd = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Position', [260 806 70 30]);

lblPsdSource = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'PSD Source:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 775 70 22]);
ddPsdSource = uicontrol('Parent', panel, 'Style', 'popupmenu', ...
    'String', {'From Time Segment (periodogram)', 'VNA Native'}, ...
    'Value', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [90 772 240 24]);

lblQuantity = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Quantity:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 742 70 22]);
ddQuantity = uicontrol('Parent', panel, 'Style', 'popupmenu', ...
    'String', {'Acceleration', 'Velocity', 'Displacement'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [90 739 240 24]);

lblDataList = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Data List (File+Channel):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 775 180 22]);
lstData = uicontrol('Parent', panel, 'Style', 'listbox', ...
    'Max', 2, 'Min', 0, ...
    'String', {' '}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Callback', @onDataSelectionChanged, ...
    'Position', [15 610 330 165]);

lblFilter = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Filter:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 565 45 22]);
chkLow = uicontrol('Parent', panel, 'Style', 'checkbox', ...
    'String', 'Low-pass', ...
    'Value', 0, ...
    'Position', [70 560 85 22]);
chkHigh = uicontrol('Parent', panel, 'Style', 'checkbox', ...
    'String', 'High-pass', ...
    'Value', 0, ...
    'Position', [160 560 90 22]);

lblLowCutoff = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'LP (Hz):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 525 55 22]);
edtLowCutoff = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '100', ...
    'BackgroundColor', 'w', ...
    'Position', [70 520 90 30]);

lblHighCutoff = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'HP (Hz):', ...
    'HorizontalAlignment', 'left', ...
    'Position', [175 525 55 22]);
edtHighCutoff = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '5', ...
    'BackgroundColor', 'w', ...
    'Position', [230 520 90 30]);

lblOrder = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Order:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 485 45 22]);
edtOrder = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '4', ...
    'BackgroundColor', 'w', ...
    'Position', [60 480 60 30]);

btnPlot = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Plot', ...
    'Position', [15 430 100 30], ...
    'Callback', @onPlot);

btnHold = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', 'Hold', ...
    'Value', 0, ...
    'Position', [125 430 90 30], ...
    'Callback', @onHoldChanged);

btnReset = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Reset Filter', ...
    'Position', [225 430 100 30], ...
    'Callback', @onResetFilter);

btnClear = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Clear Plots', ...
    'Position', [335 430 110 30], ...
    'Callback', @onClearPlots);

btnDeleteSelected = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Delete Selected', ...
    'Position', [15 575 330 30], ...
    'Callback', @onDeleteSelectedFiles);

lblRename = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Rename:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 540 55 22]);

edtRename = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Callback', @onRenameEdited, ...
    'Position', [70 536 275 30]);

lblScale = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Factor:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [250 540 40 22]);

edtScale = uicontrol('Parent', panel, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Callback', @onScaleEdited, ...
    'Position', [292 536 53 30]);

lblStatus = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', 'Status: ready', ...
    'HorizontalAlignment', 'left', ...
    'Position', [15 340 330 40]);

% 右侧三幅图的类型选择与导出按钮
% 左侧折叠分组状态（会话内保持）
isDataGroupExpanded = true;
isMainGroupExpanded = false;
isPlotGroupExpanded = true;

% 左侧折叠分组：标题按钮 + 内容面板（MATLAB 2016 compatible）
btnDataGroup = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', '[-] Data', ...
    'Value', 1, ...
    'Callback', @onToggleDataGroup);
grpData = uipanel('Parent', panel, 'BorderType', 'line', 'Title', '');

btnMainGroup = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', '[+] Main Processing', ...
    'Value', 0, ...
    'Callback', @onToggleMainGroup);
grpMainProc = uipanel('Parent', panel, 'BorderType', 'line', 'Title', '');

btnPlotGroup = uicontrol('Parent', panel, 'Style', 'togglebutton', ...
    'String', '[-] Plot', ...
    'Value', 1, ...
    'Callback', @onTogglePlotGroup);
grpPlot = uipanel('Parent', panel, 'BorderType', 'line', 'Title', '');

set([grpData, grpMainProc, grpPlot], 'Units', 'pixels');

set([btnLoad, btnLoadFolder, edtFile, lblDataList, lstData, lblRename, edtRename, ...
    lblScale, edtScale, btnDeleteSelected], 'Parent', grpData);

set([lblFs, edtFs, lblTStart, edtTStart, lblTEnd, edtTEnd, lblPsdSource, ddPsdSource, ...
    lblQuantity, ddQuantity, ...
    lblFilter, chkLow, chkHigh, lblLowCutoff, edtLowCutoff, lblHighCutoff, edtHighCutoff, ...
    lblOrder, edtOrder, btnReset], 'Parent', grpMainProc);
set(btnReset, 'String', 'Reset');

set([btnPlot, btnHold, btnClear, lblStatus], 'Parent', grpPlot);

tabRight = uitabgroup('Parent', fig, 'Units', 'pixels', 'Position', [390 15 1095 860]);
tabMain = uitab('Parent', tabRight, 'Title', 'Main');
tabFoundation = uitab('Parent', tabRight, 'Title', 'Floor Vibration');
try
    set(tabRight, 'SelectionChangedFcn', @onTabChanged);
catch
    try
        set(tabRight, 'SelectionChangeFcn', @onTabChanged);
    catch
    end
end

lblSel1 = uicontrol('Parent', tabMain, 'Style', 'text', ...
    'String', 'Plot 1:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [390 870 45 22]);
ddSel1 = uicontrol('Parent', tabMain, 'Style', 'popupmenu', ...
    'String', {'Time', 'PSD', 'CumPSD', 'Trans', 'Coherence'}, ...
    'Value', 1, ...
    'BackgroundColor', 'w', ...
    'Position', [440 868 110 24]);
btnFig1 = uicontrol('Parent', tabMain, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [556 866 62 26]);

lblSel2 = uicontrol('Parent', tabMain, 'Style', 'text', ...
    'String', 'Plot 2:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [390 620 45 22]);
ddSel2 = uicontrol('Parent', tabMain, 'Style', 'popupmenu', ...
    'String', {'Time', 'PSD', 'CumPSD', 'Trans', 'Coherence'}, ...
    'Value', 2, ...
    'BackgroundColor', 'w', ...
    'Position', [440 618 110 24]);
btnFig2 = uicontrol('Parent', tabMain, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [556 616 62 26]);

lblSel3 = uicontrol('Parent', tabMain, 'Style', 'text', ...
    'String', 'Plot 3:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [390 370 45 22]);
ddSel3 = uicontrol('Parent', tabMain, 'Style', 'popupmenu', ...
    'String', {'Time', 'PSD', 'CumPSD', 'Trans', 'Coherence'}, ...
    'Value', 4, ...
    'BackgroundColor', 'w', ...
    'Position', [440 368 110 24]);
btnFig3 = uicontrol('Parent', tabMain, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [556 366 62 26]);

% 三个主绘图区：时域、PSD、传递率
axMain1 = axes('Parent', tabMain, 'Units', 'pixels', 'Position', [20 585 1030 235], 'Box', 'on');
title(axMain1, 'Time Domain');
xlabel(axMain1, 'Time (s)');
ylabel(axMain1, 'Acceleration (m/s^2)');
grid(axMain1, 'on');

axMain2 = axes('Parent', tabMain, 'Units', 'pixels', 'Position', [20 325 1030 235], 'Box', 'on');
title(axMain2, 'PSD');
xlabel(axMain2, 'Frequency (Hz)');
ylabel(axMain2, '(m/s^2)^2/Hz');
set(axMain2, 'XScale', 'log', 'YScale', 'log');
grid(axMain2, 'on');

axMain3 = axes('Parent', tabMain, 'Units', 'pixels', 'Position', [20 65 1030 235], 'Box', 'on');
title(axMain3, 'Transmissibility (dB)');
xlabel(axMain3, 'Frequency (Hz)');
ylabel(axMain3, 'dB');
set(axMain3, 'XScale', 'log', 'YScale', 'linear');
grid(axMain3, 'on');

% 每幅图旁边的 Figure 按钮：导出当前图到单独窗口
lblVibFile = uicontrol('Parent', tabFoundation, 'Style', 'text', ...
    'String', 'Vib File:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 820 60 22]);
ddVibFile = uicontrol('Parent', tabFoundation, 'Style', 'popupmenu', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Enable', 'off', ...
    'BackgroundColor', 'w', ...
    'UserData', NaN, ...
    'Callback', @onFoundationSourceChanged, ...
    'Position', [82 818 250 24]);

lblStiffFile = uicontrol('Parent', tabFoundation, 'Style', 'text', ...
    'String', 'Stiff File:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [350 820 68 22]);
ddStiffFile = uicontrol('Parent', tabFoundation, 'Style', 'popupmenu', ...
    'String', {'(none)'}, ...
    'Value', 1, ...
    'Enable', 'off', ...
    'BackgroundColor', 'w', ...
    'UserData', NaN, ...
    'Callback', @onFoundationSourceChanged, ...
    'Position', [420 818 250 24]);

lblVibCh = uicontrol('Parent', tabFoundation, 'Style', 'text', ...
    'String', 'Vib Ch:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [20 786 52 22]);
edtVibCh = uicontrol('Parent', tabFoundation, 'Style', 'edit', ...
    'String', '2,3,4', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Position', [74 782 120 28]);

lblExciteCh = uicontrol('Parent', tabFoundation, 'Style', 'text', ...
    'String', 'Excite Ch:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [220 786 66 22], ...
    'Visible', 'off');
edtExciteCh = uicontrol('Parent', tabFoundation, 'Style', 'edit', ...
    'String', '1', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Position', [288 782 55 28], ...
    'Visible', 'off', ...
    'Enable', 'off');

lblRespCh = uicontrol('Parent', tabFoundation, 'Style', 'text', ...
    'String', 'Stiff Ch:', ...
    'HorizontalAlignment', 'left', ...
    'Position', [360 786 60 22]);
edtRespCh = uicontrol('Parent', tabFoundation, 'Style', 'edit', ...
    'String', '4', ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'Position', [422 782 55 28]);

chkVCA = uicontrol('Parent', tabFoundation, 'Style', 'checkbox', ...
    'String', 'VC A', ...
    'Value', 1, ...
    'Position', [510 784 58 22]);
chkVCB = uicontrol('Parent', tabFoundation, 'Style', 'checkbox', ...
    'String', 'VC B', ...
    'Value', 1, ...
    'Position', [570 784 58 22]);
chkVCC = uicontrol('Parent', tabFoundation, 'Style', 'checkbox', ...
    'String', 'VC C', ...
    'Value', 1, ...
    'Position', [630 784 58 22]);
chkVCD = uicontrol('Parent', tabFoundation, 'Style', 'checkbox', ...
    'String', 'VC D', ...
    'Value', 1, ...
    'Position', [690 784 58 22]);

axFoundVib = axes('Parent', tabFoundation, 'Units', 'pixels', 'Position', [20 390 1030 360], 'Box', 'on');
title(axFoundVib, 'Floor Vibration (One-Third Octave)');
xlabel(axFoundVib, 'One-Third Octave Band Frequency [Hz]');
ylabel(axFoundVib, 'RMS Velocity [um/s]');
set(axFoundVib, 'XScale', 'log', 'YScale', 'log');
grid(axFoundVib, 'on');

axFoundStiff = axes('Parent', tabFoundation, 'Units', 'pixels', 'Position', [20 235 1030 215], 'Box', 'on');
title(axFoundStiff, 'Dynamic Stiffness');
xlabel(axFoundStiff, 'Frequency [Hz]');
ylabel(axFoundStiff, 'Magnitude [N/m]');
set(axFoundStiff, 'XScale', 'log', 'YScale', 'log');
grid(axFoundStiff, 'on');

axFoundCoh = axes('Parent', tabFoundation, 'Units', 'pixels', 'Position', [20 65 1030 145], 'Box', 'on');
title(axFoundCoh, 'Coherence');
xlabel(axFoundCoh, 'Frequency [Hz]');
ylabel(axFoundCoh, 'Coherence');
set(axFoundCoh, 'XScale', 'log', 'YScale', 'linear');
ylim(axFoundCoh, [0 1]);
grid(axFoundCoh, 'on');

btnFoundVibFig = uicontrol('Parent', tabFoundation, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [980 720 62 26]);
btnFoundStiffCohFig = uicontrol('Parent', tabFoundation, 'Style', 'pushbutton', ...
    'String', 'Figure', ...
    'Position', [980 420 62 26]);

set(btnFig1, 'Callback', @(~, ~) onOpenAxisFigure(axMain1, 'Plot 1'));
set(btnFig2, 'Callback', @(~, ~) onOpenAxisFigure(axMain2, 'Plot 2'));
set(btnFig3, 'Callback', @(~, ~) onOpenAxisFigure(axMain3, 'Plot 3'));
set(btnFoundVibFig, 'Callback', @onOpenFoundationVibFigure);
set(btnFoundStiffCohFig, 'Callback', @onOpenFoundationStiffCohFigure);
refreshFoundationFileSelectors();

% 绑定窗口尺寸变化回调并执行一次初始布局
set(fig, 'ResizeFcn', @onResize);
onResize();

    % 自适应布局：根据窗口尺寸重排左侧控件和右侧三幅图
    function onResize(~, ~)
        figPos = get(fig, 'Position');
        fw = figPos(3);
        fh = figPos(4);
        minW = 1220;
        minH = 760;
        if fw < minW || fh < minH
            figPos(3) = max(fw, minW);
            figPos(4) = max(fh, minH);
            set(fig, 'Position', figPos);
            fw = figPos(3);
            fh = figPos(4);
        end
        margin = 15;
        gapLR = 15;
        titleSafe = 26;

        % Left control area width follows window size with limits.
        leftW = max(300, min(380, round(fw * 0.24)));
        set(panel, 'Position', [margin, margin, leftW, max(640, fh - 2 * margin)]);

        panelPos = get(panel, 'Position');
        pw = panelPos(3);
        ph = panelPos(4);
        xPad = 8;
        yGap = 6;
        headerH = 26;
        bodyW = max(200, pw - 2 * xPad);
        yCursor = ph - titleSafe;

        mainGroupVisible = ~isFoundationTabSelected(tabRight, tabFoundation);
        plotGroupVisible = ~isFoundationTabSelected(tabRight, tabFoundation);
        if mainGroupVisible
            set(btnMainGroup, 'Visible', 'on');
        else
            set(btnMainGroup, 'Visible', 'off');
            set(grpMainProc, 'Visible', 'off');
        end
        if plotGroupVisible
            set(btnPlotGroup, 'Visible', 'on');
        else
            set(btnPlotGroup, 'Visible', 'off');
            set(grpPlot, 'Visible', 'off');
        end

        set(btnDataGroup, 'String', getGroupTitle('Data', isDataGroupExpanded), ...
            'Value', double(isDataGroupExpanded));
        set(btnMainGroup, 'String', getGroupTitle('Main Processing', isMainGroupExpanded), ...
            'Value', double(isMainGroupExpanded));
        set(btnPlotGroup, 'String', getGroupTitle('Plot', isPlotGroupExpanded), ...
            'Value', double(isPlotGroupExpanded));

        visibleCount = 1 + double(mainGroupVisible) + double(plotGroupVisible);
        innerAvailH = max(260, ph - titleSafe - 8);
        bodyBudget = innerAvailH - visibleCount * headerH - (visibleCount + 1) * yGap;
        if bodyBudget < 0
            bodyBudget = 0;
        end

        minDataH = 120;
        minMainH = 140;
        minPlotH = 90;
        dataH = 0;
        mainH = 0;
        plotH = 0;
        if mainGroupVisible && isMainGroupExpanded
            mainH = 214;
        end
        if plotGroupVisible && isPlotGroupExpanded
            plotH = 120;
        end
        if isDataGroupExpanded
            dataH = bodyBudget - mainH - plotH;
            if dataH < minDataH
                need = minDataH - dataH;
                if mainH > 0
                    cut = min(need, max(0, mainH - minMainH));
                    mainH = mainH - cut;
                    need = need - cut;
                end
                if need > 0 && plotH > 0
                    cut = min(need, max(0, plotH - minPlotH));
                    plotH = plotH - cut;
                end
                dataH = max(90, bodyBudget - mainH - plotH);
            end
        end

        % Data group
        set(btnDataGroup, 'Position', [xPad, yCursor - headerH, bodyW, headerH]);
        yCursor = yCursor - headerH;
        if isDataGroupExpanded
            set(grpData, 'Visible', 'on', 'Position', [xPad, yCursor - dataH, bodyW, dataH]);
            yCursor = yCursor - dataH - yGap;
        else
            set(grpData, 'Visible', 'off', 'Position', [xPad, yCursor, bodyW, 1]);
            yCursor = yCursor - yGap;
        end

        % Main processing group (shown only in Main tab)
        if mainGroupVisible
            set(btnMainGroup, 'Position', [xPad, yCursor - headerH, bodyW, headerH]);
            yCursor = yCursor - headerH;
            if isMainGroupExpanded
                set(grpMainProc, 'Visible', 'on', 'Position', [xPad, yCursor - mainH, bodyW, mainH]);
                yCursor = yCursor - mainH - yGap;
            else
                set(grpMainProc, 'Visible', 'off', 'Position', [xPad, yCursor, bodyW, 1]);
                yCursor = yCursor - yGap;
            end
        end

        % Plot group (shown only in Main tab)
        if plotGroupVisible
            set(btnPlotGroup, 'Position', [xPad, yCursor - headerH, bodyW, headerH]);
            yCursor = yCursor - headerH;
            if isPlotGroupExpanded
                set(grpPlot, 'Visible', 'on', 'Position', [xPad, max(6, yCursor - plotH), bodyW, plotH]);
            else
                set(grpPlot, 'Visible', 'off', 'Position', [xPad, max(6, yCursor), bodyW, 1]);
            end
        end

        % Layout inside Data group
        if isDataGroupExpanded
            gw = bodyW;
            gh = dataH;
            gx = 10;
            gy = gh - 8;
            innerW = max(150, gw - 2 * gx);
            rowH = 28;
            rowGap = 6;

            loadW = floor((innerW - rowGap) / 2);
            set(btnLoad, 'Position', [gx, gy - rowH, loadW, rowH]);
            set(btnLoadFolder, 'Position', [gx + loadW + rowGap, gy - rowH, innerW - loadW - rowGap, rowH]);
            gy = gy - rowH - rowGap;

            set(edtFile, 'Position', [gx, gy - rowH, innerW, rowH]);
            gy = gy - rowH - rowGap;

            set(lblDataList, 'Position', [gx, gy - 20, innerW, 20]);
            gy = gy - 20 - rowGap;

            renameH = 28;
            deleteH = 28;
            listH = gy - (renameH + rowGap + deleteH + 8);
            listH = max(55, listH);
            set(lstData, 'Position', [gx, gy - listH, innerW, listH]);
            gy = gy - listH - rowGap;

            renameLabelW = 52;
            factorLabelW = 42;
            factorEditW = 52;
            renameGap = 6;
            renameW = max(72, innerW - renameLabelW - factorLabelW - factorEditW - 3 * renameGap);
            set(lblRename, 'Position', [gx, gy - renameH + 4, renameLabelW, 22]);
            set(edtRename, 'Position', [gx + renameLabelW + renameGap, gy - renameH, renameW, renameH]);
            fx = gx + renameLabelW + renameGap + renameW + renameGap;
            set(lblScale, 'Position', [fx, gy - renameH + 4, factorLabelW, 22]);
            set(edtScale, 'Position', [fx + factorLabelW + renameGap, gy - renameH, factorEditW, renameH]);
            gy = gy - renameH - rowGap;

            set(btnDeleteSelected, 'Position', [gx, gy - deleteH, innerW, deleteH]);
        end

        % Layout inside Main processing group
        if mainGroupVisible && isMainGroupExpanded
            gw = bodyW;
            gh = mainH;
            gx = 10;
            gy = gh - 8;
            innerW = max(150, gw - 2 * gx);
            rowH = 24;
            rowGap = 4;

            fsEditW = 68;
            set(lblFs, 'Position', [gx, gy - rowH + 4, 55, 22]);
            set(edtFs, 'Position', [innerW + gx - fsEditW, gy - rowH, fsEditW, rowH]);
            gy = gy - rowH - rowGap;

            tLabelW = 86;
            tGap = 8;
            tEditW = floor((innerW - 2 * tLabelW - tGap) / 2);
            set(lblTStart, 'Position', [gx, gy - rowH + 4, tLabelW, 22]);
            set(edtTStart, 'Position', [gx + tLabelW, gy - rowH, tEditW, rowH]);
            x2 = gx + tLabelW + tEditW + tGap;
            set(lblTEnd, 'Position', [x2, gy - rowH + 4, tLabelW - 8, 22]);
            set(edtTEnd, 'Position', [x2 + tLabelW - 8, gy - rowH, tEditW, rowH]);
            gy = gy - rowH - rowGap;

            psdLabelW = 72;
            set(lblPsdSource, 'Position', [gx, gy - rowH + 4, psdLabelW, 22]);
            set(ddPsdSource, 'Position', [gx + psdLabelW + 4, gy - rowH + 1, innerW - psdLabelW - 4, 24]);
            gy = gy - rowH - rowGap;

            qtyLabelW = 72;
            set(lblQuantity, 'Position', [gx, gy - rowH + 4, qtyLabelW, 22]);
            set(ddQuantity, 'Position', [gx + qtyLabelW + 4, gy - rowH + 1, innerW - qtyLabelW - 4, 24]);
            gy = gy - rowH - rowGap;

            resetW = 58;
            set(lblFilter, 'Position', [gx, gy - rowH + 4, 45, 22]);
            set(chkLow, 'Position', [gx + 48, gy - rowH + 2, 82, 22]);
            set(chkHigh, 'Position', [gx + 130, gy - rowH + 2, 86, 22]);
            set(btnReset, 'Position', [gx + innerW - resetW, gy - rowH + 1, resetW, 24]);
            gy = gy - rowH - rowGap;

            colGap = 8;
            colW = floor((innerW - colGap) / 2);
            cutoffLabelW = 50;
            cutoffEditW = max(48, colW - cutoffLabelW - 4);
            set(lblLowCutoff, 'Position', [gx, gy - rowH + 4, cutoffLabelW, 22]);
            set(edtLowCutoff, 'Position', [gx + cutoffLabelW + 4, gy - rowH, cutoffEditW, rowH]);
            rightColX = gx + colW + colGap;
            set(lblHighCutoff, 'Position', [rightColX, gy - rowH + 4, cutoffLabelW, 22]);
            set(edtHighCutoff, 'Position', [rightColX + cutoffLabelW + 4, gy - rowH, cutoffEditW, rowH]);
            gy = gy - rowH - rowGap;

            set(lblOrder, 'Position', [gx, gy - rowH + 4, 45, 22]);
            set(edtOrder, 'Position', [gx + 45, gy - rowH, 60, rowH]);
        end

        % Layout inside Plot group
        if plotGroupVisible && isPlotGroupExpanded
            gw = bodyW;
            gh = plotH;
            gx = 10;
            gy = gh - 8;
            innerW = max(150, gw - 2 * gx);
            btnGap = 8;
            btnH = 30;
            btnW = floor((innerW - 2 * btnGap) / 3);
            set(btnPlot, 'Position', [gx, gy - btnH, btnW, btnH]);
            set(btnHold, 'Position', [gx + btnW + btnGap, gy - btnH, btnW, btnH]);
            set(btnClear, 'Position', [gx + 2 * (btnW + btnGap), gy - btnH, innerW - 2 * (btnW + btnGap), btnH]);
            set(lblStatus, 'Position', [gx, gy - btnH - 36, innerW, 30]);
        end

        % Right side tab group area.
        rightXFig = margin + leftW + gapLR;
        rightMargin = 10;
        rightW = max(420, fw - rightXFig - rightMargin);
        rightH = max(430, fh - 2 * margin);
        set(tabRight, 'Position', [rightXFig, margin, rightW, rightH]);

        tabPos = get(tabRight, 'Position');
        tw = tabPos(3);
        th = tabPos(4);

        % Main tab layout (3 stacked plots).
        mPadX = 8;
        mTopPad = 30;
        mBottomPad = 8;
        mRowGap = 8;
        selH = 24;
        rowH = floor((th - mTopPad - mBottomPad - 2 * mRowGap) / 3);
        axH = max(95, rowH - selH - 8);
        axX = mPadX;
        axW = max(360, tw - 2 * mPadX);
        selLabelW = 45;
        selW = 110;
        figBtnW = 62;
        selLabelX = mPadX;
        selX = selLabelX + selLabelW + 6;
        figBtnX = selX + selW + 6;

        top1 = th - mTopPad - rowH;
        top2 = top1 - mRowGap - rowH;
        top3 = top2 - mRowGap - rowH;

        set(lblSel1, 'Position', [selLabelX, top1 + rowH - selH + 2, selLabelW, 22]);
        set(ddSel1, 'Position', [selX, top1 + rowH - selH, selW, selH]);
        set(btnFig1, 'Position', [figBtnX, top1 + rowH - selH - 1, figBtnW, 26]);
        set(axMain1, 'OuterPosition', [axX, top1, axW, axH]);

        set(lblSel2, 'Position', [selLabelX, top2 + rowH - selH + 2, selLabelW, 22]);
        set(ddSel2, 'Position', [selX, top2 + rowH - selH, selW, selH]);
        set(btnFig2, 'Position', [figBtnX, top2 + rowH - selH - 1, figBtnW, 26]);
        set(axMain2, 'OuterPosition', [axX, top2, axW, axH]);

        set(lblSel3, 'Position', [selLabelX, top3 + rowH - selH + 2, selLabelW, 22]);
        set(ddSel3, 'Position', [selX, top3 + rowH - selH, selW, selH]);
        set(btnFig3, 'Position', [figBtnX, top3 + rowH - selH - 1, figBtnW, 26]);
        set(axMain3, 'OuterPosition', [axX, top3, axW, axH]);

        % Foundation tab layout.
        fPadX = 12;
        fTopY = th - 68;
        fBottomPad = 10;
        labelVibW = 58;
        labelStiffW = 66;
        fileGap = 10;
        filePopW = max(80, floor((tw - 2 * fPadX - labelVibW - labelStiffW - fileGap - 12) / 2));
        vibPopX = fPadX + labelVibW + 4;
        stiffLblX = vibPopX + filePopW + fileGap;
        stiffPopX = stiffLblX + labelStiffW + 4;

        set(lblVibFile, 'Position', [fPadX, fTopY + 2, labelVibW, 22]);
        set(ddVibFile, 'Position', [vibPopX, fTopY, filePopW, 24]);
        set(lblStiffFile, 'Position', [stiffLblX, fTopY + 2, labelStiffW, 22]);
        set(ddStiffFile, 'Position', [stiffPopX, fTopY, filePopW, 24]);

        row2Y = fTopY - 34;
        cfgGap = 6;
        vibLblW = 46; vibEditW = 88;
        rpLblW = 56; rpEditW = 80;
        x0 = fPadX;
        set(lblVibCh, 'Position', [x0, row2Y + 2, vibLblW, 22]);
        x0 = x0 + vibLblW + 2;
        set(edtVibCh, 'Position', [x0, row2Y, vibEditW, 28]);
        x0 = x0 + vibEditW + cfgGap;
        set(lblExciteCh, 'Visible', 'off');
        set(edtExciteCh, 'Visible', 'off');
        set(lblRespCh, 'Position', [x0, row2Y + 2, rpLblW, 22]);
        x0 = x0 + rpLblW + 2;
        set(edtRespCh, 'Position', [x0, row2Y, rpEditW, 28]);

        row3Y = row2Y - 30;
        vcGap = 8;
        vcW = 56;
        vcX = fPadX;
        set(chkVCA, 'Position', [vcX, row3Y + 2, vcW, 22]);
        vcX = vcX + vcW + vcGap;
        set(chkVCB, 'Position', [vcX, row3Y + 2, vcW, 22]);
        vcX = vcX + vcW + vcGap;
        set(chkVCC, 'Position', [vcX, row3Y + 2, vcW, 22]);
        vcX = vcX + vcW + vcGap;
        set(chkVCD, 'Position', [vcX, row3Y + 2, vcW, 22]);

        fAxGap = 8;
        fAxTop = row3Y - 8;
        fAxAvailH = max(300, fAxTop - fBottomPad);
        fAxBottomH = floor((fAxAvailH - 2 * fAxGap) / 3);
        fAxMidH = fAxBottomH;
        fAxTopH = fAxAvailH - 2 * fAxGap - fAxMidH - fAxBottomH;
        fBtnW = 62;
        fBtnH = 26;
        fBtnGap = 8;
        fAxX = fPadX;
        fAxW = max(300, tw - 2 * fPadX - fBtnW - fBtnGap);
        fAxBottomY = fBottomPad;
        fAxMidY = fAxBottomY + fAxBottomH + fAxGap;
        fAxTopY = fAxMidY + fAxMidH + fAxGap;

        set(axFoundVib, 'OuterPosition', [fAxX, fAxTopY, fAxW, fAxTopH]);
        set(axFoundStiff, 'OuterPosition', [fAxX, fAxMidY, fAxW, fAxMidH]);
        set(axFoundCoh, 'OuterPosition', [fAxX, fAxBottomY, fAxW, fAxBottomH]);

        fBtnX = fAxX + fAxW + fBtnGap;
        if (fBtnX + fBtnW) > (tw - fPadX)
            fBtnX = tw - fPadX - fBtnW;
        end
        vibBtnY = max(fAxTopY + fAxTopH - fBtnH - 2, fAxTopY + 2);
        stiffBtnY = max(fAxMidY + fAxMidH - fBtnH - 2, fAxMidY + 2);
        set(btnFoundVibFig, 'Position', [fBtnX, vibBtnY, fBtnW, fBtnH]);
        set(btnFoundStiffCohFig, 'Position', [fBtnX, stiffBtnY, fBtnW, fBtnH]);
    end

    % 加载数据文件（支持多选），并重建“数据项列表”
    function txt = getGroupTitle(baseName, expanded)
        if expanded
            txt = ['[-] ' baseName];
        else
            txt = ['[+] ' baseName];
        end
    end

    function onToggleDataGroup(~, ~)
        isDataGroupExpanded = logical(get(btnDataGroup, 'Value'));
        onResize();
    end

    function onToggleMainGroup(~, ~)
        isMainGroupExpanded = logical(get(btnMainGroup, 'Value'));
        onResize();
    end

    function onTogglePlotGroup(~, ~)
        isPlotGroupExpanded = logical(get(btnPlotGroup, 'Value'));
        onResize();
    end

    function onTabChanged(~, ~)
        onResize();
    end

    function onLoadFile(~, ~)
        app = getappdata(fig, 'app');
        startDir = app.lastOpenDir;
        if isempty(startDir) || ~isDirCompat(startDir)
            startDir = pwd;
        end

        [fname, fpath] = uigetfile( ...
            {'*.vna;*.mat;*.txt;*.dat;*.csv;*.xlsx', 'Data Files (*.vna,*.mat,*.txt,*.dat,*.csv,*.xlsx)'; ...
             '*.*', 'All Files (*.*)'}, ...
            'Select vibration data file(s)', ...
            startDir, ...
            'MultiSelect', 'on');
        if isequal(fname, 0)
            return;
        end

        if isTextScalarCompat(fname)
            fileList = {char(fname)};
        else
            fileList = fname;
        end

        [app, loadedNow, failedNow, lastErr] = loadFilesByNameList(app, fileList, fpath);
        app.lastOpenDir = fpath;
        finalizeLoadResult(app, loadedNow, failedNow, lastErr, 'file(s)');
    end

    % 主绘图入口：按所选数据项与图类型刷新三幅图
    function onLoadFolder(~, ~)
        app = getappdata(fig, 'app');
        startDir = app.lastOpenDir;
        if isempty(startDir) || ~isDirCompat(startDir)
            startDir = pwd;
        end

        folderPath = uigetdir(startDir, 'Select a folder containing data files');
        if isequal(folderPath, 0)
            return;
        end

        fileList = listSupportedFilesInFolder(folderPath);
        if isempty(fileList)
            showAlertCompat(fig, 'No supported data files found in the selected folder.', 'Load folder');
            return;
        end

        [app, loadedNow, failedNow, lastErr] = loadFilesByNameList(app, fileList, folderPath);
        app.lastOpenDir = folderPath;
        finalizeLoadResult(app, loadedNow, failedNow, lastErr, 'file(s) from folder');
    end

    function [app, loadedNow, failedNow, lastErr] = loadFilesByNameList(app, fileList, rootPath)
        set(lblStatus, 'String', sprintf('Status: loading %d file(s)...', numel(fileList)));
        drawnow;

        loadedNow = 0;
        failedNow = 0;
        lastErr = '';
        for i = 1:numel(fileList)
            oneFile = fileList{i};
            fullName = fullfile(rootPath, oneFile);
            try
                D = readVibrationFile(fullName, getNumericControlValue(edtFs, 1000));
                D.filePath = fullName;
                D.fileName = getSeriesDisplayFileName(oneFile);
                D.id = app.nextFileId;
                app.nextFileId = app.nextFileId + 1;
                app.files{end + 1} = D;
                app.loaded = true;
                loadedNow = loadedNow + 1;
            catch ME
                failedNow = failedNow + 1;
                lastErr = ME.message;
            end
        end
    end

    function finalizeLoadResult(app, loadedNow, failedNow, lastErr, srcLabel)
        if ~isempty(app.files)
            app.validChannels = collectValidChannels(app.files);
            app.fs = app.files{end}.fs;
            setNumericControlValue(edtFs, app.fs);
            app = rebuildSeriesList(app);
        end

        setappdata(fig, 'app', app);
        refreshLoadedFilesList();
        refreshFoundationFileSelectors();

        cla(axMain1); cla(axMain2); cla(axMain3);
        cla(axFoundVib); cla(axFoundStiff); cla(axFoundCoh);

        if isempty(app.files)
            showAlertCompat(fig, 'No files were loaded successfully.', 'Load failed');
            if ~isempty(lastErr)
                set(lblStatus, 'String', ['Status: load failed | ' lastErr]);
            else
                set(lblStatus, 'String', 'Status: load failed');
            end
            return;
        end

        set(edtFile, 'String', summarizeLoadedFiles(app.files));
        if failedNow > 0
            set(lblStatus, 'String', sprintf('Status: loaded %d %s, failed %d | last error: %s', loadedNow, srcLabel, failedNow, lastErr));
        else
            set(lblStatus, 'String', sprintf('Status: loaded %d %s | generated %d data entries', loadedNow, srcLabel, numel(app.series)));
        end
    end

    function fileList = listSupportedFilesInFolder(folderPath)
        fileList = {};
        if isempty(folderPath) || ~isDirCompat(folderPath)
            return;
        end

        entries = dir(folderPath);
        exts = {'.vna', '.mat', '.txt', '.dat', '.csv', '.xlsx'};
        names = {};
        for i = 1:numel(entries)
            one = entries(i);
            if one.isdir
                continue;
            end
            [~, ~, ext] = fileparts(one.name);
            if any(strcmpi(ext, exts))
                names{end + 1} = one.name; %#ok<AGROW>
            end
        end

        if isempty(names)
            return;
        end
        fileList = unique(names, 'stable');
    end

    function onFoundationSourceChanged(~, ~)
        app = getappdata(fig, 'app');
        if ~app.loaded || isempty(app.files)
            return;
        end
        if ~isFoundationTabSelected(tabRight, tabFoundation)
            return;
        end
        % Source selection should immediately refresh foundation plots.
        plotFoundationPage(app, false, true);
    end

    function onPlot(~, ~)
        app = getappdata(fig, 'app');
        if ~app.loaded || isempty(app.files)
            showAlertCompat(fig, 'Please load data first.', 'Tip');
            return;
        end

        keepExisting = logical(get(btnHold, 'Value'));
        if isFoundationTabSelected(tabRight, tabFoundation)
            plotFoundationPage(app, keepExisting, false);
            return;
        end

        selectedSeries = getSelectedSeries(app.series, getSelectedListLabels(lstData));
        if isempty(selectedSeries)
            showAlertCompat(fig, 'Please select at least one data entry (File+Channel).', 'Tip');
            return;
        end

        [timeWindow, rangeErr] = parseTimeRangeInputs(edtTStart, edtTEnd);
        if ~isempty(rangeErr)
            showAlertCompat(fig, rangeErr, 'Time Range Error');
            return;
        end

        psdSourceMode = getPopupSelection(ddPsdSource);
        quantityMode = getQuantityMode(ddQuantity);

        refInput = 1;
        if ~keepExisting
            cla(axMain1); cla(axMain2); cla(axMain3);
        end

        [~, msg1] = renderOneAxis(axMain1, getPopupSelection(ddSel1), selectedSeries, app, refInput, keepExisting, timeWindow, psdSourceMode, quantityMode);
        [~, msg2] = renderOneAxis(axMain2, getPopupSelection(ddSel2), selectedSeries, app, refInput, keepExisting, timeWindow, psdSourceMode, quantityMode);
        [~, msg3] = renderOneAxis(axMain3, getPopupSelection(ddSel3), selectedSeries, app, refInput, keepExisting, timeWindow, psdSourceMode, quantityMode);
        detailMsgs = {};
        if ~isempty(msg1)
            detailMsgs{end + 1} = msg1; %#ok<AGROW>
        end
        if ~isempty(msg2)
            detailMsgs{end + 1} = msg2; %#ok<AGROW>
        end
        if ~isempty(msg3)
            detailMsgs{end + 1} = msg3; %#ok<AGROW>
        end
        detailText = '';
        if ~isempty(detailMsgs)
            detailText = [' | ' strjoin(detailMsgs, '; ')];
        end
        if keepExisting
            set(lblStatus, 'String', sprintf('Status: HOLD ON, appended %d entries%s', numel(selectedSeries), detailText));
        else
            set(lblStatus, 'String', sprintf('Status: plotted %d selected entries%s', numel(selectedSeries), detailText));
        end
    end

    % 将指定轴当前内容复制到单独 Figure，便于保存图片
    function onOpenAxisFigure(sourceAx, fallbackTitle)
        if countLineLikeChildren(sourceAx) == 0
            showAlertCompat(fig, 'Current plot is empty. Please plot data first.', 'Tip');
            return;
        end

        figName = getAxisExportTitle(sourceAx, fallbackTitle);
        cloneAxisToFigure(sourceAx, figName, 'northeast');
        set(lblStatus, 'String', sprintf('Status: opened "%s" in a separate figure', figName));
    end

    function onOpenFoundationVibFigure(~, ~)
        if countLineLikeChildren(axFoundVib) == 0
            showAlertCompat(fig, 'Foundation vibration plot is empty. Please plot data first.', 'Tip');
            return;
        end
        figName = getAxisExportTitle(axFoundVib, 'Floor Vibration');
        cloneAxisToFigure(axFoundVib, figName, 'northwest');
        set(lblStatus, 'String', sprintf('Status: opened "%s" in a separate figure', figName));
    end

    function onOpenFoundationStiffCohFigure(~, ~)
        hasStiff = countLineLikeChildren(axFoundStiff) > 0;
        hasCoh = countLineLikeChildren(axFoundCoh) > 0;
        if ~hasStiff && ~hasCoh
            showAlertCompat(fig, 'Foundation stiffness/coherence plots are empty. Please plot data first.', 'Tip');
            return;
        end
        cloneTwoAxesToFigure(axFoundStiff, axFoundCoh, 'Dynamic Stiffness + Coherence', 'northwest');
        set(lblStatus, 'String', 'Status: opened foundation stiffness/coherence in one figure');
    end

    % 在重命名输入框按回车时触发重命名
    function onRenameEdited(~, ~)
        renameSelectedFromField(false);
    end

    % 用输入框内容重命名当前选中数据项（支持提示控制）
    function renameSelectedFromField(showSelectionTips)
        app = getappdata(fig, 'app');
        selectedSeries = getSelectedSeries(app.series, getSelectedListLabels(lstData));
        if isempty(selectedSeries)
            if showSelectionTips
                showAlertCompat(fig, 'Please select one data item to rename.', 'Tip');
            end
            return;
        end
        if numel(selectedSeries) ~= 1
            if showSelectionTips
                showAlertCompat(fig, 'Please select only one data item when renaming.', 'Tip');
            end
            return;
        end

        S = selectedSeries{1};
        newLabel = strtrim(get(edtRename, 'String'));
        if isempty(newLabel)
            if showSelectionTips
                showAlertCompat(fig, 'Please type the new name in the Rename box first.', 'Tip');
            end
            return;
        end
        if strcmp(newLabel, S.label)
            return;
        end

        seriesFileId = getSeriesFileId(S, app);
        if ~isfinite(seriesFileId)
            showAlertCompat(fig, 'Cannot resolve the selected data item. Please reload the file and try again.', 'Rename failed');
            return;
        end
        app = setCustomSeriesLabel(app, seriesFileId, S.ch, newLabel);
        app = rebuildSeriesList(app);
        setappdata(fig, 'app', app);
        renamedLabel = findSeriesLabel(app.series, seriesFileId, S.ch, S.label);
        refreshLoadedFilesList({renamedLabel});
        set(edtRename, 'String', renamedLabel);
        set(lblStatus, 'String', sprintf('Status: renamed "%s" to "%s"', S.label, renamedLabel));
    end

    % 更新当前选中数据项的时域幅值缩放因子（Factor）
    function onScaleEdited(~, ~)
        app = getappdata(fig, 'app');
        selectedSeries = getSelectedSeries(app.series, getSelectedListLabels(lstData));
        if ~isscalar(selectedSeries)
            return;
        end

        scaleValue = str2double(get(edtScale, 'String'));
        if ~isfinite(scaleValue)
            set(edtScale, 'String', num2str(getSeriesScale(app, selectedSeries{1})));
            showAlertCompat(fig, 'Factor must be a valid number.', 'Tip');
            return;
        end

        S = selectedSeries{1};
        seriesFileId = getSeriesFileId(S, app);
        if ~isfinite(seriesFileId)
            return;
        end
        app = setCustomSeriesScale(app, seriesFileId, S.ch, scaleValue);
        setappdata(fig, 'app', app);
        set(lblStatus, 'String', sprintf('Status: updated factor of "%s" to %g', S.label, scaleValue));
    end

    % 列表选择变化时，同步刷新 Rename/Factor 输入框显示
    function onDataSelectionChanged(~, ~)
        app = getappdata(fig, 'app');
        selectedSeries = getSelectedSeries(app.series, getSelectedListLabels(lstData));
        if isscalar(selectedSeries)
            set(edtRename, 'String', selectedSeries{1}.label);
            set(edtScale, 'String', num2str(getSeriesScale(app, selectedSeries{1})));
        else
            set(edtRename, 'String', '');
            set(edtScale, 'String', '1');
        end
    end

    % 按 mode 在指定坐标轴上绘图（Time/PSD/Trans）
    function [usedRef, statusMsg] = renderOneAxis(ax, mode, selectedSeries, app, refInput, keepExisting, timeWindow, psdSourceMode, quantityMode)
        usedRef = NaN;
        statusMsg = '';
        styleAxisCompat(ax);
        switch mode
            case 'Time'
                set(ax, 'XScale', 'linear', 'YScale', 'linear');
                set(ax, 'XLimMode', 'auto', 'YLimMode', 'auto');
                hold(ax, 'on');
                anyTime = false;
                [quantityName, timeYLabel] = getTimeQuantityLabel(quantityMode);
                colorIdx = countLineLikeChildren(ax) + 1;
                xMin = inf;
                xMax = -inf;
                yMin = inf;
                yMax = -inf;
                for si = 1:numel(selectedSeries)
                    S = selectedSeries{si};
                    F = app.files{S.fileIdx};
                    yRaw = safeCellGet(F.rawByCh, S.ch);
                    if isempty(yRaw)
                        continue;
                    end
                    yDraw = applyFilterToSignal( ...
                        yRaw, F.fs, logical(get(chkLow, 'Value')), getNumericControlValue(edtLowCutoff, 100), ...
                        logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5), getNumericControlValue(edtOrder, 4));
                    yDraw = yDraw * getSeriesScale(app, S);
                    N = min(numel(F.t), numel(yDraw));
                    if N < 2
                        continue;
                    end
                    [tSeg, yAccSeg] = applyTimeWindow(F.t(1:N), yDraw(1:N), timeWindow);
                    if numel(tSeg) < 2
                        continue;
                    end
                    ySeg = convertAccelerationTimeSeries( ...
                        yAccSeg, F.fs, quantityMode, ...
                        logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5));
                    if numel(ySeg) ~= numel(tSeg) || numel(ySeg) < 2
                        continue;
                    end
                    safePlot(ax, tSeg, ySeg, 'LineWidth', 1.1, ...
                        'Color', getSeriesColor(colorIdx), 'DisplayName', S.label);
                    anyTime = true;
                    colorIdx = colorIdx + 1;
                    xMin = min(xMin, tSeg(1));
                    xMax = max(xMax, tSeg(end));
                    yMin = min(yMin, min(ySeg));
                    yMax = max(yMax, max(ySeg));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, 'Time (s)');
                ylabel(ax, timeYLabel);
                if anyTime
                    title(ax, sprintf('Time Domain - %s (%d entries)', quantityName, numel(selectedSeries)));
                    legend(ax, 'show', 'Location', 'northeast');
                    if ~keepExisting && isfinite(xMin) && isfinite(xMax) && xMax > xMin
                        xlim(ax, [xMin, xMax]);
                    end
                    if ~keepExisting && isfinite(yMin) && isfinite(yMax)
                        if yMax <= yMin
                            ylim(ax, [yMin - 1, yMin + 1]);
                        else
                            ylim(ax, [yMin, yMax]);
                        end
                    end
                else
                    title(ax, sprintf('Time Domain - %s (no valid data)', quantityName));
                    legend(ax, 'off');
                end

            case 'PSD'
                set(ax, 'XScale', 'log', 'YScale', 'log', 'YLimMode', 'auto');
                hold(ax, 'on');
                anyPsd = false;
                usePeriodogramFromTime = isPeriodogramSource(psdSourceMode);
                [quantityName, psdYLabel] = getPsdQuantityLabel(quantityMode);
                colorIdx = countLineLikeChildren(ax) + 1;
                xMin = inf; xMax = -inf; yMin = inf; yMax = -inf;
                for si = 1:numel(selectedSeries)
                    S = selectedSeries{si};
                    F = app.files{S.fileIdx};
                    if usePeriodogramFromTime
                        yRaw = safeCellGet(F.rawByCh, S.ch);
                        if isempty(yRaw)
                            continue;
                        end
                        yProc = applyFilterToSignal( ...
                            yRaw, F.fs, logical(get(chkLow, 'Value')), getNumericControlValue(edtLowCutoff, 100), ...
                            logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5), getNumericControlValue(edtOrder, 4));
                        N = min(numel(F.t), numel(yProc));
                        if N < 2
                            continue;
                        end
                        [~, ySeg] = applyTimeWindow(F.t(1:N), yProc(1:N), timeWindow);
                        if numel(ySeg) < 2
                            continue;
                        end
                        [f, psdAcc] = computePeriodogramPsd(ySeg, F.fs);
                    else
                        [f, psdAcc] = getPsdForChannel(F, S.ch);
                    end
                    if isempty(f)
                        continue;
                    end
                    [f, psd] = convertAccelerationPsd( ...
                        f, psdAcc, quantityMode, ...
                        logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5));
                    if isempty(f)
                        continue;
                    end
                    safeLoglog(ax, f, psd, 'LineWidth', 1.1, ...
                        'Color', getSeriesColor(colorIdx), 'DisplayName', S.label);
                    anyPsd = true;
                    colorIdx = colorIdx + 1;
                    xMin = min(xMin, f(1)); xMax = max(xMax, f(end));
                    yMin = min(yMin, min(psd)); yMax = max(yMax, max(psd));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, 'Frequency (Hz)');
                ylabel(ax, psdYLabel);
                if anyPsd
                    if usePeriodogramFromTime
                        title(ax, sprintf('PSD - %s (periodogram, log-log, %d entries)', quantityName, numel(selectedSeries)));
                    else
                        title(ax, sprintf('PSD - %s (VNA/native, log-log, %d entries)', quantityName, numel(selectedSeries)));
                    end
                    legend(ax, 'show', 'Location', 'northeast');
                    if ~keepExisting && isfinite(xMin) && isfinite(xMax) && xMax > xMin
                        xlim(ax, [xMin, xMax]);
                    end
                    if ~keepExisting && isfinite(yMin) && isfinite(yMax) && yMin > 0
                        if yMax <= yMin
                            ylim(ax, [yMin * 0.9, yMin * 1.1]);
                        else
                            ylim(ax, [yMin, yMax]);
                        end
                    end
                else
                    title(ax, sprintf('PSD - %s (no valid data)', quantityName));
                    legend(ax, 'off');
                end

            case 'CumPSD'
                set(ax, 'XScale', 'log', 'YScale', 'linear', 'YLimMode', 'auto');
                hold(ax, 'on');
                anyCum = false;
                usePeriodogramFromTime = isPeriodogramSource(psdSourceMode);
                [quantityName, cumYLabel] = getCumPsdLabel(quantityMode);
                colorIdx = countLineLikeChildren(ax) + 1;
                xMin = inf; xMax = -inf; yMin = inf; yMax = -inf;
                for si = 1:numel(selectedSeries)
                    S = selectedSeries{si};
                    F = app.files{S.fileIdx};
                    if usePeriodogramFromTime
                        yRaw = safeCellGet(F.rawByCh, S.ch);
                        if isempty(yRaw)
                            continue;
                        end
                        yProc = applyFilterToSignal( ...
                            yRaw, F.fs, logical(get(chkLow, 'Value')), getNumericControlValue(edtLowCutoff, 100), ...
                            logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5), getNumericControlValue(edtOrder, 4));
                        N = min(numel(F.t), numel(yProc));
                        if N < 2
                            continue;
                        end
                        [~, ySeg] = applyTimeWindow(F.t(1:N), yProc(1:N), timeWindow);
                        if numel(ySeg) < 2
                            continue;
                        end
                        [f, psdAcc] = computePeriodogramPsd(ySeg, F.fs);
                    else
                        [f, psdAcc] = getPsdForChannel(F, S.ch);
                    end
                    if isempty(f)
                        continue;
                    end
                    [f, psd] = convertAccelerationPsd( ...
                        f, psdAcc, quantityMode, ...
                        logical(get(chkHigh, 'Value')), getNumericControlValue(edtHighCutoff, 5));
                    if isempty(f)
                        continue;
                    end
                    [fCum, yCum] = computeCumulativeSpectrum(f, psd);
                    if isempty(fCum)
                        continue;
                    end
                    safeSemilogx(ax, fCum, yCum, 'LineWidth', 1.1, ...
                        'Color', getSeriesColor(colorIdx), 'DisplayName', S.label);
                    anyCum = true;
                    colorIdx = colorIdx + 1;
                    xMin = min(xMin, fCum(1)); xMax = max(xMax, fCum(end));
                    yMin = min(yMin, min(yCum)); yMax = max(yMax, max(yCum));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, 'Frequency (Hz)');
                ylabel(ax, cumYLabel);
                if anyCum
                    if usePeriodogramFromTime
                        title(ax, sprintf('CumPSD - %s (periodogram, %d entries)', quantityName, numel(selectedSeries)));
                    else
                        title(ax, sprintf('CumPSD - %s (VNA/native, %d entries)', quantityName, numel(selectedSeries)));
                    end
                    legend(ax, 'show', 'Location', 'northeast');
                    if ~keepExisting && isfinite(xMin) && isfinite(xMax) && xMax > xMin
                        xlim(ax, [xMin, xMax]);
                    end
                    if ~keepExisting && isfinite(yMin) && isfinite(yMax)
                        if yMax <= yMin
                            ylim(ax, [max(0, yMin - 1), yMin + 1]);
                        else
                            ylim(ax, [max(0, yMin), yMax]);
                        end
                    end
                else
                    title(ax, sprintf('CumPSD - %s (no valid data)', quantityName));
                    legend(ax, 'off');
                end

            case 'Trans'
                set(ax, 'XScale', 'log', 'YScale', 'linear', 'YLimMode', 'auto');
                hold(ax, 'on');
                anyTr = false;
                colorIdx = countLineLikeChildren(ax) + 1;
                xMin = inf; xMax = -inf; yMin = inf; yMax = -inf;
                usedRef = 1;
                skippedSelfCount = 0;
                skippedMissingCount = 0;
                for si = 1:numel(selectedSeries)
                    S = selectedSeries{si};
                    F = app.files{S.fileIdx};
                    if ~F.vna.available
                        skippedMissingCount = skippedMissingCount + 1;
                        continue;
                    end
                    refCh = 1;
                    if S.ch == refCh
                        skippedSelfCount = skippedSelfCount + 1;
                        continue;
                    end
                    [f, trDb] = getTransRatio(F, S.ch, refCh);
                    if isempty(f)
                        skippedMissingCount = skippedMissingCount + 1;
                        continue;
                    end
                    safeSemilogx(ax, f, trDb, 'LineWidth', 1.1, ...
                        'Color', getSeriesColor(colorIdx), ...
                        'DisplayName', S.label);
                    anyTr = true;
                    colorIdx = colorIdx + 1;
                    xMin = min(xMin, f(1)); xMax = max(xMax, f(end));
                    yMin = min(yMin, min(trDb)); yMax = max(yMax, max(trDb));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, 'Frequency (Hz)');
                ylabel(ax, 'dB');
                if anyTr
                    title(ax, 'Transmissibility (dB)');
                    legend(ax, 'show', 'Location', 'northeast');
                    if ~keepExisting && isfinite(xMin) && isfinite(xMax) && xMax > xMin
                        xlim(ax, [xMin, xMax]);
                    end
                    if ~keepExisting && isfinite(yMin) && isfinite(yMax)
                        if yMax <= yMin
                            ylim(ax, [yMin - 1, yMin + 1]);
                        else
                            ylim(ax, [yMin, yMax]);
                        end
                    end
                else
                    title(ax, 'Transmissibility (no valid data)');
                    legend(ax, 'off');
                end
                if skippedSelfCount > 0 || skippedMissingCount > 0
                    statusMsg = sprintf('Trans skipped self:%d, missing-xfer:%d', skippedSelfCount, skippedMissingCount);
                end

            case 'Coherence'
                set(ax, 'XScale', 'log', 'YScale', 'linear', 'YLimMode', 'auto');
                hold(ax, 'on');
                anyCoh = false;
                colorIdx = countLineLikeChildren(ax) + 1;
                xMin = inf; xMax = -inf;
                usedRef = refInput;
                for si = 1:numel(selectedSeries)
                    S = selectedSeries{si};
                    F = app.files{S.fileIdx};
                    if ~F.vna.available
                        continue;
                    end
                    refCh = chooseNearestValid(refInput, F.validChannels);
                    usedRef = refCh;
                    if S.ch == refCh || ~ismember(S.ch, F.validChannels)
                        continue;
                    end
                    [f, coh] = getCoherenceRatio(F, S.ch, refCh);
                    if isempty(f)
                        continue;
                    end
                    safeSemilogx(ax, f, coh, 'LineWidth', 1.1, ...
                        'Color', getSeriesColor(colorIdx), ...
                        'DisplayName', S.label);
                    anyCoh = true;
                    colorIdx = colorIdx + 1;
                    xMin = min(xMin, f(1)); xMax = max(xMax, f(end));
                end
                hold(ax, 'off');
                grid(ax, 'on');
                xlabel(ax, 'Frequency (Hz)');
                ylabel(ax, 'Coherence');
                if anyCoh
                    title(ax, sprintf('Coherence (%d entries)', numel(selectedSeries)));
                    legend(ax, 'show', 'Location', 'northeast');
                    if ~keepExisting && isfinite(xMin) && isfinite(xMax) && xMax > xMin
                        xlim(ax, [xMin, xMax]);
                    end
                    if ~keepExisting
                        ylim(ax, [0, 1]);
                    end
                else
                    title(ax, 'Coherence (no valid data)');
                    legend(ax, 'off');
                    if ~keepExisting
                        ylim(ax, [0, 1]);
                    end
                end

            otherwise
                title(ax, 'Unknown mode');
                legend(ax, 'off');
        end
    end

    % Hold 开关：控制 Plot 时是追加还是覆盖
    function onHoldChanged(~, ~)
        if get(btnHold, 'Value')
            set(lblStatus, 'String', 'Status: Hold ON (next Plot will append)');
        else
            set(lblStatus, 'String', 'Status: Hold OFF (next Plot will replace)');
        end
    end

    % 重置滤波器开关（低通/高通关闭）
    function onResetFilter(~, ~)
        set(chkLow, 'Value', 0);
        set(chkHigh, 'Value', 0);
        set(lblStatus, 'String', 'Status: filter reset to None');
    end

    % 清空三幅图，并按当前图类型恢复空图状态
    function onClearPlots(~, ~)
        cla(axMain1); cla(axMain2); cla(axMain3);
        cla(axFoundVib); cla(axFoundStiff); cla(axFoundCoh);
        legend(axMain1, 'off'); legend(axMain2, 'off'); legend(axMain3, 'off');
        legend(axFoundVib, 'off'); legend(axFoundStiff, 'off'); legend(axFoundCoh, 'off');
        renderOneAxis(axMain1, getPopupSelection(ddSel1), {}, getappdata(fig, 'app'), 1, false, [NaN NaN], getPopupSelection(ddPsdSource), getQuantityMode(ddQuantity));
        renderOneAxis(axMain2, getPopupSelection(ddSel2), {}, getappdata(fig, 'app'), 1, false, [NaN NaN], getPopupSelection(ddPsdSource), getQuantityMode(ddQuantity));
        renderOneAxis(axMain3, getPopupSelection(ddSel3), {}, getappdata(fig, 'app'), 1, false, [NaN NaN], getPopupSelection(ddPsdSource), getQuantityMode(ddQuantity));
        set(lblStatus, 'String', 'Status: plots cleared');
    end

    % 删除选中的数据项（会从对应文件有效通道中移除）
    function onDeleteSelectedFiles(~, ~)
        app = getappdata(fig, 'app');
        if isempty(app.series)
            return;
        end

        selectedSeries = getSelectedSeries(app.series, getSelectedListLabels(lstData));
        if isempty(selectedSeries)
            showAlertCompat(fig, 'Please select data item(s) to delete in list.', 'Tip');
            return;
        end

        removed = numel(selectedSeries);

        % Remove selected channels from source files so deletion persists.
        removeByFile = cell(1, numel(app.files));
        for i = 1:numel(selectedSeries)
            S = selectedSeries{i};
            removeByFile{S.fileIdx}(end + 1) = S.ch;
        end

        for fi = 1:numel(app.files)
            if isempty(removeByFile{fi})
                continue;
            end
            F = app.files{fi};
            rmCh = unique(removeByFile{fi}, 'stable');
            F.validChannels = setdiff(F.validChannels, rmCh, 'stable');
            app.files{fi} = F;
        end

        keepFile = true(1, numel(app.files));
        for fi = 1:numel(app.files)
            if isempty(app.files{fi}.validChannels)
                keepFile(fi) = false;
            end
        end
        app.files = app.files(keepFile);

        if isempty(app.files)
            app.loaded = false;
            app.validChannels = 1;
            app.series = {};
            set(edtFile, 'String', 'No file loaded');
        else
            app.loaded = true;
            app.validChannels = collectValidChannels(app.files);
            app.fs = app.files{end}.fs;
            setNumericControlValue(edtFs, app.fs);
            app = rebuildSeriesList(app);
            set(edtFile, 'String', summarizeLoadedFiles(app.files));
        end

        setappdata(fig, 'app', app);
        refreshLoadedFilesList();
        refreshFoundationFileSelectors();
        cla(axFoundVib); cla(axFoundStiff); cla(axFoundCoh);
        set(lblStatus, 'String', sprintf('Status: deleted %d entries, remaining %d', removed, numel(app.series)));
    end

    % 刷新左侧数据项列表，并尽量保留原选择
    function refreshLoadedFilesList(selectedLabels)
        if nargin < 1
            selectedLabels = {};
        end
        app = getappdata(fig, 'app');
        if isempty(app.series)
            set(lstData, 'String', {' '}, 'Value', 1);
            set(edtRename, 'String', '');
            return;
        end

        n = numel(app.series);
        items = cell(1, n);
        for i = 1:n
            items{i} = app.series{i}.label;
        end
        set(lstData, 'String', items);
        setListSelectionByLabels(lstData, items, selectedLabels);
        onDataSelectionChanged();
    end

    % Refresh Vib/Stiff source file dropdowns in Foundation tab.
    function refreshFoundationFileSelectors(preferredVibId, preferredStiffId)
        if nargin < 1
            preferredVibId = NaN;
        end
        if nargin < 2
            preferredStiffId = NaN;
        end

        app = getappdata(fig, 'app');
        currentVibId = getPopupSelectedFileIdCompat(ddVibFile);
        currentStiffId = getPopupSelectedFileIdCompat(ddStiffFile);
        if ~isfinite(preferredVibId)
            preferredVibId = currentVibId;
        end
        if ~isfinite(preferredStiffId)
            preferredStiffId = currentStiffId;
        end

        if isempty(app.files)
            set(ddVibFile, 'String', {'(none)'}, 'Value', 1, 'Enable', 'off', 'UserData', NaN);
            set(ddStiffFile, 'String', {'(none)'}, 'Value', 1, 'Enable', 'off', 'UserData', NaN);
            return;
        end

        n = numel(app.files);
        items = cell(1, n + 1);
        ids = nan(1, n + 1);
        items{1} = '(none)';
        ids(1) = NaN;
        for i = 1:n
            F = app.files{i};
            ids(i + 1) = F.id;
            items{i + 1} = sprintf('%s [id:%d]', getSeriesDisplayFileName(F.fileName), F.id);
        end

        vibIdx = find(ids == preferredVibId, 1, 'first');
        vibFallback = false;
        if isempty(vibIdx)
            vibIdx = 1;
            vibFallback = isfinite(preferredVibId);
        end
        stiffIdx = find(ids == preferredStiffId, 1, 'first');
        stiffFallback = false;
        if isempty(stiffIdx)
            stiffIdx = 1;
            stiffFallback = isfinite(preferredStiffId);
        end

        set(ddVibFile, 'String', items, 'Value', vibIdx, 'Enable', 'on', 'UserData', ids);
        set(ddStiffFile, 'String', items, 'Value', stiffIdx, 'Enable', 'on', 'UserData', ids);
        if vibFallback || stiffFallback
            set(lblStatus, 'String', 'Status: foundation source file selection reset to (none)');
        end
    end

    function fileId = getPopupSelectedFileIdCompat(h)
        fileId = NaN;
        try
            ids = get(h, 'UserData');
            idx = get(h, 'Value');
            if isnumeric(ids) && ~isempty(ids) && idx >= 1 && idx <= numel(ids)
                oneId = ids(idx);
                if isfinite(oneId)
                    fileId = oneId;
                end
            end
        catch
        end
    end

    function tf = isFoundationTabSelected(tabGroup, foundationTab)
        tf = false;
        try
            tf = isequal(get(tabGroup, 'SelectedTab'), foundationTab);
        catch
            tf = false;
        end
    end

    function plotFoundationPage(app, keepExisting, silentNoSource)
        if nargin < 3
            silentNoSource = false;
        end
        vibFileId = getPopupSelectedFileIdCompat(ddVibFile);
        stiffFileId = getPopupSelectedFileIdCompat(ddStiffFile);
        if ~isfinite(vibFileId) && ~isfinite(stiffFileId)
            if ~silentNoSource
                showAlertCompat(fig, 'Please select Vib File or Stiff File first.', 'Tip');
            end
            set(lblStatus, 'String', 'Status: foundation source is empty');
            return;
        end

        [vibChannels, vibErr] = parseChannelListStringNamed(get(edtVibCh, 'String'), 'Vib Ch');
        if ~isempty(vibErr)
            showAlertCompat(fig, vibErr, 'Foundation Setting Error');
            return;
        end
        exciteCh = 1;
        [respChannels, respErr] = parseChannelListStringNamed(get(edtRespCh, 'String'), 'Stiff Ch');
        if ~isempty(respErr)
            showAlertCompat(fig, respErr, 'Foundation Setting Error');
            return;
        end

        if ~keepExisting
            cla(axFoundVib);
            cla(axFoundStiff);
            cla(axFoundCoh);
        end

        vcFlags = struct( ...
            'A', logical(get(chkVCA, 'Value')), ...
            'B', logical(get(chkVCB, 'Value')), ...
            'C', logical(get(chkVCC, 'Value')), ...
            'D', logical(get(chkVCD, 'Value')));

        [Fvib, okVib] = getFileById(app.files, vibFileId);
        [Fstiff, okStiff] = getFileById(app.files, stiffFileId);
        msgParts = {};

        if okVib
            [ok, msg] = renderFoundationVibrationAxis(axFoundVib, Fvib, vibChannels, vcFlags, keepExisting);
            if ok
                msgParts{end + 1} = sprintf('vib:%s', Fvib.fileName); %#ok<AGROW>
            elseif ~isempty(msg)
                msgParts{end + 1} = ['vib skipped (' msg ')']; %#ok<AGROW>
            end
        else
            msgParts{end + 1} = 'vib file unavailable'; %#ok<AGROW>
        end

        if okStiff
            [ok, msg] = renderFoundationStiffnessAxis(axFoundStiff, Fstiff, exciteCh, respChannels, keepExisting);
            if ok
                if isempty(msg)
                    msgParts{end + 1} = sprintf('stiff:%s', Fstiff.fileName); %#ok<AGROW>
                else
                    msgParts{end + 1} = sprintf('stiff:%s (%s)', Fstiff.fileName, msg); %#ok<AGROW>
                end
            elseif ~isempty(msg)
                msgParts{end + 1} = ['stiff skipped (' msg ')']; %#ok<AGROW>
            end

            [ok, msg] = renderFoundationCoherenceAxis(axFoundCoh, Fstiff, exciteCh, respChannels, keepExisting);
            if ok
                if isempty(msg)
                    msgParts{end + 1} = sprintf('coh:%s', Fstiff.fileName); %#ok<AGROW>
                else
                    msgParts{end + 1} = sprintf('coh:%s (%s)', Fstiff.fileName, msg); %#ok<AGROW>
                end
            elseif ~isempty(msg)
                msgParts{end + 1} = ['coh skipped (' msg ')']; %#ok<AGROW>
            end
        else
            msgParts{end + 1} = 'stiff file unavailable'; %#ok<AGROW>
            msgParts{end + 1} = 'coh file unavailable'; %#ok<AGROW>
        end

        if isempty(msgParts)
            set(lblStatus, 'String', 'Status: foundation plot skipped');
        else
            set(lblStatus, 'String', ['Status: foundation plotted | ' strjoin(msgParts, ', ')]);
        end
    end
end

% 创建应用状态结构体（集中保存 UI 和数据处理状态）
function app = initAppState()
app.loaded = false;
app.filePath = '';
app.t = [];
app.fs = [];
app.validChannels = 1;
app.rawByCh = {[]};
app.fileName = '';
app.files = {};
app.nextFileId = 1;
app.series = {};
app.customSeriesNames = {};
app.customSeriesScales = {};
app.vna = struct( ...
    'available', false, ...
    'nCh', 1, ...
    'freq', [], ...
    'aspec', {{}}, ...
    'eu', 1, ...
    'wincor', 1, ...
    'rbw', 1, ...
    'xcmeas', []);
end

% 按文件扩展名读取数据并统一转成内部数据结构
function D = readVibrationFile(fileName, fsHint)
[~, ~, ext] = fileparts(fileName);
ext = lower(ext);
D = initAppState();

switch ext
    case {'.vna', '.mat'}
        S = load(fileName, '-mat');
        D = parseVnaLikeStruct(S, fsHint, D);
    case {'.txt', '.dat', '.csv', '.xlsx'}
        X = readMatrixCompat(fileName);
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

% 解析 .vna/.mat 中的 SLm 结构，提取时域与频域数据
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
    'rbw', 1, ...
    'xcmeas', []);

if isfield(slm, 'fdxvec') && ~isempty(slm.fdxvec)
    vna.freq = slm.fdxvec(:);
end
if isfield(slm, 'wincor') && isfinite(slm.wincor)
    vna.wincor = slm.wincor;
end
if isfield(slm, 'rbw') && isfinite(slm.rbw) && slm.rbw > 0
    vna.rbw = slm.rbw;
end
if isfield(slm, 'xcmeas') && ~isempty(slm.xcmeas)
    vna.xcmeas = slm.xcmeas;
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

% 对时域信号应用低通/高通滤波（支持单独或同时使用）
function yDraw = applyFilterToSignal(yRaw, fs, useLow, lowCutoff, useHigh, highCutoff, order)
yDraw = yRaw(:);
if isempty(yDraw) || ~isfinite(fs) || fs <= 0
    return;
end

order = max(1, round(order));
nyquist = fs / 2;

if useLow && useHigh && isfinite(lowCutoff) && isfinite(highCutoff) && highCutoff >= lowCutoff
    return;
end

try
    if useHigh && isfinite(highCutoff) && highCutoff > 0 && highCutoff < nyquist
        wnHigh = highCutoff / nyquist;
        [bHigh, aHigh] = butter(order, wnHigh, 'high');
        yDraw = filtfilt(bHigh, aHigh, yDraw);
    end

    if useLow && isfinite(lowCutoff) && lowCutoff > 0 && lowCutoff < nyquist
        wnLow = lowCutoff / nyquist;
        [bLow, aLow] = butter(order, wnLow, 'low');
        yDraw = filtfilt(bLow, aLow, yDraw);
    end
catch
    % If filtering fails (short signal, unstable coefficients), keep raw signal.
    yDraw = yRaw(:);
end
end

% 获取某通道 PSD（优先使用文件内频谱，否则回退 FFT）
function [f, psd] = getPsdForChannel(F, ch)
f = [];
psd = [];
if F.vna.available && ch >= 1 && ch <= F.vna.nCh
    a = safeCellGet(F.vna.aspec, ch);
    if ~isempty(a) && ~isempty(F.vna.freq) && isfinite(F.vna.rbw) && F.vna.rbw > 0
        M = min(numel(F.vna.freq), numel(a));
        f0 = F.vna.freq(1:M);
        eu = safeGet(F.vna.eu, ch, 1);
        p0 = F.vna.wincor * a(1:M) * (eu^2) / F.vna.rbw;
        valid = isfinite(f0) & isfinite(p0) & (f0 > 0) & (p0 > 0);
        f = f0(valid);
        psd = p0(valid);
        return;
    end
end

y = safeCellGet(F.rawByCh, ch);
if isempty(y)
    return;
end
[f, psd] = singleSideSpectrum(y, F.fs);
valid = isfinite(f) & isfinite(psd) & (f >= 0) & (psd >= 0);
f = f(valid);
psd = psd(valid);
end

% 计算传递率（通道/参考通道）并转换为 dB
function [f, trDb] = getTransRatio(F, ch, refCh)
f = [];
trDb = [];
if ~F.vna.available
    return;
end
if ch < 1 || ch > F.vna.nCh || refCh < 1 || refCh > F.vna.nCh
    return;
end
if ~isfield(F.vna, 'xcmeas') || isempty(F.vna.xcmeas) || isempty(F.vna.freq)
    return;
end
xc = F.vna.xcmeas;
sz = size(xc);
if numel(sz) < 2 || refCh > sz(1) || ch > sz(2)
    return;
end
if ~isstruct(xc(refCh, ch)) || ~isfield(xc(refCh, ch), 'xfer') || isempty(xc(refCh, ch).xfer)
    return;
end
xfer = xc(refCh, ch).xfer(:);
M = min(numel(F.vna.freq), numel(xfer));
if M < 3
    return;
end
f0 = F.vna.freq(2:M);
x = xfer(2:M);
euK = safeGet(F.vna.eu, ch, 1);
euR = safeGet(F.vna.eu, refCh, 1);
if ~isfinite(euR) || euR == 0
    return;
end
xferCorr = x .* (euK / euR);
trLin = abs(xferCorr);
valid = isfinite(f0) & isfinite(trLin) & (f0 > 0) & (trLin > 0);
f = f0(valid);
trDb = 20 * log10(trLin(valid));
end

function [f, coh] = getCoherenceRatio(F, ch, refCh)
f = [];
coh = [];
if ~F.vna.available
    return;
end
if ch < 1 || ch > F.vna.nCh || refCh < 1 || refCh > F.vna.nCh
    return;
end
if ~isfield(F.vna, 'xcmeas') || isempty(F.vna.xcmeas)
    return;
end

xc = F.vna.xcmeas;
sz = size(xc);
if numel(sz) < 2 || refCh > sz(1) || ch > sz(2)
    return;
end
if ~isstruct(xc(refCh, ch)) || ~isfield(xc(refCh, ch), 'coh') || isempty(xc(refCh, ch).coh)
    return;
end

c0 = xc(refCh, ch).coh(:);
M = min(numel(F.vna.freq), numel(c0));
if M < 3
    return;
end
f0 = F.vna.freq(2:M);
c0 = c0(2:M);
valid = isfinite(f0) & isfinite(c0) & (f0 > 0);
f = f0(valid);
coh = c0(valid);
end

% 解析通用数值矩阵文件（时间列/数据列）并推断采样率
% Parse time range inputs. Empty value means open-ended boundary.
function [F, ok] = getFileById(files, fileId)
F = [];
ok = false;
if ~isfinite(fileId) || isempty(files)
    return;
end
for i = 1:numel(files)
    one = files{i};
    if isfield(one, 'id') && isfinite(one.id) && one.id == fileId
        F = one;
        ok = true;
        return;
    end
end
end

function [channels, errMsg] = parseChannelListString(raw)
channels = [];
errMsg = '';

if iscell(raw)
    if isempty(raw)
        raw = '';
    else
        raw = raw{1};
    end
end
if isempty(raw)
    errMsg = 'Vib Ch cannot be empty. Example: 2,3,4';
    return;
end
if ~ischar(raw)
    errMsg = 'Vib Ch must be text like 2,3,4.';
    return;
end

txt = strtrim(strrep(raw, '，', ','));
if isempty(txt)
    errMsg = 'Vib Ch cannot be empty. Example: 2,3,4';
    return;
end

parts = regexp(txt, '[,\s;]+', 'split');
vals = zeros(1, numel(parts));
k = 0;
for i = 1:numel(parts)
    p = strtrim(parts{i});
    if isempty(p)
        continue;
    end
    v = str2double(p);
    if ~isfinite(v) || v < 1 || abs(v - round(v)) > 1e-9
        errMsg = sprintf('Invalid channel token: %s', p);
        return;
    end
    k = k + 1;
    vals(k) = round(v);
end
vals = vals(1:k);
if isempty(vals)
    errMsg = 'Vib Ch cannot be empty. Example: 2,3,4';
    return;
end
channels = unique(vals, 'stable');
end

function [channels, errMsg] = parseChannelListStringNamed(raw, fieldName)
[channels, errMsg] = parseChannelListString(raw);
if nargin < 2 || isempty(fieldName) || isempty(errMsg)
    return;
end
if ~ischar(fieldName)
    return;
end
errMsg = strrep(errMsg, 'Vib Ch', fieldName);
errMsg = strrep(errMsg, 'channel token', [fieldName ' token']);
end

function [value, errMsg] = parsePositiveIntString(raw, fieldName)
value = NaN;
errMsg = '';
if iscell(raw)
    if isempty(raw)
        raw = '';
    else
        raw = raw{1};
    end
end
if isempty(raw) || ~ischar(raw)
    errMsg = sprintf('%s must be a positive integer.', fieldName);
    return;
end
v = str2double(strtrim(raw));
if ~isfinite(v) || v < 1 || abs(v - round(v)) > 1e-9
    errMsg = sprintf('%s must be a positive integer.', fieldName);
    return;
end
value = round(v);
end

function [ok, msg] = renderFoundationVibrationAxis(ax, F, vibChannels, vcFlags, keepExisting)
ok = false;
msg = '';
styleAxisCompat(ax);
set(ax, 'XScale', 'log', 'YScale', 'log', 'XLimMode', 'auto', 'YLimMode', 'auto');

if ~isfield(F, 'vna') || ~isfield(F.vna, 'freq') || isempty(F.vna.freq)
    msg = 'missing fdxvec';
    title(ax, 'Floor Vibration (missing fdxvec)');
    return;
end
if ~isfield(F.vna, 'aspec') || isempty(F.vna.aspec)
    msg = 'missing scmeas.aspec';
    title(ax, 'Floor Vibration (missing aspec)');
    return;
end
rbw = F.vna.rbw;
if ~isfinite(rbw) || rbw <= 0
    msg = 'invalid rbw';
    title(ax, 'Floor Vibration (invalid rbw)');
    return;
end

fAll = F.vna.freq(:);
if numel(fAll) >= 2
    fAll = fAll(2:end);
else
    fAll = [];
end
fAll = fAll(isfinite(fAll) & fAll > 0);
if numel(fAll) < 2
    msg = 'not enough positive frequency points';
    title(ax, 'Floor Vibration (insufficient frequency points)');
    return;
end

[fc, fcL, fcU, bandErr] = getThirdOctaveBandsCompat(min(fAll), max(fAll));
if isempty(fc)
    msg = bandErr;
    if isempty(msg)
        msg = 'third-octave bands unavailable';
    end
    title(ax, 'Floor Vibration (third-octave bands unavailable)');
    return;
end

hold(ax, 'on');
colorIdx = countLineLikeChildren(ax) + 1;
anyData = false;
xMin = inf;
xMax = -inf;
yMin = inf;
yMax = -inf;

for i = 1:numel(vibChannels)
    ch = vibChannels(i);
    if ch < 1 || ch > F.vna.nCh
        continue;
    end
    aRaw = safeCellGet(F.vna.aspec, ch);
    if isempty(aRaw)
        continue;
    end
    M = min(numel(F.vna.freq), numel(aRaw));
    if M < 3
        continue;
    end
    f = F.vna.freq(2:M);
    eu = safeGet(F.vna.eu, ch, 1);
    aPsd = aRaw(2:M) * (eu ^ 2) / rbw;
    valid = isfinite(f) & isfinite(aPsd) & (f > 0) & (aPsd > 0);
    f = f(valid);
    aPsd = aPsd(valid);
    if numel(f) < 2
        continue;
    end
    vSpec = aPsd ./ ((2 * pi * f) .^ 2);

    v31 = nan(size(fc));
    for bi = 1:numel(fc)
        idx = (f >= fcL(bi)) & (f <= fcU(bi));
        if any(idx)
            v31(bi) = sqrt(sum(vSpec(idx) * rbw));
        end
    end
    y = v31 * 1e6;
    valid31 = isfinite(fc) & isfinite(y) & (fc > 0) & (y > 0);
    if ~any(valid31)
        continue;
    end
    safeLoglog(ax, fc(valid31), y(valid31), '.-', ...
        'LineWidth', 1.1, ...
        'Color', getSeriesColor(colorIdx), ...
        'DisplayName', getFoundationVibLegendName(ch));
    colorIdx = colorIdx + 1;
    anyData = true;
    xMin = min(xMin, min(fc(valid31)));
    xMax = max(xMax, max(fc(valid31)));
    yMin = min(yMin, min(y(valid31)));
    yMax = max(yMax, max(y(valid31)));
end

fRef = [4 8 80];
if vcFlags.A
    safeLoglog(ax, fRef, [100 50 50], '--', 'LineWidth', 1.5, 'Color', [0.2 0.2 0.2], 'DisplayName', 'VC A');
    xMin = min(xMin, min(fRef)); xMax = max(xMax, max(fRef));
    yMin = min(yMin, min([100 50 50])); yMax = max(yMax, max([100 50 50]));
end
if vcFlags.B
    safeLoglog(ax, fRef, [50 25 25], '--', 'LineWidth', 1.5, 'Color', [0.10 0.40 0.85], 'DisplayName', 'VC B');
    xMin = min(xMin, min(fRef)); xMax = max(xMax, max(fRef));
    yMin = min(yMin, min([50 25 25])); yMax = max(yMax, max([50 25 25]));
end
if vcFlags.C
    safeLoglog(ax, fRef, [12.5 12.5 12.5], '--', 'LineWidth', 1.5, 'Color', [0.85 0.20 0.20], 'DisplayName', 'VC C');
    xMin = min(xMin, min(fRef)); xMax = max(xMax, max(fRef));
    yMin = min(yMin, min([12.5 12.5 12.5])); yMax = max(yMax, max([12.5 12.5 12.5]));
end
if vcFlags.D
    safeLoglog(ax, fRef, [6.25 6.25 6.25], '--', 'LineWidth', 1.5, 'Color', [0.15 0.60 0.20], 'DisplayName', 'VC D');
    xMin = min(xMin, min(fRef)); xMax = max(xMax, max(fRef));
    yMin = min(yMin, min([6.25 6.25 6.25])); yMax = max(yMax, max([6.25 6.25 6.25]));
end

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'One-Third Octave Band Frequency [Hz]');
ylabel(ax, 'RMS Velocity [um/s]');
title(ax, sprintf('Floor Vibration - %s', F.fileName));
legend(ax, 'show', 'Location', 'northwest');

if ~keepExisting
    if isfinite(xMin) && isfinite(xMax) && xMax > xMin
        xlim(ax, [max(eps, xMin * 0.9), xMax * 1.1]);
    end
    if isfinite(yMin) && isfinite(yMax) && yMax > yMin
        ylim(ax, [max(eps, yMin * 0.85), yMax * 1.15]);
    end
end

hasCurve = anyData || vcFlags.A || vcFlags.B || vcFlags.C || vcFlags.D;
if hasCurve
    ok = true;
else
    msg = 'no valid vibration channels/aspec';
end
end

function [ok, msg] = renderFoundationStiffnessAxis(ax, F, exciteCh, respChannels, keepExisting)
ok = false;
msg = '';
styleAxisCompat(ax);
set(ax, 'XScale', 'log', 'YScale', 'log', 'XLimMode', 'auto', 'YLimMode', 'auto');

if ~isfield(F, 'vna') || ~isfield(F.vna, 'freq') || isempty(F.vna.freq)
    msg = 'missing fdxvec';
    title(ax, 'Dynamic Stiffness (missing fdxvec)');
    return;
end
if ~isfield(F.vna, 'xcmeas') || isempty(F.vna.xcmeas)
    msg = 'missing xcmeas';
    title(ax, 'Dynamic Stiffness (missing xcmeas)');
    return;
end

xc = F.vna.xcmeas;
sz = size(xc);
if numel(sz) < 2 || exciteCh < 1 || exciteCh > sz(1)
    msg = sprintf('xcmeas excite index out of range (%d)', exciteCh);
    title(ax, 'Dynamic Stiffness (excite channel out of range)');
    return;
end
if isempty(respChannels)
    msg = 'Stiff Ch is empty';
    title(ax, 'Dynamic Stiffness (empty response channels)');
    return;
end

hold(ax, 'on');
euExc = safeGet(F.vna.eu, exciteCh, 1);
xMin = inf;
xMax = -inf;
yMin = inf;
yMax = -inf;
plottedCount = 0;
skippedResp = [];
for i = 1:numel(respChannels)
    respCh = respChannels(i);
    if respCh < 1 || respCh > sz(2)
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end
    if ~isstruct(xc(exciteCh, respCh)) || ~isfield(xc(exciteCh, respCh), 'xfer') || isempty(xc(exciteCh, respCh).xfer)
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end

    xfer = xc(exciteCh, respCh).xfer(:);
    M = min(numel(F.vna.freq), numel(xfer));
    if M < 3
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end
    f = F.vna.freq(2:M);
    x = xfer(2:M);
    euResp = safeGet(F.vna.eu, respCh, 1);
    resp = 1 ./ (x ./ ((2 * pi * f) .^ 2) * (euResp / euExc));
    kAbs = abs(resp);
    valid = isfinite(f) & isfinite(kAbs) & (f > 0) & (kAbs > 0);
    f = f(valid);
    kAbs = kAbs(valid);
    if numel(f) < 2
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end

    safeLoglog(ax, f, kAbs, 'LineWidth', 1.2, ...
        'Color', getSeriesColor(countLineLikeChildren(ax) + 1), ...
        'DisplayName', getFoundationVibLegendName(respCh));
    plottedCount = plottedCount + 1;
    xMin = min(xMin, f(1));
    xMax = max(xMax, f(end));
    yMin = min(yMin, min(kAbs));
    yMax = max(yMax, max(kAbs));
end

if plottedCount > 0
    specF1 = max(30, xMin);
    specF2 = min(1000, xMax);
    if specF2 > specF1
        safeLoglog(ax, [specF1 specF2], [1e8 1e8], '--', 'LineWidth', 1.5, ...
            'Color', [0.85 0.20 0.20], 'DisplayName', 'Specification (10^8 N/m)');
    end
end
hold(ax, 'off');

grid(ax, 'on');
xlabel(ax, 'Frequency [Hz]');
ylabel(ax, 'Magnitude [N/m]');
title(ax, sprintf('Dynamic Stiffness - %s', F.fileName));
if plottedCount > 0
    legend(ax, 'show', 'Location', 'northwest');
else
    legend(ax, 'off');
end

if plottedCount == 0
    title(ax, 'Dynamic Stiffness (no valid points)');
    if isempty(skippedResp)
        msg = 'no valid stiffness points';
    else
        msg = ['no valid stiffness points for Stiff Ch: ' formatChannelList(skippedResp)];
    end
    return;
end

if ~keepExisting
    xlim(ax, [xMin, xMax]);
    if isfinite(yMin) && isfinite(yMax) && yMax > yMin
        ylim(ax, [yMin, yMax]);
    end
end

if ~isempty(skippedResp)
    msg = ['skipped Stiff Ch: ' formatChannelList(skippedResp)];
end
ok = true;
end

function [ok, msg] = renderFoundationCoherenceAxis(ax, F, exciteCh, respChannels, keepExisting)
ok = false;
msg = '';
styleAxisCompat(ax);
set(ax, 'XScale', 'log', 'YScale', 'linear', 'XLimMode', 'auto', 'YLimMode', 'auto');

if ~isfield(F, 'vna') || ~isfield(F.vna, 'freq') || isempty(F.vna.freq)
    msg = 'missing fdxvec';
    title(ax, 'Coherence (missing fdxvec)');
    return;
end
if ~isfield(F.vna, 'xcmeas') || isempty(F.vna.xcmeas)
    msg = 'missing xcmeas';
    title(ax, 'Coherence (missing xcmeas)');
    return;
end

xc = F.vna.xcmeas;
sz = size(xc);
if numel(sz) < 2 || exciteCh < 1 || exciteCh > sz(1)
    msg = sprintf('xcmeas excite index out of range (%d)', exciteCh);
    title(ax, 'Coherence (excite channel out of range)');
    return;
end
if isempty(respChannels)
    msg = 'Stiff Ch is empty';
    title(ax, 'Coherence (empty response channels)');
    return;
end

hold(ax, 'on');
xMin = inf;
xMax = -inf;
plottedCount = 0;
skippedResp = [];
for i = 1:numel(respChannels)
    respCh = respChannels(i);
    if respCh < 1 || respCh > sz(2)
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end
    if ~isstruct(xc(exciteCh, respCh)) || ~isfield(xc(exciteCh, respCh), 'coh') || isempty(xc(exciteCh, respCh).coh)
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end

    coh = xc(exciteCh, respCh).coh(:);
    M = min(numel(F.vna.freq), numel(coh));
    if M < 3
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end
    f = F.vna.freq(2:M);
    c = coh(2:M);
    valid = isfinite(f) & isfinite(c) & (f > 0);
    f = f(valid);
    c = c(valid);
    if numel(f) < 2
        skippedResp(end + 1) = respCh; %#ok<AGROW>
        continue;
    end

    safeSemilogx(ax, f, c, 'LineWidth', 1.2, ...
        'Color', getSeriesColor(countLineLikeChildren(ax) + 1), ...
        'DisplayName', getFoundationVibLegendName(respCh));
    plottedCount = plottedCount + 1;
    xMin = min(xMin, f(1));
    xMax = max(xMax, f(end));
end
hold(ax, 'off');

grid(ax, 'on');
xlabel(ax, 'Frequency [Hz]');
ylabel(ax, 'Coherence');
title(ax, sprintf('Coherence - %s', F.fileName));
if plottedCount > 0
    legend(ax, 'show', 'Location', 'northwest');
else
    legend(ax, 'off');
end
ylim(ax, [0 1]);

if plottedCount == 0
    title(ax, 'Coherence (no valid points)');
    if isempty(skippedResp)
        msg = 'no valid coherence points';
    else
        msg = ['no valid coherence points for Stiff Ch: ' formatChannelList(skippedResp)];
    end
    return;
end

if ~keepExisting
    xlim(ax, [xMin, xMax]);
end

if ~isempty(skippedResp)
    msg = ['skipped Stiff Ch: ' formatChannelList(skippedResp)];
end

ok = true;
end

function [fc, fcL, fcU, errMsg] = getThirdOctaveBandsCompat(minF, maxF)
fc = [];
fcL = [];
fcU = [];
errMsg = '';

if ~isfinite(minF) || ~isfinite(maxF) || minF <= 0 || maxF <= minF
    errMsg = 'invalid frequency range';
    return;
end

[fc0, fcL0, fcU0] = computeNthFreqBandInternal(3, minF, maxF);

fc0 = fc0(:);
fcL0 = fcL0(:);
fcU0 = fcU0(:);
M = min([numel(fc0), numel(fcL0), numel(fcU0)]);
fc0 = fc0(1:M);
fcL0 = fcL0(1:M);
fcU0 = fcU0(1:M);
valid = isfinite(fc0) & isfinite(fcL0) & isfinite(fcU0) & (fc0 > 0) & (fcL0 > 0) & (fcU0 > fcL0);
fc0 = fc0(valid);
fcL0 = fcL0(valid);
fcU0 = fcU0(valid);

if isempty(fc0)
    errMsg = 'empty third-octave bands';
    return;
end
if maxF < fcU0(end)
    fc0 = fc0(1:end-1);
    fcL0 = fcL0(1:end-1);
    fcU0 = fcU0(1:end-1);
end
if isempty(fc0)
    errMsg = 'empty third-octave bands';
    return;
end

fc = fc0;
fcL = fcL0;
fcU = fcU0;
end

function [fc, fcL, fcU] = computeNthFreqBandInternal(N, minF, maxF)
if nargin < 1 || ~isfinite(N) || N <= 0
    N = 3;
end
if nargin < 2 || ~isfinite(minF) || minF <= 0
    minF = 20;
end
if nargin < 3 || ~isfinite(maxF) || maxF <= minF
    maxF = 20000;
end

N = round(N);
Nmax = round(N * ceil(log(maxF / 1000) / log(2)) + 1);
if Nmax < 1
    Nmax = 1;
end

f_ab = zeros(Nmax + 1, 1);
f_ab(1) = 1000;
for n = 1:Nmax
    f_ab(n + 1) = f_ab(n) * 10 ^ (3 / (10 * N));
end
f_ab = f_ab(f_ab < maxF * (2 ^ (0.5 / N)));

Nmin = round(N * ceil(log(1000 / minF) / log(2)) + 1);
if Nmin < 1
    Nmin = 1;
end

f_bl = zeros(Nmin + 1, 1);
f_bl(1) = 1000;
for n = 1:Nmin
    f_bl(n + 1) = f_bl(n) / (10 ^ (3 / (10 * N)));
end
f_bl = f_bl(f_bl > minF * (2 ^ (-0.5 / N)));

fc = unique([f_bl; f_ab]);
fc = fc(fc < maxF * (2 ^ (0.5 / N)));
fc = fc(fc > minF * (2 ^ (-0.5 / N)));
fcL = fc / (2 ^ (1 / (2 * N)));
fcU = fc * (2 ^ (1 / (2 * N)));

fc = applyAnsiPreferredAdjust(fc);
fcL = sdRoundInternal(fcL, 3, 5);
fcU = sdRoundInternal(fcU, 3, 5);
end

function out = applyAnsiPreferredAdjust(fc)
fc5 = sdRoundInternal(fc, 3, 5);
fc100 = sdRoundInternal(fc, 3, 100);
out = fc5;
mask = isfinite(fc5) & isfinite(fc100) & (fc100 ~= 0) & (abs(100 * (1 - fc5 ./ fc100)) < 1);
out(mask) = fc100(mask);
end

function A2 = sdRoundInternal(A, Nsig, mult)
if nargin < 2 || ~isfinite(Nsig)
    Nsig = 3;
end
if nargin < 3 || ~isfinite(mult)
    mult = 1;
end
Nsig = max(1, round(Nsig));
mult = max(1, round(mult));

A2 = A;
if isempty(A)
    return;
end

for i = 1:numel(A)
    a = A(i);
    if ~isfinite(a) || a == 0
        A2(i) = a;
        continue;
    end

    D = ceil(log10(abs(a)));
    if abs(a) - 10 ^ D == 0
        D = D + 1;
    end
    dec = 10 ^ (Nsig - D);
    buf = dec / mult;
    A2(i) = round(buf * a) / buf;
end
end

function txt = formatChannelList(chList)
if isempty(chList)
    txt = '';
    return;
end
chList = unique(chList(:)', 'stable');
txt = num2str(chList(1));
for i = 2:numel(chList)
    txt = [txt ',' num2str(chList(i))]; %#ok<AGROW>
end
end

function name = getFoundationVibLegendName(ch)
switch ch
    case 2
        name = 'X';
    case 3
        name = 'Y';
    case 4
        name = 'Z';
    otherwise
        name = sprintf('Ch%d', ch);
end
end

function [timeWindow, errMsg] = parseTimeRangeInputs(edtStart, edtEnd)
timeWindow = [NaN NaN];
errMsg = '';

startRaw = '';
endRaw = '';
try
    startRaw = strtrim(get(edtStart, 'String'));
catch
end
try
    endRaw = strtrim(get(edtEnd, 'String'));
catch
end

if ~isempty(startRaw)
    t0 = str2double(startRaw);
    if ~isfinite(t0)
        errMsg = 'Time Start must be a valid number or empty.';
        return;
    end
    timeWindow(1) = t0;
end

if ~isempty(endRaw)
    t1 = str2double(endRaw);
    if ~isfinite(t1)
        errMsg = 'Time End must be a valid number or empty.';
        return;
    end
    timeWindow(2) = t1;
end

if isfinite(timeWindow(1)) && isfinite(timeWindow(2)) && timeWindow(2) <= timeWindow(1)
    errMsg = 'Time End must be greater than Time Start.';
end
end

% Apply time window on aligned vectors.
function [tOut, yOut] = applyTimeWindow(tIn, yIn, timeWindow)
tOut = tIn(:);
yOut = yIn(:);
N = min(numel(tOut), numel(yOut));
tOut = tOut(1:N);
yOut = yOut(1:N);
if isempty(tOut) || isempty(yOut)
    return;
end

if nargin < 3 || isempty(timeWindow) || numel(timeWindow) < 2
    return;
end

tStart = timeWindow(1);
tEnd = timeWindow(2);
mask = true(size(tOut));
if isfinite(tStart)
    mask = mask & (tOut >= tStart);
end
if isfinite(tEnd)
    mask = mask & (tOut <= tEnd);
end
tOut = tOut(mask);
yOut = yOut(mask);
end

% Compatible check for periodogram source mode (without using contains).
function tf = isPeriodogramSource(psdSourceMode)
tf = false;
if ischar(psdSourceMode)
    tf = ~isempty(strfind(lower(psdSourceMode), 'periodogram')); %#ok<STREMP>
end
end

function quantityMode = getQuantityMode(h)
quantityMode = 'Acceleration';
try
    quantityMode = getPopupSelection(h);
catch
end
if ~ischar(quantityMode) || isempty(quantityMode)
    quantityMode = 'Acceleration';
end
end

function [quantityName, yLabel] = getTimeQuantityLabel(quantityMode)
quantityName = 'Acceleration';
yLabel = 'Acceleration (m/s^2)';
if ~ischar(quantityMode)
    return;
end
switch lower(strtrim(quantityMode))
    case 'velocity'
        quantityName = 'Velocity';
        yLabel = 'Velocity (um/s)';
    case 'displacement'
        quantityName = 'Displacement';
        yLabel = 'Displacement (um)';
end
end

function [quantityName, yLabel] = getPsdQuantityLabel(quantityMode)
quantityName = 'Acceleration';
yLabel = '(m/s^2)^2/Hz';
if ~ischar(quantityMode)
    return;
end
switch lower(strtrim(quantityMode))
    case 'velocity'
        quantityName = 'Velocity';
        yLabel = '(um/s)^2/Hz';
    case 'displacement'
        quantityName = 'Displacement';
        yLabel = 'um^2/Hz';
end
end

function [quantityName, yLabel] = getCumPsdLabel(quantityMode)
quantityName = 'Acceleration';
yLabel = '3sigma Acceleration (m/s^2)';
if ~ischar(quantityMode)
    return;
end
switch lower(strtrim(quantityMode))
    case 'velocity'
        quantityName = 'Velocity';
        yLabel = '3sigma Velocity (um/s)';
    case 'displacement'
        quantityName = 'Displacement';
        yLabel = '3sigma Displacement (um)';
end
end

function yOut = convertAccelerationTimeSeries(yAcc, fs, quantityMode, useHigh, highCutoff)
yOut = yAcc(:);
if ~ischar(quantityMode)
    return;
end
modeKey = lower(strtrim(quantityMode));
if strcmp(modeKey, 'acceleration')
    return;
end
if isempty(yOut) || numel(yOut) < 2 || ~isfinite(fs) || fs <= 0
    yOut = [];
    return;
end

yWork = yOut - mean(yOut);
N = numel(yWork);
freqSigned = getSignedFrequencyVector(N, fs);
omega = 2 * pi * freqSigned;
Y = fft(yWork);

if useHigh && isfinite(highCutoff) && highCutoff > 0
    Y(abs(freqSigned) < highCutoff) = 0;
end

scale = zeros(size(omega));
nonzero = abs(omega) > 0;
switch modeKey
    case 'velocity'
        scale(nonzero) = 1 ./ (1i * omega(nonzero));
        yOut = real(ifft(Y .* scale)) * 1e6;
    case 'displacement'
        scale(nonzero) = -1 ./ (omega(nonzero) .^ 2);
        yOut = real(ifft(Y .* scale)) * 1e6;
    otherwise
        yOut = yAcc(:);
end
end

function [fOut, psdOut] = convertAccelerationPsd(f, psdAcc, quantityMode, useHigh, highCutoff)
fOut = f(:);
psdOut = psdAcc(:);
if isempty(fOut) || isempty(psdOut) || numel(fOut) ~= numel(psdOut)
    fOut = [];
    psdOut = [];
    return;
end
valid = isfinite(fOut) & isfinite(psdOut) & (fOut > 0) & (psdOut > 0);
fOut = fOut(valid);
psdOut = psdOut(valid);
if isempty(fOut)
    return;
end

if ~ischar(quantityMode)
    quantityMode = 'Acceleration';
end
modeKey = lower(strtrim(quantityMode));
omega = 2 * pi * fOut;
switch modeKey
    case 'velocity'
        psdOut = psdOut ./ (omega .^ 2) * 1e12;
    case 'displacement'
        psdOut = psdOut ./ (omega .^ 4) * 1e12;
end

if ~strcmp(modeKey, 'acceleration') && useHigh && isfinite(highCutoff) && highCutoff > 0
    keep = fOut >= highCutoff;
    fOut = fOut(keep);
    psdOut = psdOut(keep);
end

valid = isfinite(fOut) & isfinite(psdOut) & (fOut > 0) & (psdOut > 0);
fOut = fOut(valid);
psdOut = psdOut(valid);
end

function [fOut, yOut] = computeCumulativeSpectrum(f, psd)
fOut = [];
yOut = [];
f = f(:);
psd = psd(:);
if isempty(f) || isempty(psd) || numel(f) ~= numel(psd)
    return;
end

valid = isfinite(f) & isfinite(psd) & (f > 0) & (psd >= 0);
f = f(valid);
psd = psd(valid);
if numel(f) < 2
    return;
end

[f, order] = sort(f, 'ascend');
psd = psd(order);
cumVal = zeros(size(f));
for i = 2:numel(f)
    df = f(i) - f(i - 1);
    if ~isfinite(df) || df <= 0
        cumVal(i) = cumVal(i - 1);
    else
        cumVal(i) = cumVal(i - 1) + 0.5 * (psd(i - 1) + psd(i)) * df;
    end
end
cumVal = max(cumVal, 0);
fOut = f;
yOut = 3 * sqrt(cumVal);
end

function freqSigned = getSignedFrequencyVector(N, fs)
if mod(N, 2) == 0
    k = [0:(N / 2), (-N / 2 + 1):-1]';
else
    k = [0:((N - 1) / 2), (-((N - 1) / 2)):-1]';
end
freqSigned = k * (fs / N);
end

% Compute PSD with periodogram from time-domain segment.
function [f, psd] = computePeriodogramPsd(y, fs)
f = [];
psd = [];
y = y(:);
y = y(isfinite(y));
if numel(y) < 2 || ~isfinite(fs) || fs <= 0
    return;
end
y = y - mean(y);

try
    [p0, f0] = periodogram(y, [], [], fs);
catch
    [f0, p0] = singleSideSpectrum(y, fs);
end

valid = isfinite(f0) & isfinite(p0) & (f0 > 0) & (p0 > 0);
f = f0(valid);
psd = p0(valid);
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

% 获取工程单位换算系数 eu_val（缺省为 1）
function eu = getEuVal(sc)
if isfield(sc, 'eu_val') && ~isempty(sc.eu_val) && isfinite(sc.eu_val)
    eu = sc.eu_val;
else
    eu = 1;
end
end

% 汇总所有已加载文件中的有效通道并去重
function valid = collectValidChannels(files)
valid = [];
for i = 1:numel(files)
    v = files{i}.validChannels;
    if ~isempty(v)
        valid = [valid, v(:)']; %#ok<AGROW>
    end
end
if isempty(valid)
    valid = 1;
else
    valid = unique(valid, 'stable');
end
end

% 生成顶部文件显示文本（少量文件显示名称，多文件显示摘要）
function txt = summarizeLoadedFiles(files)
n = numel(files);
if n <= 3
    names = cell(1, n);
    for i = 1:n
        names{i} = getSeriesDisplayFileName(files{i}.fileName);
    end
    txt = strjoin(names, '; ');
else
    txt = sprintf('%d files loaded (last: %s)', n, getSeriesDisplayFileName(files{end}.fileName));
end
end

% 根据已加载文件重建“数据项列表”（文件+通道）
function app = rebuildSeriesList(app)
app = pruneCustomSeriesLabels(app);
app = pruneCustomSeriesScales(app);
totalSeries = 0;
for fi = 1:numel(app.files)
    totalSeries = totalSeries + numel(app.files{fi}.validChannels);
end
series = cell(1, totalSeries);
si = 0;
for fi = 1:numel(app.files)
    F = app.files{fi};
    for ci = 1:numel(F.validChannels)
        ch = F.validChannels(ci);
        label = getSeriesBaseLabel(app, F, ch);
        label = stripVnaSuffixInSeriesLabel(label);
        % Keep labels unique even when same file is loaded multiple times.
        base = label;
        k = 2;
        while any(cellfun(@(s) ~isempty(s) && strcmp(s.label, label), series(1:si)))
            label = sprintf('%s#%d', base, k);
            k = k + 1;
        end
        si = si + 1;
        series{si} = struct('fileIdx', fi, 'fileId', F.id, 'ch', ch, 'label', label);
    end
end
series = series(1:si);
app.series = series;
end

% 清理已失效的自定义名称映射（文件被删后）
function app = pruneCustomSeriesLabels(app)
if isempty(app.customSeriesNames)
    return;
end
validFileIds = zeros(1, numel(app.files));
for i = 1:numel(app.files)
    validFileIds(i) = app.files{i}.id;
end

keep = false(1, numel(app.customSeriesNames));
for i = 1:numel(app.customSeriesNames)
    keep(i) = ismember(app.customSeriesNames{i}.fileId, validFileIds);
end
app.customSeriesNames = app.customSeriesNames(keep);
end

% 清理已失效的自定义缩放映射（文件被删后）
function app = pruneCustomSeriesScales(app)
if isempty(app.customSeriesScales)
    return;
end
validFileIds = zeros(1, numel(app.files));
for i = 1:numel(app.files)
    validFileIds(i) = app.files{i}.id;
end

keep = false(1, numel(app.customSeriesScales));
for i = 1:numel(app.customSeriesScales)
    keep(i) = ismember(app.customSeriesScales{i}.fileId, validFileIds);
end
app.customSeriesScales = app.customSeriesScales(keep);
end

% 获取数据项基础显示名（优先自定义名，否则文件名+通道）
function label = getSeriesBaseLabel(app, F, ch)
label = getCustomSeriesLabel(app, F.id, ch);
if isempty(label)
    label = sprintf('%s+ch%d', getSeriesDisplayFileName(F.fileName), ch);
end
end

% 查询指定文件+通道的自定义显示名
function name = getSeriesDisplayFileName(fileName)
name = fileName;
if iscell(name)
    if isempty(name)
        name = '';
    else
        name = name{1};
    end
end
if ~ischar(name)
    try
        if isstring(name) && isscalar(name)
            name = char(name);
        end
    catch
    end
end
if ~ischar(name) || isempty(name)
    return;
end
[stem, ext] = fileparts(name);
if strcmpi(ext, '.vna')
    name = stem;
end
end

function label = stripVnaSuffixInSeriesLabel(label)
if ~ischar(label) || isempty(label)
    return;
end
% Remove ".vna" only in default-like labels such as "name.vna+ch2" / "name.vna+ch2#2".
try
    label = regexprep(label, '(?i)\.vna(?=\+ch\d+(#\d+)?$)', '');
catch
end
end

function label = getCustomSeriesLabel(app, fileId, ch)
label = '';
for i = 1:numel(app.customSeriesNames)
    one = app.customSeriesNames{i};
    if one.fileId == fileId && one.ch == ch
        label = one.label;
        return;
    end
end
end

% 设置/更新指定文件+通道的自定义显示名
function app = setCustomSeriesLabel(app, fileId, ch, label)
found = false;
for i = 1:numel(app.customSeriesNames)
    one = app.customSeriesNames{i};
    if one.fileId == fileId && one.ch == ch
        app.customSeriesNames{i}.label = label;
        found = true;
        break;
    end
end
if ~found
    app.customSeriesNames{end + 1} = struct('fileId', fileId, 'ch', ch, 'label', label);
end
end

% 获取指定数据项的时域缩放因子（Factor）
function scaleValue = getSeriesScale(app, S)
fileId = getSeriesFileId(S, app);
scaleValue = 1;
if ~isfinite(fileId)
    return;
end
for i = 1:numel(app.customSeriesScales)
    one = app.customSeriesScales{i};
    if one.fileId == fileId && one.ch == S.ch
        scaleValue = one.scale;
        return;
    end
end
end

% 设置/更新指定数据项的时域缩放因子（Factor）
function app = setCustomSeriesScale(app, fileId, ch, scaleValue)
found = false;
for i = 1:numel(app.customSeriesScales)
    one = app.customSeriesScales{i};
    if one.fileId == fileId && one.ch == ch
        app.customSeriesScales{i}.scale = scaleValue;
        found = true;
        break;
    end
end
if ~found
    app.customSeriesScales{end + 1} = struct('fileId', fileId, 'ch', ch, 'scale', scaleValue);
end
end

% 根据 fileId+通道在当前 series 中查找实际显示名
function label = findSeriesLabel(series, fileId, ch, fallback)
label = fallback;
for i = 1:numel(series)
    if series{i}.fileId == fileId && series{i}.ch == ch
        label = series{i}.label;
        return;
    end
end
end

% 从 series 条目解析 fileId（兼容旧字段）
function fileId = getSeriesFileId(S, app)
if isfield(S, 'fileId') && ~isempty(S.fileId)
    fileId = S.fileId;
    return;
end

fileId = NaN;
if isfield(S, 'fileIdx') && ~isempty(S.fileIdx)
    fileIdx = S.fileIdx;
    if fileIdx >= 1 && fileIdx <= numel(app.files) && isfield(app.files{fileIdx}, 'id')
        fileId = app.files{fileIdx}.id;
        return;
    end
end
end

% 按显示名从 series 中筛选出已选数据项
function selectedSeries = getSelectedSeries(series, selectedLabels)
if isempty(series) || isempty(selectedLabels)
    selectedSeries = {};
    return;
end
if isTextScalarCompat(selectedLabels)
    selectedLabels = cellstr(selectedLabels);
end
selectedSeries = {};
for i = 1:numel(series)
    if ismember(series{i}.label, selectedLabels)
        selectedSeries{end + 1} = series{i}; %#ok<AGROW>
    end
end
end

% 若目标通道无效，则选择最接近的有效通道
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

% 安全读取 cell 指定元素（越界返回空）
function x = safeCellGet(c, idx)
if idx >= 1 && idx <= numel(c)
    x = c{idx};
else
    x = [];
end
end

% 安全读取数组指定元素（越界或无效返回默认值）
function v = safeGet(arr, idx, fallback)
if idx >= 1 && idx <= numel(arr) && isfinite(arr(idx))
    v = arr(idx);
else
    v = fallback;
end
end

% 过滤无效点后执行线性 plot
function safePlot(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
plot(ax, x, y, varargin{:});
end

% 过滤无效点后执行 semilogx
function safeSemilogx(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y) & (x > 0);
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
semilogx(ax, x, y, varargin{:});
end

% 过滤无效点后执行 loglog
function safeLoglog(ax, x, y, varargin)
valid = isfinite(x) & isfinite(y) & (x > 0) & (y > 0);
x = x(valid);
y = y(valid);
if isempty(x) || isempty(y)
    return;
end
loglog(ax, x, y, varargin{:});
end

% 统一曲线调色板（保证多曲线颜色可区分）
function c = getSeriesColor(idx)
palette = [ ...
    0.0000 0.4470 0.7410; ...
    0.8500 0.3250 0.0980; ...
    0.9290 0.6940 0.1250; ...
    0.4940 0.1840 0.5560; ...
    0.4660 0.6740 0.1880; ...
    0.3010 0.7450 0.9330; ...
    0.6350 0.0780 0.1840; ...
    0.2500 0.2500 0.2500];
if nargin < 1 || ~isfinite(idx) || idx < 1
    idx = 1;
end
idx = mod(round(idx) - 1, size(palette, 1)) + 1;
c = palette(idx, :);
end

% 统计坐标轴中 line 对象数量（用于颜色续接）
function n = countLineLikeChildren(ax)
n = 0;
try
    kids = get(ax, 'Children');
    for i = 1:numel(kids)
        kidType = get(kids(i), 'Type');
        if strcmp(kidType, 'line')
            n = n + 1;
        end
    end
catch
    n = 0;
end
end

% 生成单独导出图窗标题（优先使用轴标题）
function figName = getAxisExportTitle(ax, fallbackTitle)
figName = fallbackTitle;
try
    t = get(get(ax, 'Title'), 'String');
    if iscell(t)
        t = strjoin(t, ' ');
    end
    if ischar(t) && ~isempty(strtrim(t))
        figName = strtrim(t);
    end
catch
end
end

% 复制当前轴内容到新 Figure（用于单图保存）
function cloneAxisToFigure(sourceAx, figName, legendLoc)
if nargin < 3 || isempty(legendLoc)
    legendLoc = 'northeast';
end
hFig = figure( ...
    'Name', figName, ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'MenuBar', 'figure', ...
    'ToolBar', 'figure', ...
    'Position', [120 120 900 560]);
setFigureRendererCompat(hFig);

newAx = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.13 0.11 0.775 0.815], 'Box', 'on');
copyAxisContent(sourceAx, newAx, legendLoc);
enableInteractiveFigureCompat(hFig);
end

% 将两个坐标轴复制到同一 Figure 的 subplot(211/212) 中
function cloneTwoAxesToFigure(sourceAxTop, sourceAxBottom, figName, legendLoc)
if nargin < 4 || isempty(legendLoc)
    legendLoc = 'northeast';
end
hFig = figure( ...
    'Name', figName, ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'MenuBar', 'figure', ...
    'ToolBar', 'figure', ...
    'Position', [120 80 920 700]);
setFigureRendererCompat(hFig);

figure(hFig);
newAxTop = subplot(2, 1, 1);
newAxBottom = subplot(2, 1, 2);
copyAxisContent(sourceAxTop, newAxTop, legendLoc);
copyAxisContent(sourceAxBottom, newAxBottom, legendLoc);
enableInteractiveFigureCompat(hFig);
end

% 复制坐标轴内容及样式到目标轴
function copyAxisContent(sourceAx, targetAx, legendLoc)
if nargin < 3 || isempty(legendLoc)
    legendLoc = 'northeast';
end
cla(targetAx);
copyobj(allchild(sourceAx), targetAx);

set(targetAx, ...
    'XScale', get(sourceAx, 'XScale'), ...
    'YScale', get(sourceAx, 'YScale'), ...
    'XGrid', get(sourceAx, 'XGrid'), ...
    'YGrid', get(sourceAx, 'YGrid'), ...
    'Box', get(sourceAx, 'Box'), ...
    'LineWidth', get(sourceAx, 'LineWidth'), ...
    'FontSize', get(sourceAx, 'FontSize'));
try
    set(targetAx, 'XLim', get(sourceAx, 'XLim'));
catch
end
try
    set(targetAx, 'YLim', get(sourceAx, 'YLim'));
catch
end

xlabel(targetAx, get(get(sourceAx, 'XLabel'), 'String'));
ylabel(targetAx, get(get(sourceAx, 'YLabel'), 'String'));
title(targetAx, get(get(sourceAx, 'Title'), 'String'));

try
    legend(targetAx, 'show', 'Location', legendLoc);
catch
end
end

% 按显示名恢复列表选中项（找不到则回退默认）
function setListSelectionByLabels(h, items, selectedLabels)
if isempty(items)
    set(h, 'Value', 1);
    return;
end
if isempty(selectedLabels)
    set(h, 'Value', 1:numel(items));
    return;
end

idx = zeros(1, numel(selectedLabels));
k = 0;
for i = 1:numel(selectedLabels)
    oneIdx = find(strcmp(items, selectedLabels{i}), 1, 'first');
    if ~isempty(oneIdx)
        k = k + 1;
        idx(k) = oneIdx;
    end
end
idx = idx(1:k);
if isempty(idx)
    idx = 1;
end
set(h, 'Value', unique(idx, 'stable'));
end

% 判断向量是否像时间轴（单调递增且步长近似恒定）
function tf = isTimeLike(v)
v = v(:);
if numel(v) < 3 || any(~isfinite(v))
    tf = false;
    return;
end
d = diff(v);
tf = all(d > 0) && (std(d) / max(mean(d), eps) < 1e-2);
end

% 校验采样率输入是否有效
function validateFs(fs)
if isempty(fs) || ~isfinite(fs) || fs <= 0
    error('Invalid Fs. Please input a valid sampling frequency.');
end
end

% 计算单边幅值谱（FFT）
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

% 从编辑框读取数值，失败时返回 fallback
function v = getNumericControlValue(h, fallback)
v = fallback;
try
    raw = get(h, 'String');
    if iscell(raw)
        raw = raw{1};
    end
    numVal = str2double(raw);
    if isfinite(numVal)
        v = numVal;
    end
catch
end
end

% 向编辑框写入数值文本
function setNumericControlValue(h, v)
try
    set(h, 'String', num2str(v));
catch
end
end

% 获取下拉框当前选中的图类型字符串
function mode = getPopupSelection(h)
items = getCellStringCompat(get(h, 'String'));
idx = get(h, 'Value');
if isempty(items)
    mode = 'Time';
    return;
end
idx = max(1, min(numel(items), idx));
mode = items{idx};
end

% 获取列表当前选中项对应的字符串集合
function labels = getSelectedListLabels(h)
items = getCellStringCompat(get(h, 'String'));
idx = get(h, 'Value');
if isempty(items) || isempty(idx)
    labels = {};
    return;
end
idx = idx(idx >= 1 & idx <= numel(items));
labels = items(idx);
labels = labels(~cellfun(@isempty, labels));
end

% 兼容 char/cell/string 的字符串列表转换
function items = getCellStringCompat(raw)
if isempty(raw)
    items = {};
elseif ischar(raw)
    items = cellstr(raw);
elseif iscell(raw)
    items = raw;
else
    items = {};
end
end

% 兼容目录存在性检查（适配老版本 MATLAB）
function tf = isDirCompat(p)
tf = ischar(p) && exist(p, 'dir') == 7;
end

% 统一弹窗提示（uialert 不可用时回退 errordlg）
function showAlertCompat(figHandle, msg, ttl)
try
    uialert(figHandle, msg, ttl);
catch
    errordlg(msg, ttl);
end
end

% 兼容判断“是否为文本标量”
function tf = isTextScalarCompat(v)
tf = ischar(v);
if tf
    return;
end
try
    tf = isstring(v) && isscalar(v);
catch
    tf = false;
end
end

% 兼容读取数值矩阵（新版本 readmatrix，旧版本回退）
function X = readMatrixCompat(fileName)
if exist('readmatrix', 'file') == 2
    X = readmatrix(fileName);
    return;
end

[~, ~, ext] = fileparts(fileName);
ext = lower(ext);
switch ext
    case '.xlsx'
        X = xlsread(fileName);
    otherwise
        X = dlmread(fileName);
end
end

% 设置图窗渲染器（优先 painters，提升导出稳定性）
function setFigureRendererCompat(hFig)
try
    set(hFig, 'Renderer', 'painters');
catch
end
end

% 打开图窗交互能力（缩放、平移、数据光标）
function enableInteractiveFigureCompat(hFig)
try
    zoom(hFig, 'on');
catch
end
try
    pan(hFig, 'on');
catch
end
try
    dcm = datacursormode(hFig);
    set(dcm, 'Enable', 'on', 'DisplayStyle', 'datatip', 'SnapToDataVertex', 'on');
catch
end
end

% 统一坐标轴样式（边框、字体、边距）
function styleAxisCompat(ax)
try
    set(ax, 'Box', 'on', 'LineWidth', 1.0, 'FontSize', 10, ...
        'ActivePositionProperty', 'outerposition', ...
        'LooseInset', [0.08 0.08 0.03 0.05]);
catch
end
end
