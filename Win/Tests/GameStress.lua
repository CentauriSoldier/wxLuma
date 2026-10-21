--[[!
@fqxn wxLuma.Tests.GameStress
@desc Runs visible old/new UI workloads at a 120 Hz target. The benchmark host
    supplies a monotonic high-resolution wall clock. Each logical frame updates
    controls, runs two milliseconds of synthetic game logic and completes native
    paint requests before recording completion. Desktop presentation is not timed.
    Run GameStress.ps1; production framework code is not modified.
!]]
assert(APP_PATH and BENCH_NOW and BENCH_SLEEP, "Run this benchmark through GameStress.ps1.");
package.path  = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";

local _wx          = require("wx");
_wx.wxGetApp():SetExitOnFrameDelete(false);
local _Controls    = require("wxLuma.Controls");
local _Window      = require("wxLuma.Containers.Window");
local _pBackup     = APP_PATH.."/Backups/UI-before-objects-20261020-113030/Scripts/";
local _pBefore     = APP_PATH.."/Backups/UI-before-redraw-optimization/Scripts/";
local _bDirty      = BENCH_REDRAW_MODE ~= "Full";
local _bViewport   = BENCH_REDRAW_MODE == "Game";
local _nTargetHz   = 120;
local _nBudget     = 1000 / _nTargetHz;
local _nWarmFrames = 120;
local _nFrames     = 600;
local _nGameMs     = 2;
local _bStopped    = false;
local _tItems      = {};
local _tResults    = {};
local _tProfiles   = {
    {Name = "HUD",   Lists = 1, Meters = 8,  Sliders = 2, Checks = 2, Buttons = 2, Radios = 2, Editors = 1, Scrollbars = 1, Particles = 120},
    {Name = "Heavy", Lists = 4, Meters = 48, Sliders = 8, Checks = 8, Buttons = 8, Radios = 4, Editors = 2, Scrollbars = 4, Particles = 600},
};

for nIndex = 1, 10000 do
    _tItems[nIndex] = string.format("Combat log entry %05d", nIndex);
end

--[[!
@fqxn wxLuma.Tests.GameStress.baseline
@desc Loads a preserved implementation and all dependencies in an isolated cache.
@param string pRoot The preserved Scripts directory.
@param boolean bPlainList Whether to use the original plain list experiment backup.
@ret table Controls The original factories.
@ret table Window The original window module.
!]]
local function baseline(pRoot, bPlainList)
    local tCache = {};
    local wEnv   = setmetatable({}, {__index = _G});

    local function fRequire(sModule)
        if (sModule == "wx") then
            return _wx;
        end

        local sSource = bPlainList and sModule == "UI.Widgets.List" and "UI.Widgets.ListPlain" or sModule;

        if (not tCache[sModule]) then
            local pModule = pRoot..sSource:gsub("%.", "/")..".lua";
            tCache[sModule] = assert(loadfile(pModule, "t", wEnv))();
        end

        return tCache[sModule];
    end

    wEnv.require = fRequire;
    return fRequire("UI.Controls"), fRequire("UI.Containers.Window");
end

--[[!
@fqxn wxLuma.Tests.GameStress.percentile
@desc Selects a nearest-rank percentile from measured wall-clock durations.
@param table tValues The nonempty timing samples; sorting occurs in place.
@param number nFraction The percentile as a fraction from zero to one.
@ret number nValue The selected duration in milliseconds.
!]]
local function percentile(tValues, nFraction)
    table.sort(tValues);
    return tValues[math.max(1, math.ceil(#tValues * nFraction))];
end

--[[!
@fqxn wxLuma.Tests.GameStress.createScene
@desc Builds a visible game-like control workload using either implementation.
@param table Controls The control factories.
@param table Window The window module.
@param table tProfile The workload counts.
@param string sVariant The old/new label.
@ret table tScene The scene and its owned native resources.
!]]
local function createScene(Controls, Window, tProfile, sVariant)
    local oDisplay = _wx.wxDisplay(0);
    local oArea    = oDisplay:GetClientArea();
    local nWidth   = math.min(1360, oArea:GetWidth() - 80);
    local nHeight  = math.min(940, oArea:GetHeight() - 100);
    oDisplay:delete();
    assert(nWidth >= 1000 and nHeight >= 740, "Display work area is too small for this workload.");

    local tScene = {
        Frame       = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma 120 Hz — "..tProfile.Name.." — "..sVariant,
            _wx.wxDefaultPosition, _wx.wxSize(nWidth, nHeight)),
        Skin        = Controls.loadSkin(),
        Group       = Controls.radioGroup(),
        Widgets     = {},
        Lists       = {},
        Meters      = {},
        Sliders     = {},
        Checks      = {},
        Buttons     = {},
        Radios      = {},
        Texts       = {},
        Spinners    = {},
        Scrollbars  = {},
        Paints      = 0,
        PaintCounts = {},
        Callbacks   = 0,
        SimFrame    = 0,
        Width       = nWidth,
        Height      = nHeight,
        Units       = tProfile.Particles,
    };
    local oBrush = _wx.wxBrush(_wx.wxColour(91, 139, 164));
    local oPen   = _wx.wxPen(_wx.wxColour(91, 139, 164), 1, _wx.wxPENSTYLE_SOLID);
    tScene.Brush = oBrush;
    tScene.Pen   = oPen;

    -- Keep the drawing path and allocations identical between implementations.
    tScene.Window = Window.create(tScene.Frame, {
        Title    = "wxLuma 120 Hz stress test",
        Subtitle = tProfile.Name.." / "..sVariant.." / 10,000 rows per list / synthetic game logic: 2 ms",
        PaintContent = function(oDC, tContent)
            if (_bViewport) then
                return;
            end

            oDC:SetBrush(oBrush);
            oDC:SetPen(oPen);

            for nIndex = 1, tProfile.Particles do
                local nX = tContent.x + (nIndex * 37 + tScene.SimFrame * (nIndex % 5 + 1)) % math.max(1, tContent.width - 6);
                local nY = tContent.y + (nIndex * 23 + tScene.SimFrame * (nIndex % 3 + 1)) % math.max(1, tContent.height - 6);
                oDC:DrawRectangle(nX, nY, 4, 4);
            end
        end,
    });
    tScene.Frame:SetClientSize(_wx.wxSize(nWidth, nHeight));
    tScene.Window.Control:SetSize(0, 0, nWidth, nHeight);
    local tContent = tScene.Window.getGeometry().Content;

    -- Count draw completions inside the real native paint handlers. Update()
    -- subsequently returns only after the native handler and DC cleanup finish.
    local function fTrack(oWidget)
        local fDraw = oWidget.draw;
        tScene.PaintCounts[oWidget] = 0;
        oWidget.draw = function(oDC, nDrawWidth, nDrawHeight)
            local bOk, sError = xpcall(fDraw, debug.traceback, oDC, nDrawWidth, nDrawHeight);

            if (not bOk) then
                tScene.PaintError = sError;
                return;
            end
            tScene.Paints = tScene.Paints + 1;
            tScene.PaintCounts[oWidget] = tScene.PaintCounts[oWidget] + 1;
        end;
    end

    local function fAdd(sFactory, tOptions, tCollection)
        tOptions.Skin = tScene.Skin;
        tOptions.OnChange = function(vValue, oSource)
            assert(oSource.Control, "A callback lost its public component.");
            tScene.Callbacks = tScene.Callbacks + 1;
        end;

        local oWidget = Controls[sFactory](tScene.Window.Control, tOptions);
        tScene.Widgets[#tScene.Widgets + 1] = oWidget;

        if (tCollection) then
            tCollection[#tCollection + 1] = oWidget;
        end

        fTrack(oWidget);
        return oWidget;
    end

    fTrack(tScene.Window);
    local nListWidth  = math.floor(tContent.width / tProfile.Lists);
    local nListHeight = math.floor(tContent.height * 0.28);

    for nIndex = 1, tProfile.Lists do
        fAdd("list", {Items = _tItems, Value = nIndex}, tScene.Lists).layout(
            tContent.x + (nIndex - 1) * nListWidth, tContent.y,
            nListWidth - 6, nListHeight
        );
    end

    local nMeterTop   = tContent.y + nListHeight + 6;
    local nMeterCols  = tProfile.Name == "HUD" and 4 or 8;
    local nMeterWidth = math.floor(tContent.width / nMeterCols);
    local nMeterRows  = math.ceil(tProfile.Meters / nMeterCols);

    for nIndex = 1, tProfile.Meters do
        fAdd("progress", {Min = 0, Max = 100, Value = nIndex % 100, Text = "Unit "..nIndex.."  %v"}, tScene.Meters).layout(
            tContent.x + (nIndex - 1) % nMeterCols * nMeterWidth,
            nMeterTop + math.floor((nIndex - 1) / nMeterCols) * 22,
            nMeterWidth - 6, 20
        );
    end

    local nSliderTop   = nMeterTop + nMeterRows * 22 + 6;
    local nSliderCols  = 4;
    local nSliderWidth = math.floor(tContent.width / nSliderCols);

    for nIndex = 1, tProfile.Sliders do
        fAdd("slider", {Min = 0, Max = 100, Step = 1, Value = 50}, tScene.Sliders).layout(
            tContent.x + (nIndex - 1) % nSliderCols * nSliderWidth,
            nSliderTop + math.floor((nIndex - 1) / nSliderCols) * 42,
            nSliderWidth - 6, 40
        );
    end

    local nInputTop   = nSliderTop + math.ceil(tProfile.Sliders / nSliderCols) * 42 + 6;
    local nInputWidth = math.floor(tContent.width / 8);
    local nInputIndex = 0;

    local function fInput(oWidget)
        oWidget.layout(
            tContent.x + nInputIndex % 8 * nInputWidth,
            nInputTop + math.floor(nInputIndex / 8) * 40,
            nInputWidth - 6, 36
        );
        nInputIndex = nInputIndex + 1;
    end

    for nIndex = 1, tProfile.Checks do
        fInput(fAdd("checkbox", {Text = "Flag "..nIndex}, tScene.Checks));
    end

    for nIndex = 1, tProfile.Buttons do
        fInput(fAdd("button", {
            Text = "Action "..nIndex,
            OnClick = function()
                tScene.Callbacks = tScene.Callbacks + 1;
            end,
        }, tScene.Buttons));
    end

    for nIndex = 1, tProfile.Radios do
        fInput(fAdd("radio", {Text = "Mode "..nIndex, Group = tScene.Group, Value = nIndex, Selected = nIndex == 1}, tScene.Radios));
    end

    for nIndex = 1, tProfile.Editors do
        fInput(fAdd("textfield", {Value = "Command"}, tScene.Texts));
        fInput(fAdd("spinner", {Min = 0, Max = 100, Step = 1, Value = 1}, tScene.Spinners));
    end

    for nIndex = 1, tProfile.Scrollbars do
        fInput(fAdd("scrollbar", {Min = 0, Max = 900, Page = 100, Value = 0, Vertical = false}, tScene.Scrollbars));
    end

    local nPanelTop = nInputTop + math.ceil(nInputIndex / 8) * 40 + 6;
    tScene.Panel = fAdd("panel", {Text = "Live command panel", MinWidth = 220, MinHeight = 100});
    tScene.Panel.layout(tContent.x, nPanelTop, math.min(500, tContent.width), math.max(100, tContent.y + tContent.height - nPanelTop));
    tScene.Dropdown = fAdd("dropdown", {Items = _tItems, Value = 1});
    tScene.Dropdown.layout(tContent.x + math.min(510, tContent.width - 250), nPanelTop, 240, 36);
    tScene.PanelX = tContent.x;
    tScene.PanelY = nPanelTop;

    if (_bViewport) then
        -- Keep animated game pixels in a sibling panel. Invalidating a native
        -- parent can invalidate all of its HUD children regardless of their state.
        local nDropdownX = tScene.Dropdown.Control:GetPositionXY();
        local nDropdownWidth = tScene.Dropdown.Control:GetSizeWH();
        local nViewportX = nDropdownX + nDropdownWidth + 10;
        local nViewportWidth = tContent.x + tContent.width - nViewportX;
        local nViewportHeight = tContent.y + tContent.height - nPanelTop;
        local oViewportControl = _wx.wxPanel(tScene.Window.Control, _wx.wxID_ANY,
            _wx.wxPoint(nViewportX, nPanelTop), _wx.wxSize(nViewportWidth, nViewportHeight),
            _wx.wxBORDER_NONE);
        oViewportControl:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
        tScene.ViewportBrush = _wx.wxBrush(_wx.wxColour(10, 12, 16));

        local tViewport = {
            Control = oViewportControl,
            Kind = "BenchmarkViewport",
            Disposed = false,
        };

        -- This fixture draws simple moving units, not a production game renderer.
        function tViewport.draw(oDC, nViewportDrawWidth, nViewportDrawHeight)
            if (tViewport.Disposed) then
                return;
            end

            oDC:SetBackground(tScene.ViewportBrush);
            oDC:Clear();
            oDC:SetBrush(oBrush);
            oDC:SetPen(oPen);

            for nIndex = 1, tProfile.Particles do
                local nX = (nIndex * 37 + tScene.SimFrame * (nIndex % 5 + 1)) % math.max(1, nViewportDrawWidth - 6);
                local nY = (nIndex * 23 + tScene.SimFrame * (nIndex % 3 + 1)) % math.max(1, nViewportDrawHeight - 6);
                oDC:DrawRectangle(nX, nY, 4, 4);
            end
        end

        function tViewport.destroy()
            tViewport.Disposed = true;
        end

        oViewportControl:Connect(_wx.wxEVT_PAINT, function()
            local oDC = _wx.wxAutoBufferedPaintDC(oViewportControl);
            tViewport.draw(oDC, oViewportControl:GetClientSizeWH());
            oDC:delete();
        end);
        tScene.Viewport = tViewport;
        tScene.ViewportWidth = nViewportWidth;
        tScene.ViewportHeight = nViewportHeight;
        tScene.Widgets[#tScene.Widgets + 1] = tViewport;
        fTrack(tViewport);
    end

    tScene.Frame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(jEvent)
        _bStopped = true;
        jEvent:Veto();
    end);
    tScene.Frame:Centre();
    tScene.Frame:Show(true);
    tScene.Frame:Raise();
    _wx.wxYield();
    assert(tScene.Window.Control:IsShownOnScreen(), "Benchmark surface is not visible.");

    for _, oWidget in ipairs(tScene.Widgets) do
        local nX, nY = oWidget.Control:GetPositionXY();
        local nWidgetWidth, nWidgetHeight = oWidget.Control:GetSizeWH();
        assert(nX >= 0 and nY >= 0 and nX + nWidgetWidth <= nWidth and nY + nWidgetHeight <= nHeight,
            "A benchmark widget falls outside the visible client area.");
    end

    return tScene;
end

--[[!
@fqxn wxLuma.Tests.GameStress.update
@desc Applies deterministic game-like value and input changes, a fixed synthetic
    game-logic budget, and synchronous native repaint requests for the whole scene.
@param table tScene The live scene.
@param number nFrame The deterministic simulation frame.
@ret number nUiMs The elapsed UI update and paint time, excluding synthetic logic.
!]]
local function update(tScene, nFrame)
    local nGameEnd = BENCH_NOW() + _nGameMs;
    local nAccumulator = nFrame;

    repeat
        for nIndex = 1, 128 do
            nAccumulator = (nAccumulator * 17 + nIndex) % 1000003;
        end
    until (BENCH_NOW() >= nGameEnd);

    tScene.Accumulator = nAccumulator;
    local nUiStart = BENCH_NOW();
    tScene.SimFrame = nFrame;

    for nIndex, oList in ipairs(tScene.Lists) do
        oList.scrollTo(1 + (nFrame * (nIndex + 1)) % 9900);
        oList.setValue(oList.First + nFrame % math.max(1, oList.getVisibleCount() - 1), true);
        oList.handlePointer("move", 20, 15 + nFrame % 4 * 28);
        oList.handleKey("down", nFrame % 2 == 0 and _wx.WXK_DOWN or _wx.WXK_UP);
    end

    for nIndex, oMeter in ipairs(tScene.Meters) do
        -- Most game resource bindings stay stable between model changes.
        -- A quarter remain continuously animated to retain active rendering work.
        local nValueFrame = _bDirty and nIndex % 4 ~= 0 and math.floor(nFrame / 30) or nFrame;
        oMeter.setValue((nValueFrame * 3 + nIndex * 7) % 101);
    end

    for nIndex, oSlider in ipairs(tScene.Sliders) do
        local nValueFrame = _bDirty and math.floor(nFrame / 6) or nFrame;
        oSlider.setValue((nValueFrame + nIndex * 11) % 101, true);
        oSlider.handlePointer("move", 16 + nFrame % 200, 20);
    end

    for nIndex, oScrollbar in ipairs(tScene.Scrollbars) do
        oScrollbar.setValue((nFrame * 3 + nIndex * 13) % 901, true);
    end

    if (_bDirty) then
        -- Poll model bindings every frame; unchanged setters should remain cheap.
        for nIndex, oCheckbox in ipairs(tScene.Checks) do
            oCheckbox.setValue((math.floor(nFrame / 90) + nIndex) % 2 == 0, true);
        end

        tScene.Radios[math.floor(nFrame / 120) % #tScene.Radios + 1].setValue(true, true);

        for _, oText in ipairs(tScene.Texts) do
            oText.setValue("Command "..math.floor(nFrame / 30), true);
        end

        for _, oSpinner in ipairs(tScene.Spinners) do
            oSpinner.setValue(math.floor(nFrame / 30) % 101, true);
        end
    end

    if (nFrame % 12 == 0) then
        for _, oCheckbox in ipairs(tScene.Checks) do
            if (not _bDirty) then
                oCheckbox.handleKey("down", _wx.WXK_SPACE);
                oCheckbox.handleKey("up", _wx.WXK_SPACE);
            end
        end

        for _, oButton in ipairs(tScene.Buttons) do
            oButton.handleKey("down", _wx.WXK_RETURN);
            oButton.handleKey("up", _wx.WXK_RETURN);
        end

        if (not _bDirty) then
            tScene.Radios[nFrame / 12 % #tScene.Radios + 1].setValue(true, true);
        end

        for _, oText in ipairs(tScene.Texts) do
            if (not _bDirty) then
                oText.setValue("Command "..nFrame, true);
            end
        end

        for _, oSpinner in ipairs(tScene.Spinners) do
            local nTypedValue = _bDirty and math.floor(nFrame / 30) % 101 or nFrame % 101;
            oSpinner.TextControl:ChangeValue(tostring(nTypedValue));
            assert(oSpinner.commitText(), "Synthetic spinner input failed.");
        end

        tScene.Dropdown.setValue(1 + nFrame % 10000, true);
    end

    if (nFrame % 30 == 0) then
        local nWidth, nHeight = tScene.Panel.Control:GetSizeWH();
        tScene.Panel.resize(nFrame % 60 == 0 and 440 or 480, nHeight, true);
    end

    local nBefore = tScene.Paints;
    local tBefore = {};

    for oWidget, nCount in pairs(tScene.PaintCounts) do
        tBefore[oWidget] = nCount;
    end
    if (_bViewport) then
        tScene.Viewport.Control:Refresh(false);
    else
        tScene.Window.Control:Refresh(false);
    end

    if (not _bDirty) then
        for _, oWidget in ipairs(tScene.Widgets) do
            oWidget.Control:Refresh(false);
        end
    end

    local tRequested = {};

    for oWidget in pairs(tBefore) do
        -- An unchanged widget need not paint. Every dirty widget must complete
        -- its native paint before this logical frame can be counted as finished.
        tRequested[oWidget] = not oWidget.Control:GetUpdateRegion():IsEmpty();
    end

    tScene.Window.Control:Update();

    for _, oWidget in ipairs(tScene.Widgets) do
        oWidget.Control:Update();

        if (oWidget.TextControl) then
            oWidget.TextControl:Update();
        end
    end

    _wx.wxYield();
    assert(not tScene.PaintError, tScene.PaintError);
    local tMissing = {};

    for oWidget, nCount in pairs(tBefore) do
        if (tRequested[oWidget] and tScene.PaintCounts[oWidget] <= nCount) then
            local nX, nY = oWidget.Control:GetPositionXY();
            local nWidth, nHeight = oWidget.Control:GetSizeWH();
            tMissing[#tMissing + 1] = string.format("%s shown=%s frozen=%s disposed=%s regionEmpty=%s rect=%d,%d,%d,%d",
                oWidget.Kind or "Window", tostring(oWidget.Control:IsShownOnScreen()),
                tostring(oWidget.Control:IsFrozen()), tostring(oWidget.Disposed),
                tostring(oWidget.Control:GetUpdateRegion():IsEmpty()), nX, nY, nWidth, nHeight);
        end
    end

    assert(#tMissing == 0, "Requested paints missing at frame "..nFrame..": "..table.concat(tMissing, ", "));
    return BENCH_NOW() - nUiStart;
end

--[[!
@fqxn wxLuma.Tests.GameStress.dispose
@desc Releases component resources before their skin and native frame.
@param table tScene The scene being retired.
!]]
local function dispose(tScene)
    for _, oWidget in ipairs(tScene.Widgets) do
        oWidget.destroy();
    end

    tScene.Window.destroy();
    tScene.Skin.destroy();
    tScene.Frame:Show(false);
    tScene.Frame:Destroy();
    _wx.wxYield();
    _wx.wxGetApp():ProcessPendingEvents();
    if (tScene.ViewportBrush) then
        tScene.ViewportBrush:delete();
    end

    tScene.Brush:delete();
    tScene.Pen:delete();
    collectgarbage("collect");
end

--[[!
@fqxn wxLuma.Tests.GameStress.trial
@desc Warms one scene and measures completed native paint batches with 120 Hz
    pacing. Late frame slots are skipped rather than queued for catch-up bursts.
@param table tProfile The workload counts.
@param string sVariant Old or New.
@param number nRound The paired measurement round.
@ret table tResult Measured wall-clock timings and completion statistics.
!]]
local function trial(tProfile, sVariant, nRound)
    local Controls, Window = _Controls, _Window;

    if (sVariant == "Old") then
        Controls, Window = baseline(_pBackup, true);
    elseif (sVariant == "Before") then
        Controls, Window = baseline(_pBefore, false);
    end

    print(string.format("START %s %s round %d", tProfile.Name, sVariant, nRound));
    io.stdout:flush();
    local tScene = createScene(Controls, Window, tProfile, sVariant);
    local tWork  = {};
    local tUi    = {};
    local tGaps  = {};
    local nNext  = BENCH_NOW();
    local nFirst;
    local nLast;
    local nMissWork     = 0;
    local nMissDeadline = 0;
    local nDropped     = 0;
    local nPaintStart;
    local nCallbackStart;
    local nMemoryStart;

    for nFrame = 1, _nWarmFrames + _nFrames do
        if (_bStopped) then
            dispose(tScene);
            error("Benchmark stopped by the user.");
        end

        if (nFrame == _nWarmFrames + 1) then
            collectgarbage("collect");
            nNext          = BENCH_NOW();
            nPaintStart    = tScene.Paints;
            nCallbackStart = tScene.Callbacks;
            nMemoryStart   = collectgarbage("count");
        end

        -- Dispatch native events while pacing. Sleep only the coarse portion;
        -- the high-resolution clock controls the final portion of each period.
        while (BENCH_NOW() < nNext) do
            local nRemaining = nNext - BENCH_NOW();

            if (nRemaining > 2) then
                BENCH_SLEEP(math.floor(nRemaining - 1));
            else
                _wx.wxYield();
            end
        end

        local nStart = BENCH_NOW();
        local nSkipped = math.floor(math.max(0, nStart - nNext) / _nBudget);
        nNext = nNext + nSkipped * _nBudget;
        local nUiMs = update(tScene, nFrame);
        local nEnd  = BENCH_NOW();

        if (nFrame > _nWarmFrames) then
            local nWorkMs = nEnd - nStart;
            tWork[#tWork + 1] = nWorkMs;
            tUi[#tUi + 1]     = nUiMs;
            nDropped = nDropped + nSkipped;

            if (nWorkMs > _nBudget) then
                nMissWork = nMissWork + 1;
            end

            if (nEnd > nNext + _nBudget) then
                nMissDeadline = nMissDeadline + 1;
            end

            if (nLast) then
                tGaps[#tGaps + 1] = nEnd - nLast;
            else
                nFirst = nEnd;
            end

            nLast = nEnd;
        end

        nNext = nNext + _nBudget;
    end

    local tResult = {
        Profile            = tProfile.Name,
        RedrawMode         = BENCH_REDRAW_MODE,
        Variant            = sVariant,
        Round              = nRound,
        Frames             = #tWork,
        Controls           = #tScene.Widgets - (_bViewport and 1 or 0),
        ViewportWidth      = tScene.ViewportWidth or 0,
        ViewportHeight     = tScene.ViewportHeight or 0,
        Particles          = tProfile.Particles,
        ClientWidth        = tScene.Width,
        ClientHeight       = tScene.Height,
        CompletedPaints    = tScene.Paints - nPaintStart,
        Callbacks          = tScene.Callbacks - nCallbackStart,
        Fps                = (#tWork - 1) * 1000 / (nLast - nFirst),
        WorkMedianMs       = percentile(tWork, 0.5),
        WorkP95Ms          = percentile(tWork, 0.95),
        WorkP99Ms          = percentile(tWork, 0.99),
        WorkMaxMs          = percentile(tWork, 1),
        UiMedianMs         = percentile(tUi, 0.5),
        UiP95Ms            = percentile(tUi, 0.95),
        UiP99Ms            = percentile(tUi, 0.99),
        CompletionP95Ms    = percentile(tGaps, 0.95),
        CompletionP99Ms    = percentile(tGaps, 0.99),
        WorkOverBudget     = nMissWork,
        DeadlineMisses     = nMissDeadline,
        DroppedSlots       = nDropped,
        MemoryDeltaKiB     = collectgarbage("count") - nMemoryStart,
        FinalListSelection = tScene.Lists[1].getValue(),
    };
    print(string.format("RESULT %s %s r%d: %.2f paint-batches/s | work median/p95/p99 %.3f/%.3f/%.3f ms | UI median %.3f ms | over-budget %d/%d | deadline misses %d | dropped slots %d",
        tResult.Profile, sVariant, nRound, tResult.Fps, tResult.WorkMedianMs,
        tResult.WorkP95Ms, tResult.WorkP99Ms, tResult.UiMedianMs,
        nMissWork, #tWork, nMissDeadline, nDropped));
    io.stdout:flush();
    dispose(tScene);
    BENCH_SLEEP(250);
    return tResult;
end

--[[!
@fqxn wxLuma.Tests.GameStress.json
@desc Encodes finite benchmark numbers, booleans, strings and ordinary tables.
@param any vValue The value to encode.
@ret string sJson The JSON representation.
!]]
local function json(vValue)
    local zValue = type(vValue);

    if (zValue == "number") then
        assert(vValue == vValue and math.abs(vValue) < math.huge);
        return string.format("%.9g", vValue);
    elseif (zValue == "boolean") then
        return tostring(vValue);
    elseif (zValue == "string") then
        return '"'..vValue:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')..'"';
    end

    assert(zValue == "table", "Unsupported JSON value.");
    local tParts = {};

    if (#vValue > 0) then
        for _, vItem in ipairs(vValue) do
            tParts[#tParts + 1] = json(vItem);
        end

        return "["..table.concat(tParts, ",").."]";
    end

    for sKey, vItem in pairs(vValue) do
        tParts[#tParts + 1] = json(sKey)..":"..json(vItem);
    end

    table.sort(tParts);
    return "{"..table.concat(tParts, ",").."}";
end

print(string.format("CLOCK %.0f Hz | target %.0f Hz | %.6f ms budget | synthetic game logic %.1f ms | timer resolution requested: %s",
    BENCH_CLOCK_FREQUENCY, _nTargetHz, _nBudget, _nGameMs, tostring(BENCH_TIMER_RESOLUTION == 1)));

local _tProfile;

for _, tProfile in ipairs(_tProfiles) do
    if (tProfile.Name == BENCH_PROFILE) then
        _tProfile = tProfile;
    end
end

assert(_tProfile, "Unknown benchmark profile.");
_tResults[1] = trial(_tProfile, BENCH_VARIANT, BENCH_ROUND);
local oFile = assert(io.open(BENCH_RESULT_PATH, "w"));
oFile:write(json({
    RedrawMode        = BENCH_REDRAW_MODE,
    BeforeBaseline    = _pBefore,
    TargetHz          = _nTargetHz,
    FrameBudgetMs     = _nBudget,
    GameLogicMs       = _nGameMs,
    RowsPerList       = #_tItems,
    WarmupFrames      = _nWarmFrames,
    MeasuredFrames    = _nFrames,
    ClockFrequencyHz  = BENCH_CLOCK_FREQUENCY,
    TimerResolutionMs = BENCH_TIMER_RESOLUTION,
    Scope             = "Visible native UI paints plus 2 ms synthetic logic. Game mode separates animated viewport from stable HUD bindings. Desktop/GPU presentation is not measured.",
    Baseline          = _pBackup,
    Trials            = _tResults,
}));
oFile:close();
print("PASS: isolated trial completed. Results: "..BENCH_RESULT_PATH);