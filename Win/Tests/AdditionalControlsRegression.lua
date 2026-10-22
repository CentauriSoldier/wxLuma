--[[!
@fqxn wxLuma.Tests.AdditionalControlsRegression
@desc Exercises native editing, two-handle input, owned notification timers,
    Gregorian dates, path IDs, docking identity and potentiometer continuity.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Luma = require("wxLuma")();
local _Date = require("wxLuma.Core.ControlDateTime");
local _Object = require("wxLuma.Core.ControlObject");
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.AdditionalControlsRegression.check
@desc Counts successful behavior assertions and names failures.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.AdditionalControlsRegression.dispatch
@desc Pumps the actual native timer/paint loop for a bounded interval.
!]]
local function dispatch(oFrame, nMilliseconds)
    local oTimer = _wx.wxTimer(oFrame);
    local nId = oTimer:GetId();
    oFrame:Connect(nId, _wx.wxEVT_TIMER, function() _wx.wxGetApp():ExitMainLoop(); end);
    oTimer:Start(nMilliseconds, true);
    _wx.wxGetApp():MainLoop();
    oFrame:Disconnect(nId, _wx.wxEVT_TIMER);
    oTimer:delete();
end

--[[!
@fqxn wxLuma.Tests.AdditionalControlsRegression.mouse
@desc Delivers a real native event through shared observers and widget input.
!]]
local function mouse(oControl, nType, nX, nY)
    local oEvent = _wx.wxMouseEvent(nType);
    oEvent.GetX = function() return nX; end;
    oEvent.GetY = function() return nY; end;
    oEvent:SetId(oControl:GetId()); oEvent:SetEventObject(oControl);
    oControl:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.AdditionalControlsRegression.run
@desc Covers application state, disabled input, native child events and repeat
    disposal. LuaEx reference scenarios are asserted without loading LuaEx.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local oSkin = _Luma.Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Additional control regression",
        _wx.wxDefaultPosition, _wx.wxSize(820, 700));
    oFrame:Show(true);
    local tOwned = {};

    --[[!
    @fqxn wxLuma.Tests.AdditionalControlsRegression.run.create
    @desc Creates and retains application-owned examples with explicit bounds.
    !]]
    local function fCreate(sFactory, tOptions, nX, nY, nWidth, nHeight, oParent)
        tOptions.Skin = oSkin;
        local oWidget = _Luma.Controls[sFactory](oParent or oFrame, tOptions);
        tOwned[#tOwned + 1] = oWidget;
        oWidget.layout(nX, nY, nWidth, nHeight);
        return oWidget;
    end

    local nTextChanges = 0;
    local oText = fCreate("multilineText", {Value = "first\nsecond", OnChange = function() nTextChanges = nTextChanges + 1; end}, 20, 20, 300, 130);
    check(oText.getValue() == "first\nsecond", "Multiline creation preserves line breaks.");
    oText.setValue("saved\nnotes", true); oText.setValue("saved\nnotes", true);
    check(nTextChanges == 1, "Multiline binding notifications are effective-change only.");
    oText.TextControl:SetValue("typed\ntext");
    check(oText.getValue() == "typed\ntext" and nTextChanges == 2, "Native multiline edits use the same value notifications.");
    oText.setReadOnly(true);
    check(oText.isReadOnly() and not oText.TextControl:IsEditable(), "Read-only policy reaches the native editor.");
    local tTextState = oText.getObjectState(); oText.setReadOnly(false); oText.setValue("changed"); oText.setObjectState(tTextState);
    check(oText.isReadOnly() and oText.getValue() == "typed\ntext", "Multiline state restores text and editing policy.");

    local nRangeChanges = 0;
    local oRange = fCreate("rangeSlider", {Min = 0, Max = 100, Step = 5, Value = {Low = 20, High = 80},
        OnChange = function() nRangeChanges = nRangeChanges + 1; end}, 20, 175, 300, 50);
    oRange.setValue({Low = -5, High = 103}, true);
    check(oRange.getValue().Low == 0 and oRange.getValue().High == 100 and nRangeChanges == 1, "Range clamps both endpoints.");
    check(not pcall(oRange.setValue, {Low = 80, High = 20}) and oRange.getValue().High == 100, "Reversed range input is atomic.");
    oRange.setValue({Low = 20, High = 80});
    -- Alternate thumbs using off-center clicks before dragging. Selecting the
    -- upper thumb must never move the lower endpoint into the upper endpoint.
    oRange.handlePointer("down", 16 + 268 * 0.2, 25); oRange.handlePointer("up", 16 + 268 * 0.2, 25);
    oRange.handlePointer("down", 16 + 268 * 0.8 - 2, 25);
    check(oRange.getValue().Low == 20 and oRange.getValue().High == 80, "Selecting the upper thumb preserves the lower endpoint.");
    oRange.handlePointer("move", 16 + 268 * 0.9, 25); oRange.handlePointer("up", 16 + 268 * 0.9, 25);
    check(oRange.getValue().Low == 20 and oRange.getValue().High == 90, "Dragging the upper thumb after the lower thumb moves only High.");
    oRange.handlePointer("down", 16 + 268 * 0.2 + 2, 25);
    oRange.handlePointer("move", 16 + 268 * 0.3, 25); oRange.handlePointer("up", 16 + 268 * 0.3, 25);
    check(oRange.getValue().Low == 30 and oRange.getValue().High == 90, "Switching back to the lower thumb preserves High.");
    oRange.setValue({Low = 20, High = 80});
    oRange.handlePointer("down", 16 + 268 * 0.2, 25); oRange.handlePointer("move", 500, 25);
    check(oRange.getValue().Low == 80 and oRange.getValue().High == 80, "Lower handle cannot cross upper handle.");
    oRange.handleKey("down", _wx.WXK_ESCAPE);
    check(oRange.getValue().Low == 20 and oRange.getValue().High == 80 and not oRange.Control:HasCapture(), "Escape restores the dragged interval and releases capture.");
    oRange.handleKey("down", _wx.WXK_SPACE); oRange.handleKey("down", _wx.WXK_END);
    check(oRange.getValue().High == 100, "Keyboard handle switching and endpoints work.");
    local tInterval = oRange.getValue(); tInterval.Low = 99;
    check(oRange.getValue().Low == 20, "Interval getters do not alias stored state.");
    local tRangeState = oRange.getObjectState(); oRange.setValue({Low = 0, High = 5}); oRange.setObjectState(tRangeState);
    check(oRange.getValue().Low == 20 and oRange.getValue().High == 100, "Range state round trip restores both handles.");

    local oKnob = fCreate("knob", {Min = 0, Max = 100, Value = 95, Rate = 10}, 350, 20, 180, 180);
    oKnob.increase(); check(oKnob.getValue() == 100 and oKnob.isAtEnd(), "Clamped knob stops at maximum.");
    oKnob.setContinuity("revolve"); oKnob.setValue(120);
    check(oKnob.getValue() == 19, "Revolution matches LuaEx inclusive period 101.");
    oKnob.setRange(10, 20); oKnob.setValue(20); oKnob.setRate(1); oKnob.increase();
    check(oKnob.getValue() == 10, "Inclusive revolution wraps with nonzero minimum.");
    oKnob.decrease(); check(oKnob.getValue() == 20, "Inclusive revolution wraps backward.");
    oKnob.setValue(20.5); check(oKnob.getValue() == 20, "Fractional inclusive seam matches potentiometer behavior.");
    oKnob.setRange(0, 10); oKnob.setContinuity("alternate"); oKnob.setValue(0); oKnob.setMotionDirection(1);
    oKnob.increase(10); check(oKnob.getValue() == 10 and oKnob.getMotionDirection() == 1, "Exact alternating endpoint retains direction.");
    oKnob.increase(); check(oKnob.getValue() == 9 and oKnob.getMotionDirection() == -1, "Overshoot reflects and reverses logical direction.");
    oKnob.increase(3); check(oKnob.getValue() == 6, "Logical increase follows descending direction.");
    oKnob.decrease(2); oKnob.adjust(1);
    check(oKnob.getValue() == 9 and oKnob.getMotionDirection() == -1, "Decrease opposes direction; adjust remains absolute.");
    oKnob.setValue(0); oKnob.setMotionDirection(1); oKnob.increase(25);
    check(oKnob.getValue() == 5 and oKnob.getMotionDirection() == 1, "Multiple reflected crossings preserve direction parity.");
    oKnob.setRange(-2, 2); oKnob.setRate(0.5); oKnob.setValue(1.5); oKnob.setMotionDirection(1); oKnob.increase(2);
    check(oKnob.getValue() == 1.5 and oKnob.getMotionDirection() == -1, "Fractional reflection matches LuaEx guidance.");
    local tKnobState = oKnob.getObjectState(); oKnob.setContinuity("none"); oKnob.setValue(-2); oKnob.setObjectState(tKnobState);
    check(oKnob.getContinuity() == "alternate" and oKnob.getValue() == 1.5 and oKnob.getMotionDirection() == -1, "Knob state preserves continuity and direction.");
    check(not pcall(oKnob.setValue, math.huge) and oKnob.getValue() == 1.5, "Nonfinite knob positions are rejected atomically.");
    oKnob.increase(0); check(oKnob.getValue() == 1.5, "Explicit zero multiplier does not move.");
    oKnob.setRate(-100); check(oKnob.getRate() == 4, "Rate is a magnitude capped to the span.");
    oKnob.setValue(1000000000); check(oKnob.getValue() >= -2 and oKnob.getValue() <= 2, "Large overshoot normalizes without recursive wrapping.");

    check(_Date.days(2000, 2) == 29 and _Date.days(1900, 2) == 28, "Gregorian century leap-year rules.");
    check(_Date.weekday(2024, 2, 29) == 4, "Gregorian calendar weekday is independent of local timezone.");
    for _, sBad in ipairs({"2023-02-29", "2024-13-01", "2024-04-31", "0000-01-01", "2024-2-01"}) do
        check(_Date.parse(sBad, "date") == nil, "Invalid calendar text rejected: "..sBad);
    end
    for _, sBad in ipairs({"24:00", "12:60", "2:10", "-1:30"}) do check(_Date.parse(sBad, "time") == nil, "Invalid 24-hour time rejected: "..sBad); end
    local oDate = fCreate("dateTimePicker", {Value = "2024-02-15", Min = "2024-02-01", Max = "2024-03-01"}, 20, 255, 280, 42);
    local oTime = fCreate("dateTimePicker", {Mode = "time", Value = "23:59"}, 350, 255, 200, 42);
    local oCombined = fCreate("dateTimePicker", {Mode = "datetime", Value = "2024-02-29 23:59"}, 20, 310, 280, 42);
    oDate.TextControl:ChangeValue("2023-02-29");
    check(not oDate.commit() and oDate.getValue() == "2024-02-15" and oDate.TextControl:GetValue() == "2024-02-15", "Invalid typed date restores the accepted value.");
    check(not pcall(oDate.setValue, "2025-01-01") and oDate.getValue() == "2024-02-15", "Out-of-range application dates preserve state.");

    local oPath = fCreate("breadcrumb", {Items = {{Id = "home", Text = "Home"}, {Id = "project", Text = "Project"}, {Id = "assets", Text = "Assets"}}}, 20, 365, 600, 42);
    check(oPath.getValue() == "assets" and #oPath.getPath() == 3, "Breadcrumb defaults to complete path.");
    oPath.handleKey("down", _wx.WXK_LEFT);
    check(oPath.getValue() == "project" and #oPath.getPath() == 2 and #oPath.getItems() == 3, "Ancestor navigation preserves deeper path definitions.");
    local tPathState = oPath.getObjectState(); oPath.setItems({{Id = "home", Text = "Home"}}); oPath.setObjectState(tPathState);
    check(oPath.getValue() == "home", "Missing saved breadcrumb ID is skipped during state restoration.");
    check(not pcall(oPath.setItems, {{Id = "same", Text = "A"}, {Id = "same", Text = "B"}}) and #oPath.getItems() == 1, "Duplicate path definitions are atomic.");

    local oNotice = fCreate("notification", {Value = "Ready", Duration = 30}, 20, 430, 600, 64);
    local nDismissed, sReason = 0;
    oNotice.on("dismissed", function(oSender, tEvent) nDismissed = nDismissed + 1; sReason = tEvent.Reason; end);
    local oDockHost = _wx.wxPanel(oFrame, _wx.wxID_ANY, _wx.wxPoint(450, 510), _wx.wxSize(300, 140));
    local oDock = fCreate("dockablePanel", {Text = "Inspector", Extent = 140}, 0, 0, 300, 140, oDockHost);
    local oDockText = fCreate("textfield", {Value = "retained"}, 10, 8, 200, 36, oDock.Content);
    local nChildId = oDockText.Control:GetId();
    oFrame:Show(true); dispatch(oFrame, 30);

    check(oDate.open(), "Skinned date popup opens within owner bounds.");
    dispatch(oFrame, 20); check(oDate.isOpen(), "Calendar survives native paint/activation delivery.");
    oDate.Calendar.handlePointer("down", 186, 202); oDate.Calendar.handlePointer("up", 186, 202);
    check(oDate.getValue() == "2024-02-29" and not oDate.isOpen(), "Calendar leap-day cell commits and dismisses date mode.");
    oDate.setReadOnly(true); check(not oDate.open(), "Read-only date picker blocks popup edits."); oDate.setReadOnly(false);
    check(oTime.open(), "Time-only popup opens.");
    oTime.Calendar.handlePointer("down", 100, 48); oTime.Calendar.handlePointer("up", 100, 48);
    check(oTime.getValue() == "00:59", "Time action wraps hours without an invalid 24-hour value."); oTime.close();
    check(oCombined.open(), "Combined calendar/time popup opens.");
    oCombined.Calendar.handlePointer("down", 100, 295); oCombined.Calendar.handlePointer("up", 100, 295);
    check(oCombined.getValue() == "2024-02-29 00:59", "Combined time adjustment preserves the selected date."); oCombined.close();
    local tDateState = oDate.getObjectState(); oDate.setValue("2024-03-01"); oDate.setObjectState(tDateState);
    check(oDate.getValue() == "2024-02-29", "ISO value and bounds survive state restoration.");

    -- Leave room for cold native paint work while still crossing the original
    -- deadline before checking that the replacement remains visible.
    oNotice.show("first", "info", 100); dispatch(oFrame, 10);
    oNotice.show("second", "success", 1000); dispatch(oFrame, 150);
    check(oNotice.isShown() and nDismissed == 0 and oNotice.getValue() == "second", "Replacing a notification cancels its old timeout.");
    dispatch(oFrame, 900);
    check(not oNotice.isShown() and nDismissed == 1 and sReason == "timeout", "Native timeout dismisses once.");
    oNotice.show("Persistent", "error", 0); dispatch(oFrame, 35);
    check(oNotice.isShown(), "Zero-duration notification persists.");
    oNotice.handleKey("down", _wx.WXK_ESCAPE); oNotice.dismiss();
    check(nDismissed == 2, "Keyboard and repeated dismissal are changed-only.");
    check(not pcall(oNotice.show, "bad", "invalid", 10) and oNotice.getValue() == "Persistent", "Invalid notification show is atomic.");

    local nObjects = 0; for _ in pairs(_Object.instances()) do nObjects = nObjects + 1; end
    oDock.float(300, 150, true);
    check(oDock.isFloating() and oDockText.Control:GetId() == nChildId and oDockText.getValue() == "retained", "Floating preserves child identity and values.");
    local tDockState = oDock.getObjectState(); oDock.dock("left", true); oDock.setObjectState(tDockState);
    check(oDock.isFloating() and oDockText.Control:GetId() == nChildId, "Floating placement restores using the existing native host.");
    local nObjectsAfter = 0; for _ in pairs(_Object.instances()) do nObjectsAfter = nObjectsAfter + 1; end
    check(nObjectsAfter == nObjects, "Dock state restoration constructs no objects.");
    oDock.dock("right", true);
    local nX, nY = oDock.Control:GetPositionXY();
    check(not oDock.isFloating() and nX == 160 and nY == 0, "Edge docking fits the original owner.");
    oDock.handleKey("down", _wx.WXK_RETURN);
    check(oDock.isFloating(), "Keyboard toggles floating.");
    oDock.handleKey("down", _wx.WXK_ESCAPE);
    check(not oDock.isFloating(), "Escape returns a floating panel to its last dock.");
    oDock.handlePointer("down", 60, 14);
    check(oDock.isFloating() and oDock.Control:HasCapture(), "Dragging the skinned header detaches and captures the pointer.");
    local oEdge = oDockHost:ClientToScreen(_wx.wxPoint(2, 60));
    local oDrop = oDock.Control:ScreenToClient(oEdge);
    oDock.handlePointer("up", oDrop:GetX(), oDrop:GetY());
    oDrop:delete(); oEdge:delete();
    check(not oDock.isFloating() and oDock.getDockState().Side == "left" and not oDock.Control:HasCapture(),
        "Releasing a header drag near the owner edge docks and releases capture.");

    local nEditorClicks = 0;
    oText.on("rightDown", function() nEditorClicks = nEditorClicks + 1; end);
    mouse(oText.TextControl, _wx.wxEVT_RIGHT_DOWN, 8, 8);
    check(nEditorClicks == 1, "Multiline native child forwards physical audio events exactly once.");

    -- All new surfaces retain native audio-event subscriptions and direct draw.
    local oBitmap = _wx.wxBitmap(320, 190); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    for _, oWidget in ipairs({oText, oRange, oKnob, oDate, oPath, oNotice, oDock}) do
        local nClicks = 0;
        oWidget.on("rightDown", function() nClicks = nClicks + 1; end);
        mouse(oWidget.Control, _wx.wxEVT_RIGHT_DOWN, 10, 10);
        check(nClicks == 1, oWidget.Kind.." supports native right-click audio events.");
        oWidget.draw(oDC, 300, oWidget == oKnob and 180 or 60);
        oWidget.setEnabled(false);
        check(not oWidget.handleKey("down", _wx.WXK_END), oWidget.Kind.." rejects disabled keyboard input.");
        oWidget.draw(oDC, 300, oWidget == oKnob and 180 or 60); oWidget.setEnabled(true);
    end
    -- A monochrome test skin isolates needle edge coverage from face shading.
    -- Intermediate channel values therefore prove actual antialiasing.
    local oWhiteImage = _wx.wxImage(1, 1); oWhiteImage:SetRGB(0, 0, 255, 255, 255);
    local oWhiteBitmap = _wx.wxBitmap(oWhiteImage); oWhiteImage:delete();
    local tNeedleBitmaps = {};
    for _, nHalfWidth in ipairs({1, 5}) do
        local tAlpha = {};
        for nY = 0, 31 do
            for nX = 0, 31 do
                tAlpha[#tAlpha + 1] = string.char(nX >= 16 and nX <= 26 and math.abs(nY - 16) <= nHalfWidth and 255 or 0);
            end
        end
        local oImage = _wx.wxImage(32, 32); oImage:SetData(string.rep(string.char(255), 32 * 32 * 3));
        oImage:InitAlpha(); oImage:SetAlpha(table.concat(tAlpha));
        tNeedleBitmaps[#tNeedleBitmaps + 1] = _wx.wxBitmap(oImage); oImage:delete();
    end
    local nNeedleVariant = 1;
    local oBlackBrush = _wx.wxBrush(_wx.wxColour(0, 0, 0));
    local tNeedleSkin = {Font = oSkin.Font};
    --[[!
    @fqxn wxLuma.Tests.AdditionalControlsRegression.run.needleSurface
    @desc Supplies flat black surfaces and a white needle for coverage checks.
    !]]
    function tNeedleSkin.draw(oTarget, sName, nX, nY, nWidth, nHeight)
        if (not sName:find("Focus", 1, true)) then
            oTarget:SetPen(_wx.wxTRANSPARENT_PEN); oTarget:SetBrush(oBlackBrush);
            oTarget:DrawRectangle(nX, nY, nWidth, nHeight);
        end
    end
    tNeedleSkin.getBitmap = function(sName)
        if (sName:find(" Needle ", 1, true)) then return tNeedleBitmaps[nNeedleVariant]; end
        return oWhiteBitmap;
    end;
    local oSmooth = _Luma.Controls.knob(oFrame, {Skin = tNeedleSkin, Value = 37});
    tOwned[#tOwned + 1] = oSmooth;
    oSmooth.draw(oDC, 120, 140);
    --[[!
    @fqxn wxLuma.Tests.AdditionalControlsRegression.run.measureNeedle
    @desc Measures covered area, filtered edges and the light's centroid without
        including value text. A flat black face contributes no covered pixels.
    !]]
    local function fMeasureNeedle()
        local oPixels = oBitmap:ConvertToImage();
        local nPartial, nInk, nXSum, nYSum, nWeight = 0, 0, 0, 0, 0;
        for nY = 5, 110 do
            for nX = 0, 119 do
                local nChannel = oPixels:GetRed(nX, nY);
                if (nChannel > 0) then
                    nInk = nInk + 1;
                    nWeight, nXSum, nYSum = nWeight + nChannel, nXSum + nX * nChannel, nYSum + nY * nChannel;
                    if (nChannel < 255) then nPartial = nPartial + 1; end
                end
            end
        end
        oPixels:delete();
        return nInk, nPartial, nXSum / math.max(1, nWeight), nYSum / math.max(1, nWeight);
    end
    local nThinInk, nPartial = fMeasureNeedle();
    check(nPartial > 10, "Knob needle has partially covered antialiased edge pixels.");
    oSmooth.draw(oDC, 120, 140);
    check(fMeasureNeedle() == nThinInk, "Cached needle paint preserves exact coverage.");
    for _, tCase in ipairs({{0, -1, 1}, {50, 0, -1}, {100, 1, 1}}) do
        oSmooth.setValue(tCase[1]); oSmooth.draw(oDC, 120, 140);
        local nInk, nEdges, nCX, nCY = fMeasureNeedle();
        check((tCase[2] == 0 or (nCX - 60) * tCase[2] > 5) and (nCY - 59) * tCase[3] > 5,
            "Needle image follows the expected dial angle at "..tCase[1]..".");
    end
    oSmooth.destroy(); nNeedleVariant = 2;
    local oWide = _Luma.Controls.knob(oFrame, {Skin = tNeedleSkin, Value = 37});
    oWide.draw(oDC, 120, 140);
    check(fMeasureNeedle() > nThinInk * 2, "Changing only needle skin artwork changes its thickness and silhouette.");
    oWide.destroy();
    for _, oNeedleBitmap in ipairs(tNeedleBitmaps) do oNeedleBitmap:delete(); end
    oWhiteBitmap:delete(); oBlackBrush:delete();
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
    oNotice.show("Dispose before timeout", "warning", 10); oNotice.destroy(); dispatch(oFrame, 25);
    check(nDismissed == 2, "Disposal cancels queued notification work.");
    for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); tOwned[nIndex].destroy(); end
    oFrame:Destroy(); _wx.wxGetApp():Yield(); oSkin.destroy();
    check(package.loaded["LuaEx.load"] == nil, "New controls do not load LuaEx.");
end

run();
print("Additional controls regression: ".._nChecks.." checks passed.");
