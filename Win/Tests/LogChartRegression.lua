--[[!
@fqxn wxLuma.Tests.LogChartRegression
@desc Native log/chart behavior, UTF-8 clipboard payloads, atomic validation,
    event delivery, saved coupled state, hit testing and cached raster output.
    Clipboard transport is recorded locally so the user's clipboard is preserved.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Luma = require("wxLuma")();
local _Options = require("wxLuma.Core.ControlOptions");
local _Object = require("wxLuma.Core.ControlObject");
local _nChecks = 0;
local _oClipboard = _wx.wxTheClipboard;
local _oFrame, _oSkin;
local _tOwned = {};

--[[!
@fqxn wxLuma.Tests.LogChartRegression.check
@desc Counts successful assertions with an actionable failure message.
!]]
local function check(bPassed, sMessage) assert(bPassed, sMessage); _nChecks = _nChecks + 1; end

--[[!
@fqxn wxLuma.Tests.LogChartRegression.upvalue
@desc Finds a private renderer dependency for an independent reference comparison
    without exposing test hooks or native resources through the public API.
!]]
local function upvalue(fTarget, sName)
    for nIndex = 1, 100 do
        local sFound, vValue = debug.getupvalue(fTarget, nIndex);
        if (not sFound) then break; end
        if (sFound == sName) then return vValue, nIndex; end
    end
    error("Missing renderer dependency: "..sName);
end

--[[!
@fqxn wxLuma.Tests.LogChartRegression.layerReference
@desc Retains the full-canvas per-pixel coverage conversion as an independent
    visual reference for cropped native coverage and opacity cache reuse.
!]]
local function layerReference(oDC, oColor, nW, nH, nOpacity, fDraw)
    if (nOpacity <= 0 or oColor:Alpha() == 0) then return; end
    local oMask = _wx.wxBitmap(nW, nH); local oMaskDC = _wx.wxMemoryDC(); oMaskDC:SelectObject(oMask);
    local oBlack = _wx.wxBrush(_wx.wxColour(0, 0, 0)); local oWhite = _wx.wxBrush(_wx.wxColour(255, 255, 255));
    oMaskDC:SetBackground(oBlack); oMaskDC:Clear(); oMaskDC:SetPen(_wx.wxTRANSPARENT_PEN); oMaskDC:SetBrush(oWhite);
    fDraw(oMaskDC); oMaskDC:SelectObject(_wx.wxNullBitmap); oMaskDC:delete();
    local oImage = oMask:ConvertToImage(); oMask:delete(); oBlack:delete(); oWhite:delete();
    local sShades = oImage:GetData():gsub("(.)..", "%1"); local tAlpha = {};
    for nByte = 0, 255 do tAlpha[string.char(nByte)] = string.char(math.floor(nByte * nOpacity * oColor:Alpha() / 255)); end
    local sAlpha = sShades:gsub(".", tAlpha);
    oImage:SetData(string.rep(string.char(oColor:Red(), oColor:Green(), oColor:Blue()), nW * nH));
    oImage:InitAlpha(); oImage:SetAlpha(sAlpha);
    local oFill = _wx.wxBitmap(oImage); oImage:delete(); oDC:DrawBitmap(oFill, 0, 0, true); oFill:delete();
end


--[[!
@fqxn wxLuma.Tests.LogChartRegression.mouse
@desc Dispatches real native mouse events through input and event observers.
!]]
local function mouse(oTarget, nType, nX, nY)
    local oEvent = _wx.wxMouseEvent(nType);
    oEvent.GetX = function() return nX; end; oEvent.GetY = function() return nY; end;
    oEvent:SetId(oTarget:GetId()); oEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.LogChartRegression.dispatch
@desc Runs real native timers and queued paint work for a bounded interval.
!]]
local function dispatch(nMilliseconds)
    local oTimer = _wx.wxTimer(_oFrame); local nId = oTimer:GetId();
    _oFrame:Connect(nId, _wx.wxEVT_TIMER, function() _wx.wxGetApp():ExitMainLoop(); end);
    oTimer:Start(nMilliseconds, true); _wx.wxGetApp():MainLoop();
    _oFrame:Disconnect(nId, _wx.wxEVT_TIMER); oTimer:delete();
end

--[[!
@fqxn wxLuma.Tests.LogChartRegression.run
@desc Exercises full option/data APIs on existing native instances and all chart
    draw paths. Resource cleanup and clipboard restoration run even after errors.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    _oSkin = _Luma.Controls.loadSkin();
    _oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Log/chart regression", _wx.wxDefaultPosition, _wx.wxSize(900, 650));
    _oFrame:Show(true);
    --[[!
    @fqxn wxLuma.Tests.LogChartRegression.run.create
    @desc Retains test components for deterministic repeat-disposal checks.
    !]]
    local function fCreate(sKind, tOptions)
        tOptions.Skin = _oSkin;
        local oWidget = _Luma.Controls[sKind](_oFrame, tOptions);
        _tOwned[#_tOwned + 1] = oWidget; oWidget.layout(10, 10, 420, 290); return oWidget;
    end
    local sCopied;
    _wx.wxTheClipboard = {
        Open = function() return true; end,
        SetData = function(oSelf, oData) sCopied = oData:GetText(); oData:delete(); return true; end,
        Close = function() end,
    };
    local sIcon = _Luma.Path.."/Images/Controls/Control Log Viewer Icon Normal.png";
    local tEntries = {{Id = "one", Text = "First café 雪 ☃", Icon = sIcon, Timestamp = "10:00:00"},
        {Id = "two", Text = "Warning\nsecond line", Severity = "warning", Timestamp = "10:00:01"},
        {Id = "three", Text = "Last action"}};
    local oLog = fCreate("logViewer", {Entries = tEntries});
    check(not oLog.getSeverityEnabled() and oLog.getWrap() and oLog.getAutoScroll(), "Log defaults are plain, wrapping and tail-following.");
    check(oLog.getEntryCount() == 3 and oLog.getVisibleCount() == 3, "Entries and default filters are complete.");
    local tCopy = oLog.getEntries(); tCopy[1].Text = "mutated";
    check(oLog.getEntry("one").Text == tEntries[1].Text, "Log entry getters return independent records.");
    local nChanges, nEntriesChanged, nCopied = 0, 0, 0;
    oLog.on("selectionChanged", function() nChanges = nChanges + 1; end);
    oLog.on("entriesChanged", function() nEntriesChanged = nEntriesChanged + 1; end);
    oLog.on("copied", function() nCopied = nCopied + 1; end);
    oLog.setSelected({"three", "one"}, true); oLog.setSelected({"three", "one"}, true);
    check(nChanges == 1 and oLog.getValue() == "one" and oLog.getSelected()[1] == "one", "Entry selection separates insertion order and primary ID.");
    local bCopied = oLog.copySelected();
    check(bCopied and sCopied == "First café 雪 ☃\nLast action" and nCopied == 1, "Unicode entry selection is copied without losing text.");
    oLog.setTextSelection({Id = "one", Start = 6, Finish = 10}, true); oLog.copySelected();
    check(sCopied == "café", "Text boundaries count UTF-8 characters, not bytes.");
    oLog.setTextSelection({Id = "one", Start = 11, Finish = 14}); oLog.copySelected();
    check(sCopied == "雪 ☃", "Non-Latin and multibyte symbols copy intact.");
    oLog.clearTextSelection(); oLog.setCopyTimestamps(true); oLog.setCopySeverity(true); oLog.setValue("two"); oLog.copySelected();
    check(sCopied == "10:00:01 [warning] Warning\nsecond line", "Optional copy metadata preserves multiline entry text.");
    oLog.setFilterText("last"); check(oLog.getVisibleCount() == 1, "Plain-text filter is case-insensitive by default.");
    oLog.setCaseSensitive(true); check(oLog.getVisibleCount() == 0, "Case-sensitive filtering is available.");
    oLog.setLogOptions({FilterText = "", CaseSensitive = false, SeverityFilter = {"warning"}});
    check(oLog.getVisibleEntries()[1].Id == "two", "Severity filtering is independent of displayed severity.");
    oLog.setSeverityFilter({}); oLog.setSeverityEnabled(true); oLog.setTimestamps(true);
    for sName, vValue in pairs(oLog.getLogOptions()) do
        check(type(oLog["get"..sName]) == "function" and type(oLog["set"..sName]) == "function", "Runtime log setting API: "..sName);
        oLog["set"..sName](vValue);
    end
    local tBefore = oLog.getLogOptions();
    check(not pcall(oLog.setLogOptions, {IconSize = 50, MaxEntries = 0}) and _Options.same(tBefore, oLog.getLogOptions()), "Log option batches validate before mutation.");
    check(not pcall(oLog.setEntries, {{Id = "dup", Text = "A"}, {Id = "dup", Text = "B"}}) and oLog.getEntryCount() == 3, "Duplicate entry IDs cannot partially replace history.");
    check(not pcall(oLog.setEntries, {[1] = {Text = "first"}, [3] = {Text = "hole"}})
        and not pcall(oLog.addEntry, nil), "Sparse entry arrays and missing entry records are rejected.");
    oLog.setEntries(oLog.getEntries(), true); check(nEntriesChanged == 0, "Identical entry replacement is silent.");
    oLog.setEntry("three", {Text = "Changed action"}, true);
    check(oLog.getEntry("three").Text == "Changed action" and nEntriesChanged == 1, "Entry updates preserve stable IDs and notify.");
    oLog.setSelected({"two", "one"}); oLog.setTextSelection({Id = "one", Start = 6, Finish = 10});
    oLog.setEntry("three", {Text = "Another action"}, true);
    check(oLog.getValue() == "one" and oLog.getSelectedText() == "café", "Unrelated entry mutations preserve primary and substring selection.");
    local tLogState = oLog.getObjectState();
    oLog.clear(); oLog.setWrap(false); oLog.setObjectState(tLogState);
    check(oLog.getEntryCount() == 3 and oLog.getWrap() and oLog.getValue() == "one" and #oLog.getSelected() == 2
        and oLog.getSelectedText() == "café", "Log state preserves entries, options, primary/multiple selection and text selection.");
    oLog.setMaxEntries(3); oLog.addEntries({{Id = "four", Text = "four"}, {Id = "five", Text = "five"}}, true);
    check(oLog.getEntryCount() == 3 and not oLog.getEntry("one") and not oLog.getEntry("two"), "Bounded history trims oldest entries in one append batch.");
    check(oLog.getTextSelection() == false and #oLog.getSelected() == 0, "Trimmed entries leave no stale text/entry selection.");
    oLog.setMaxEntries(2000); oLog.clear();
    local tMany = {}; for nIndex = 1, 1000 do tMany[nIndex] = {Id = "row-"..nIndex, Text = "Entry "..nIndex.." with enough text to measure"}; end
    oLog.addEntries(tMany); oLog.scrollToEnd(); local nX, nTail = oLog.getPosition();
    local fClientDC = _wx.wxClientDC;
    local nMeasures = 0;
    _wx.wxClientDC = function(oControl)
        local oDC = fClientDC(oControl); local fMeasure = oDC.GetTextExtent;
        oDC.GetTextExtent = function(oTarget, ...)
            nMeasures = nMeasures + 1; return fMeasure(oTarget, ...);
        end;
        return oDC;
    end;
    local bMeasured, sMeasureError = pcall(function()
        oLog.addEntry({Id = "cached", Text = "Entry 1001 with enough text to measure"}); oLog.getContentSize();
    end);
    _wx.wxClientDC = fClientDC; assert(bMeasured, sMeasureError);
    check(nMeasures <= 4, "Appending to a 1000-entry log does not remeasure unchanged entry layouts.");
    check(nTail > 0 and oLog.isFollowingTail(), "A full log can follow its tail.");
    oLog.scrollToStart(); oLog.addEntry("Do not jump while reading old entries"); local nUnused, nY = oLog.getPosition();
    check(nY == 0 and not oLog.isFollowingTail(), "Appending preserves a user-scrolled viewport.");
    oLog.scrollToEnd(); oLog.addEntry("Follow new entries"); nUnused, nY = oLog.getPosition();
    check(nY > nTail and oLog.isFollowingTail(), "Explicit following resumes append scrolling.");
    oLog.setWrap(false); oLog.setEntry("row-1", {Text = string.rep("wide text ", 100)}); oLog.scrollToStart(); oLog.scrollBy(200, 0);
    nX = oLog.getPosition(); check(nX == 200, "Unwrapped content supports horizontal scrolling.");
    oLog.setWrap(true); oLog.scrollToEntry("row-500");
    local tRect = oLog.getEntryRect("row-500"); local tHit = oLog.hitTest(tRect.TextX + 2, math.max(0, tRect.Y) + 8);
    check(tHit and tHit.Id == "row-500", "Hit testing finds a middle entry without scanning visible history.");
    local nHover, nRight = 0, 0;
    oLog.on("entryHovered", function() nHover = nHover + 1; end); oLog.on("rightDown", function() nRight = nRight + 1; end);
    mouse(oLog.Control, _wx.wxEVT_MOTION, tRect.TextX + 2, 8); mouse(oLog.Control, _wx.wxEVT_RIGHT_DOWN, 20, 8);
    check(nHover == 1 and nRight == 1, "Log exposes semantic hover and native right-click audio hooks.");
    oLog.handlePointer("down", tRect.TextX + 1, 8); oLog.handlePointer("move", tRect.TextX + 65, 8); oLog.handlePointer("up", tRect.TextX + 65, 8);
    check(oLog.getTextSelection() and oLog.getTextSelection().Finish > oLog.getTextSelection().Start, "Actual pointer dragging selects entry text.");
    oLog.scrollToEnd(); oLog.setValue("row-501");
    check(not oLog.isFollowingTail(), "Selecting text/entries pauses automatic tail motion by default.");
    oLog.setFollowingTail(true); local tFollowingState = oLog.getObjectState(); oLog.setFollowingTail(false); oLog.setObjectState(tFollowingState);
    check(oLog.isFollowingTail() and oLog.getValue() == "row-501", "Explicit following and retained selection restore together.");
    oLog.scrollToEntry("row-500"); tRect = oLog.getEntryRect("row-500");
    oLog.handlePointer("down", tRect.TextX + 1, 8); oLog.handlePointer("move", tRect.TextX + 30, 8);
    oLog.addEntry("Unrelated append during selection");
    check(oLog.Control:HasCapture(), "Appending an unrelated action preserves an active text-selection drag.");
    oLog.handlePointer("move", tRect.TextX + 70, 8); oLog.handlePointer("up", tRect.TextX + 70, 8);
    oLog.setEnabled(false); check(not oLog.handleKey("down", _wx.WXK_DOWN), "Disabled log ignores keyboard input."); oLog.setEnabled(true);

    local tSeries = {{Id = "a", Text = "Alpha", Points = {{Id = "p", X = 1, Y = 2}, {Id = "q", X = 2, Y = 5}, {Id = "r", X = 3, Y = 3}}},
        {Id = "b", Text = "Beta", Points = {{Id = "p", X = 1, Y = 4}, {Id = "q", X = 2, Y = 1}, {Id = "r", X = 3, Y = 6}}}};
    local oChart = fCreate("lineChart", {Series = tSeries, Title = "Test", XLabel = "X", YLabel = "Y"});
    check(oChart.getType() == "line" and oChart.getLegend() and oChart.getZoomEnabled(), "Chart defaults expose ordinary interaction options.");
    local tIndependent = oChart.getSeries(); tIndependent[1].Points[1].Y = 999;
    check(oChart.getPoint("a", "p").Y == 2, "Chart data getters do not expose live arrays.");
    local nData, nView, nSelected, nOptions = 0, 0, 0, 0;
    oChart.on("dataChanged", function() nData = nData + 1; end); oChart.on("viewChanged", function() nView = nView + 1; end);
    oChart.on("selectionChanged", function() nSelected = nSelected + 1; end); oChart.on("optionsChanged", function() nOptions = nOptions + 1; end);
    oChart.setSeries(tSeries, true); check(nData == 0, "Identical series data is silent.");
    oChart.setValue({Series = "a", Point = "p"}, true); oChart.setValue({Series = "a", Point = "p"}, true);
    check(nSelected == 1, "Point selection notifies actual changes only.");
    oChart.setLineWidth(4, true); oChart.setLineWidth(4, true);
    check(nOptions == 1, "Generated option setters notify once per effective change.");
    local tChartOptions = oChart.getChartOptions();
    for sName, vValue in pairs(tChartOptions) do
        check(type(oChart["get"..sName]) == "function" and type(oChart["set"..sName]) == "function", "Runtime chart setting API: "..sName);
        oChart["set"..sName](vValue);
    end
    check(not pcall(oChart.setMarkerSize, nil) and not pcall(oLog.setWrap, nil), "Required setting setters reject nil rather than silently doing nothing.");
    check(not pcall(oChart.setChartOptions, {MarkerSize = 30, HoleSize = 1}) and _Options.same(tChartOptions, oChart.getChartOptions()), "Chart option batches are atomic.");
    check(not pcall(oChart.setSeries, {{Id = "x", Points = {{Y = 0 / 0}}}}) and oChart.getPoint("a", "p").Y == 2, "Nonfinite chart data cannot corrupt an existing plot.");
    check(not pcall(oChart.setSeries, {{Points = false}}) and not pcall(oChart.setSeries, {{Points = {{X = false, Y = 2}}}})
        and not pcall(oChart.setSeries, {{Id = false, Points = {}}}), "Invalid explicit chart fields are not treated as omitted defaults.");
    oChart.setXRange({Min = 0, Max = 10}); check(nView == 0, "Programmatic view changes default to silent.");
    oChart.resetView(); local tView = oChart.getViewRange();
    oChart.zoom(0.5, nil, nil, true); local tZoom = oChart.getViewRange();
    check(math.abs(tZoom.XMax - tZoom.XMin - (tView.XMax - tView.XMin) / 2) < 1e-9 and nView == 1, "Zoom changes ranges and emits viewChanged.");
    oChart.pan(1, 2); local tPan = oChart.getViewRange();
    check(math.abs(tPan.XMin - tZoom.XMin - 1) < 1e-9 and math.abs(tPan.YMin - tZoom.YMin - 2) < 1e-9, "Panning uses explicit data coordinates.");
    oChart.resetView(); local nPX, nPY = oChart.getPointPosition("a", "q"); local tPointHit = oChart.hitTest(nPX, nPY);
    check(tPointHit and tPointHit.Series == "a" and tPointHit.Point == "q", "Point geometry and hit testing agree.");
    local nClicked, nPointHover = 0, 0;
    oChart.on("pointClicked", function() nClicked = nClicked + 1; end); oChart.on("pointHovered", function() nPointHover = nPointHover + 1; end);
    mouse(oChart.Control, _wx.wxEVT_MOTION, nPX, nPY); mouse(oChart.Control, _wx.wxEVT_LEFT_DOWN, nPX, nPY); mouse(oChart.Control, _wx.wxEVT_LEFT_UP, nPX, nPY);
    check(nClicked == 1 and nPointHover == 1 and oChart.getValue().Point == "q", "Native chart clicks select and emit point events.");
    oChart.addPoint("a", {Id = "s", X = 4, Y = 8}, true); oChart.setPoint("a", "s", {X = 4, Y = 7}, true);
    check(oChart.getPoint("a", "s").Y == 7, "Points can be appended and edited by identity.");
    oChart.setMaxPoints(2);
    check(#oChart.getSeries("a").Points == 2 and not oChart.getPoint("a", "p"), "Changing point history limit trims immediately.");
    oChart.removePoint("a", "s"); check(not oChart.getPoint("a", "s"), "Point removal retains remaining data.");
    oChart.setSeriesVisible("b", false, true); check(not oChart.getSeries("b").Visible, "Series visibility is mutable.");
    oChart.setSeries(tSeries); oChart.setMaxPoints(10000); oChart.setSeries(tSeries);
    local nBatch = nData;
    oChart.addPoints("a", {{Y = 8}, {Y = 9}}, true);
    check(nData == nBatch + 1 and #oChart.getSeries("a").Points == 5 and oChart.getPoint("a", "point-2").X == 5,
        "Point batches commit once and assign independent stable IDs/X positions.");
    oChart.setSeries(tSeries);
    oChart.setChartOptions({XScale = "log", YScale = "log"});
    local tLogBounds = oChart.getViewRange(); check(tLogBounds.XMin > 0 and tLogBounds.YMin > 0, "Log axes have positive automatic bounds.");
    check(not pcall(oChart.addPoint, "a", {Y = 0}) and #oChart.getSeries("a").Points == 3, "Log axes reject invalid values before appending.");
    local tSaved = oChart.getObjectState();
    oChart.setChartOptions({XScale = "linear", YScale = "linear", Type = "bar"});
    oChart.setSeries({{Id = "negative", Points = {{X = 1, Y = -5}}}});
    local nBeforeObjects = 0; for _ in pairs(_Object.instances()) do nBeforeObjects = nBeforeObjects + 1; end
    oChart.setObjectState(tSaved);
    local nAfterObjects = 0; for _ in pairs(_Object.instances()) do nAfterObjects = nAfterObjects + 1; end
    check(oChart.getType() == "line" and oChart.getXScale() == "log" and oChart.getPoint("a", "p") and nBeforeObjects == nAfterObjects,
        "Coupled options/data restore across incompatible live modes without constructing objects.");
    oChart.setChartOptions({XScale = "linear", YScale = "linear", Type = "bar", Stacked = true});
    oChart.setSeries({{Id = "a", Points = {{X = 1, Y = 3}, {X = 2, Y = -2}}}, {Id = "b", Points = {{X = 1, Y = 4}, {X = 2, Y = -5}}}});
    local tBounds = oChart.getDataBounds(); check(tBounds.YMax == 7 and tBounds.YMin == -7, "Stacked bar bounds include signed cumulative sums.");
    check(not pcall(oChart.setType, "pie") and oChart.getType() == "bar", "Negative slices are rejected atomically on mode changes.");
    oChart.setSeries({{Id = "a", Points = {{X = 1, Y = 3}}}, {Id = "b", Points = {{X = 1, Y = 4}}}});
    oChart.setYScale("log"); tBounds = oChart.getDataBounds();
    check(tBounds.YMax == 7 and tBounds.YMin < 3, "Log stacks keep true cumulative values with a positive display floor.");
    check(not pcall(oChart.setBaseline, -1) and oChart.getBaseline() == 0, "Invalid logarithmic fill baselines are rejected atomically.");
    oChart.setChartOptions({YScale = "linear", Stacked = false});
    oChart.setSeries(tSeries); oChart.setType("donut"); oChart.setHoleSize(0.6); oChart.setSliceGap(6);
    local tPlot = oChart.getPlotRect();
    check(not oChart.hitTest(tPlot.X + tPlot.Width / 2, tPlot.Y + tPlot.Height / 2), "Donut hole never selects a slice.");
    nPX, nPY = oChart.getPointPosition("a", "p"); check(oChart.hitTest(nPX, nPY).Point == "p", "Donut slice centers remain selectable.");
    oChart.setSeries({{Id = "zero", Points = {{Y = 0}, {Y = 0}}}}); check(oChart.getDataBounds().Empty == false, "Zero-valued pie data remains valid.");
    oChart.setType("line"); oChart.setSeries({}); check(oChart.getDataBounds().Empty, "Empty charts expose an explicit empty state.");
    oChart.setTooltips(false);
    local tNoTooltip = oChart.getObjectState(); oChart.setTooltips(true); oChart.setObjectState(tNoTooltip);
    check(not oChart.getTooltips() and not oChart.Tooltip.isEnabled(), "Tooltip availability survives chart and child state restoration.");

    local oBitmap = _wx.wxBitmap(450, 320); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    oLog.setLogOptions({Transparent = true, FilterText = "", SeverityFilter = {}, AutoScroll = false}); oLog.draw(oDC, 420, 290);
    local tDrawData = {{Id = "a", Points = {{Id = "p", X = 1, Y = 2}, {Id = "q", X = 2, Y = 5}, {Id = "r", X = 3, Y = 3}}}};
    for _, sType in ipairs({"line", "area", "bar", "scatter", "pie", "donut"}) do
        oChart.setType(sType); oChart.setSeries(tDrawData); oChart.setChartOptions({ValueLabels = true, LegendPosition = "right", Supersampling = 2});
        for _, bEnabled in ipairs({true, false}) do
            oChart.setEnabled(bEnabled); oChart.draw(oDC, 420, 290);
            local oFirst = oBitmap:ConvertToImage(); local sFirst = oFirst:GetData(); oFirst:delete();
            oChart.draw(oDC, 420, 290); local oSecond = oBitmap:ConvertToImage();
            check(sFirst == oSecond:GetData(), sType.." repeated rendering preserves exact cached pixels."); oSecond:delete();
        end
    end
    oChart.setEnabled(true); oChart.setType("area"); oChart.setSeries(tDrawData); oChart.setAreaOpacity(0.1); oChart.draw(oDC, 420, 290);
    local oFaint = oBitmap:ConvertToImage(); local sFaint = oFaint:GetData(); oFaint:delete();
    oChart.setAreaOpacity(0.8); oChart.draw(oDC, 420, 290); local oOpaque = oBitmap:ConvertToImage();
    check(sFaint ~= oOpaque:GetData(), "Area opacity changes actual composited plot pixels."); oOpaque:delete();
    oChart.setType("bar"); oChart.setOrientation("horizontal"); oChart.setStacked(true); oChart.draw(oDC, 420, 290);
    oChart.setOrientation("vertical"); oChart.setInterpolation("step"); oChart.setType("line"); oChart.draw(oDC, 420, 290);
    oChart.setChartOptions({Title = "", Subtitle = "", Legend = false, Axes = false, Grid = false, TickLabels = false,
        Markers = false, ValueLabels = false, XRange = {Min = 0, Max = 4}, YRange = {Min = 0, Max = 7}});
    for _, sType in ipairs({"line", "area", "bar", "scatter", "pie"}) do
        oChart.setType(sType); oChart.setMarkers(sType == "scatter");
        oChart.setSeries({{Id = "alpha", Color = {R = 255, G = 50, B = 20, A = 0}, Points = {{X = 1, Y = 2}, {X = 2, Y = 5}, {X = 3, Y = 3}}}});
        oChart.draw(oDC, 420, 290); local oTransparent = oBitmap:ConvertToImage(); local sTransparent = oTransparent:GetData(); oTransparent:delete();
        local tOpaque = oChart.getSeries(); tOpaque[1].Color.A = 255; oChart.setSeries(tOpaque); oChart.draw(oDC, 420, 290);
        local oSolid = oBitmap:ConvertToImage(); check(sTransparent ~= oSolid:GetData(), sType.." honors series alpha in actual rendered pixels."); oSolid:delete();
    end
    -- Compare the optimized paths with independent full-canvas compositing.
    -- The reference stays inside this test and never changes production APIs.
    local fRender = upvalue(oChart.draw, "fRender");
    local fPart = upvalue(fRender, "fPart");
    local fLayer, nLayerIndex = upvalue(fRender, "fLayer");
    local fComposite, nCompositeIndex = upvalue(fPart, "fComposite");
    --[[!
    @fqxn wxLuma.Tests.LogChartRegression.run.referenceComposite
    @desc Uses direct native full-destination alpha blending as the pixel oracle.
    !]]
    local function fReferenceComposite(oTarget, oPart, nX, nY)
        oTarget:DrawBitmap(oPart, math.floor(nX), math.floor(nY), true);
    end
    --[[!
    @fqxn wxLuma.Tests.LogChartRegression.run.pixels
    @desc Captures a clean destination so clipped/offscreen differences cannot
        hide behind a previous render. The caller owns no returned native handle.
    !]]
    local function fPixels(nW, nH)
        oDC:SetBackground(_wx.wxBLACK_BRUSH); oDC:Clear();
        oChart.draw(oDC, nW, nH);
        local oImage = oBitmap:ConvertToImage(); local sPixels = oImage:GetData(); oImage:delete(); return sPixels;
    end
    for _, sType in ipairs({"line", "area", "bar", "scatter", "pie", "donut"}) do
        for nScale = 1, 3 do
            oChart.setChartOptions({Type = sType, Supersampling = nScale, AreaOpacity = 0.37, LineWidth = 3,
                LineStyle = nScale == 2 and "dash" or "dot", Interpolation = nScale == 3 and "step" or "linear",
                Markers = true, MarkerSize = 19, SliceGap = 4, HoleSize = 0.43, Grid = true,
                Orientation = nScale == 3 and "horizontal" or "vertical", XRange = {Min = 1.5, Max = 2.5}, YRange = {Min = 0, Max = 7}});
            local tReferenceData = {{Id = "alpha", Color = {R = 185, G = 40, B = 70, A = 137},
                Points = {{X = 1, Y = 2}, {X = 2, Y = 5}, {X = 3, Y = 3}}}};
            oChart.setSeries(tReferenceData);
            debug.setupvalue(fRender, nLayerIndex, layerReference);
            debug.setupvalue(fPart, nCompositeIndex, fReferenceComposite);
            oChart.setFormatter("Value", nil);
            local sReference = fPixels(420, 290);
            debug.setupvalue(fRender, nLayerIndex, fLayer);
            debug.setupvalue(fPart, nCompositeIndex, fComposite);
            oChart.setFormatter("Value", nil);
            check(sReference == fPixels(420, 290), sType.." cropped alpha and artwork match the full-canvas reference at scale "..nScale..".");
        end
    end
    oChart.setChartOptions({Type = "area", Supersampling = 2, LineStyle = "solid", Interpolation = "linear", AreaOpacity = 0.1});
    oChart.setSeries(tDrawData); fPixels(420, 290);
    local tPreviousGeometry = upvalue(fRender, "tGeometry");
    local tPreviousCoverage = upvalue(fLayer, "tLayerShapes");
    local tFirstCoverage = tPreviousCoverage[1];
    for _, nOpacity in ipairs({0, 0.25, 1, 0.6}) do
        oChart.setAreaOpacity(nOpacity); local sReused = fPixels(420, 290);
        check(tFirstCoverage ~= nil and upvalue(fRender, "tGeometry") == tPreviousGeometry and upvalue(fLayer, "tLayerShapes")[1] == tFirstCoverage,
            "Opacity slider reuses existing layout and native polygon coverage, including zero opacity.");
        debug.setupvalue(fRender, nLayerIndex, layerReference);
        oChart.setFormatter("Value", nil); local sReference = fPixels(420, 290);
        debug.setupvalue(fRender, nLayerIndex, fLayer);
        check(sReference == sReused, "Reused opacity coverage preserves exact full-canvas reference pixels.");
        oChart.setFormatter("Value", nil); oChart.setAreaOpacity(0.1); fPixels(420, 290);
        tPreviousGeometry = upvalue(fRender, "tGeometry");
        tFirstCoverage = upvalue(fLayer, "tLayerShapes")[1];
    end
    for _, tChange in ipairs({{Interpolation = "step"}, {Baseline = 1}, {Supersampling = 3},
        {XRange = {Min = 0, Max = 4}}, {Padding = {Left = 32, Right = 15, Top = 20, Bottom = 36}}}) do
        oChart.setChartOptions(tChange); local sChanged = fPixels(317, 213);
        debug.setupvalue(fRender, nLayerIndex, layerReference);
        oChart.setFormatter("Value", nil); local sReference = fPixels(317, 213);
        debug.setupvalue(fRender, nLayerIndex, fLayer);
        check(sChanged == sReference, "Shape, view, padding and size changes invalidate cached coverage correctly.");
    end
    local tManySeries = {};
    for nIndex = 1, 12 do tManySeries[nIndex] = {Id = "coverage-"..nIndex, Points = {{Y = 2}, {Y = 4}, {Y = 3}}}; end
    oChart.setSeries(tManySeries); fPixels(317, 213);
    local nCoverage = 0; for _ in pairs(upvalue(fLayer, "tLayerShapes")) do nCoverage = nCoverage + 1; end
    check(nCoverage == 8, "Native coverage cache remains bounded with many translucent series.");
    oChart.setType("line"); oChart.setSeries(tDrawData);
    oChart.setChartOptions({TickLabels = true, Precision = 0, AutoPrecision = true, XRange = {Min = 1, Max = 4}, YRange = {Min = 0, Max = 48}});
    local tTickPlot = oChart.getPlotRect(); local tTickText, nTickText = {}, 0; local fDrawText = oDC.DrawText;
    oDC.DrawText = function(oTarget, sText, nX, nY)
        if (math.abs(nY - (tTickPlot.Y + tTickPlot.Height + 3)) < 0.5) then tTickText[sText] = true; nTickText = nTickText + 1; end
        return fDrawText(oTarget, sText, nX, nY);
    end;
    oChart.draw(oDC, 420, 290); oDC.DrawText = fDrawText;
    local nDistinct = 0; for _ in pairs(tTickText) do nDistinct = nDistinct + 1; end
    check(nTickText == 5 and nDistinct == 5, "Axis labels retain distinct fractional tick values even with integer value precision.");
    oChart.setChartOptions({Tooltips = true, TooltipDelay = 500});
    nPX, nPY = oChart.getPointPosition("a", "q");
    oChart.handlePointer("leave", -1, -1); oChart.handlePointer("move", nPX, nPY);
    check(not oChart.Tooltip.isShown(), "Point tooltips honor their delay.");
    oChart.handlePointer("leave", -1, -1); dispatch(40);
    check(not oChart.Tooltip.isShown(), "Leaving cancels pending point tooltips.");
    oChart.setTooltipDelay(0); oChart.handlePointer("move", nPX, nPY);
    check(oChart.Tooltip.isShown(), "Zero tooltip delay shows immediately for a real point.");
    oChart.setTooltips(false); check(not oChart.Tooltip.isShown(), "Disabling tooltips hides current content and cancels timers.");
    oChart.setChartOptions({Tooltips = true, TooltipDelay = 30}); oChart.handlePointer("leave", -1, -1);
    oChart.handlePointer("move", nPX, nPY); dispatch(150);
    check(oChart.Tooltip.isShown(), "A real native tooltip timer shows the hovered point after its delay.");
    oChart.setTooltips(false);
    oChart.setSeries({{Id = "outlier", Points = {{X = -1e90, Y = -1e90}, {X = 1e90, Y = 1e90}}}});
    oChart.setViewRange(-1, 1, -1, 1); oChart.draw(oDC, 420, 290); check(true, "Extreme offscreen data stays within safe native drawing coordinates.");
    oChart.setEnabled(false); check(not oChart.handleKey("down", _wx.WXK_RIGHT), "Disabled chart ignores selection gestures.");
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();

    local oSwitch = fCreate("switch", {}); local nSwitchEvents = 0;
    oSwitch.on("orientationChanged", function() nSwitchEvents = nSwitchEvents + 1; end);
    oSwitch.on("reversedChanged", function() nSwitchEvents = nSwitchEvents + 1; end);
    oSwitch.setOrientation("vertical", true); oSwitch.setOrientation("vertical", true); oSwitch.setReversed(true, true);
    check(nSwitchEvents == 2, "Previous switch batch now exposes changed-only orientation/reversal events.");
    for _, oWidget in ipairs({oLog, oChart}) do
        oWidget.destroy(); oWidget.destroy();
        check(not pcall(oWidget.setValue, nil), oWidget.Kind.." rejects mutation after repeat-safe disposal.");
    end
end

local bOK, sError = xpcall(run, debug.traceback);
_wx.wxTheClipboard = _oClipboard;
for nIndex = #_tOwned, 1, -1 do pcall(_tOwned[nIndex].destroy); end
if (_oFrame) then _oFrame:Destroy(); _wx.wxGetApp():Yield(); end
if (_oSkin) then _oSkin.destroy(); end
assert(bOK, sError);
print("Log/chart regression: ".._nChecks.." checks passed.");
