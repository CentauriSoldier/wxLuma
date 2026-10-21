--[[!
@fqxn wxLuma.Tests.DisplayContainersRegression
@desc Exercises the new display/container objects against the native wxLua build,
    including rendering, event subscriptions, range changes and workbench pages.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path  = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";

local _wx       = require("wx");
local _pFramework = require("wxLuma")().Config.ImagePath;
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.DisplayContainersRegression.check
@desc Counts assertions and reports the failed behavior precisely.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.DisplayContainersRegression.run
@desc Runs native control checks, then opens both new workbench categories.
!]]
local function run()
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma display/container checks",
        _wx.wxDefaultPosition, _wx.wxSize(900, 700));
    local oSkin = _Controls.loadSkin();
    local oLabel = _Controls.label(oFrame, {
        Skin = oSkin, Value = "one two three four five six seven eight nine ten", Wrap = true
    });
    local pImage = _pFramework.."/Window/Window Ornament Upper Left.png";
    local oImage = _Controls.image(oFrame, {Skin = oSkin, Value = pImage});
    local oScroll = _Controls.scrollContainer(oFrame, {
        Skin = oSkin, ContentWidth = 1200, ContentHeight = 1000
    });
    local nChildClicks = 0;
    local oChild = _Controls.button(oScroll.Content, {
        Skin = oSkin, Text = "Child action",
        OnClick = function()
            nChildClicks = nChildClicks + 1;
        end
    });
    oLabel.layout(10, 10, 300, 120);
    oImage.layout(330, 10, 200, 120);
    oScroll.layout(10, 150, 600, 450);
    oChild.layout(900, 880, 200, 40);
    oFrame:Show(true);
    _wx.wxYield();

    for _, oComponent in ipairs({oLabel, oImage, oScroll}) do
        check(next(oComponent) == nil, "Public object must be an empty decoy.");
        check(getmetatable(oComponent) == "wxLuma.UI."..oComponent.Kind, "Proxy identity.");
    end

    local nWideWidth, nWideHeight = oLabel.measure();
    oLabel.layout(10, 10, 100, 120);
    local nNarrowWidth, nNarrowHeight = oLabel.measure();
    check(nWideWidth > nNarrowWidth and nNarrowHeight > nWideHeight, "Label wraps after resize.");
    oLabel.setAlignment("right", "bottom");
    check(not pcall(oLabel.setAlignment, "bad", "top"), "Reject invalid alignment.");
    local nNotifications = 0;
    local fChanged = function(oSource, tEvent)
        check(oSource == oLabel and tEvent.Source == oLabel, "Event source is the proxy.");
        check(tEvent.Name == "valueChanged" and tEvent.OldValue ~= tEvent.Value, "Event snapshot.");
        nNotifications = nNotifications + 1;
    end;
    oLabel.on("valueChanged", fChanged).on("valueChanged", fChanged);
    oLabel.setValue("silent");
    check(nNotifications == 0, "Setters default to silent.");
    oLabel.setValue("changed", true);
    oLabel.setValue("changed", true);
    check(nNotifications == 1, "Deduplicated subscriptions and unchanged-value suppression.");
    oLabel.off("valueChanged", fChanged);
    oLabel.setValue("removed", true);
    check(nNotifications == 1, "Removed subscription stays removed.");
    local nEnabled = 0;
    oLabel.on("enabledChanged", function()
        nEnabled = nEnabled + 1;
    end);
    oLabel.setEnabled(false);
    oLabel.setEnabled(false);
    oLabel.setEnabled(true);
    check(nEnabled == 2, "Enable notifications only report transitions.");

    -- Dispatch native mouse events through the real handler chain. Observers
    -- must preserve the shared surface's press/capture behavior.
    local nLeftClicks, nRightClicks, nMoves = 0, 0, 0;
    oLabel.on("leftClick", function()
        nLeftClicks = nLeftClicks + 1;
    end);
    oLabel.on("rightClick", function()
        nRightClicks = nRightClicks + 1;
    end);
    oLabel.on("pointerMove", function(oSource, tEvent)
        check(tEvent.X == 0 and tEvent.Y == 0, "Mouse coordinates.");
        nMoves = nMoves + 1;
    end);

    local function fMouse(oTarget, nType, nX, nY)
        local jEvent = _wx.wxMouseEvent(nType);
        -- wxLua exposes mouse coordinates as read-only properties. Override
        -- accessors on this native fixture to supply the requested coordinates.
        jEvent.GetX = function()
            return nX or 0;
        end;
        jEvent.GetY = function()
            return nY or 0;
        end;
        jEvent:SetEventObject(oTarget);
        jEvent:SetId(oTarget:GetId());
        oTarget:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end

    fMouse(oLabel.Control, _wx.wxEVT_LEFT_DOWN);
    check(oLabel.Pressed and oLabel.Control:HasCapture(), "Observer preserves native press/capture.");
    fMouse(oLabel.Control, _wx.wxEVT_LEFT_UP);
    check(not oLabel.Pressed and not oLabel.Control:HasCapture(), "Native release/capture cleanup.");
    fMouse(oLabel.Control, _wx.wxEVT_RIGHT_DOWN);
    fMouse(oLabel.Control, _wx.wxEVT_RIGHT_UP);
    fMouse(oLabel.Control, _wx.wxEVT_MOTION);
    check(nLeftClicks == 1 and nRightClicks == 1 and nMoves == 1, "Native pointer notifications: "..nLeftClicks..","..nRightClicks..","..nMoves);

    -- Cancellation must discard old button-down state across disable/enable.
    fMouse(oLabel.Control, _wx.wxEVT_RIGHT_DOWN);
    oLabel.setEnabled(false);
    oLabel.setEnabled(true);
    fMouse(oLabel.Control, _wx.wxEVT_RIGHT_UP);
    check(nRightClicks == 1, "Disable cancels incomplete clicks.");
    local tSeen = {};

    for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "middleClick",
        "leftDoubleClick", "rightDoubleClick", "middleDoubleClick", "keyDown",
        "keyUp", "character", "contextMenu", "mouseWheel"}) do
        oLabel.on(sEvent, function(oSource, tEvent)
            tSeen[tEvent.Name] = (tSeen[tEvent.Name] or 0) + 1;
        end);
    end

    for _, nType in ipairs({_wx.wxEVT_ENTER_WINDOW, _wx.wxEVT_LEAVE_WINDOW,
        _wx.wxEVT_MIDDLE_DOWN, _wx.wxEVT_MIDDLE_UP, _wx.wxEVT_LEFT_DCLICK,
        _wx.wxEVT_RIGHT_DCLICK, _wx.wxEVT_MIDDLE_DCLICK, _wx.wxEVT_MOUSEWHEEL}) do
        fMouse(oLabel.Control, nType);
    end

    for _, nType in ipairs({_wx.wxEVT_KEY_DOWN, _wx.wxEVT_KEY_UP, _wx.wxEVT_CHAR}) do
        local jEvent = _wx.wxKeyEvent(nType);
        jEvent:SetId(oLabel.Control:GetId());
        jEvent:SetEventObject(oLabel.Control);
        oLabel.Control:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end

    local jContext = _wx.wxContextMenuEvent(_wx.wxEVT_CONTEXT_MENU,
        oLabel.Control:GetId(), _wx.wxPoint(-1, -1));
    jContext:SetEventObject(oLabel.Control);
    oLabel.Control:GetEventHandler():ProcessEvent(jContext);
    jContext:delete();

    for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "middleClick",
        "leftDoubleClick", "rightDoubleClick", "middleDoubleClick", "keyDown",
        "keyUp", "character", "contextMenu", "mouseWheel"}) do
        check(tSeen[sEvent] == 1, "Native event delivery: "..sEvent);
    end

    local nFirst, nSecond = 0, 0;
    local fSecond = function()
        nSecond = nSecond + 1;
    end;
    oLabel.on("valueChanged", function()
        nFirst = nFirst + 1;
        oLabel.off("valueChanged", fSecond);
    end).on("valueChanged", fSecond);
    oLabel.setValue("snapshot one", true);
    oLabel.setValue("snapshot two", true);
    check(nFirst == 2 and nSecond == 1, "Listener removal uses a dispatch snapshot.");
    oLabel.off("valueChanged");
    local nSourceWidth, nSourceHeight = oImage.getImageSize();
    check(nSourceWidth > 0 and nSourceHeight > 0, "Image decoded dimensions.");
    check(not pcall(oImage.setValue, APP_PATH.."/missing-file.png", true), "Reject missing image.");
    check(oImage.getValue() == pImage and oImage.getImageSize() == nSourceWidth,
        "Failed image load preserves current source.");

    -- Render every scaling policy and text alignment into real native memory DCs.
    local oBitmap = _wx.wxBitmap(220, 180);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);

    for _, sMode in ipairs({"contain", "cover", "stretch", "native"}) do
        oImage.setScaleMode(sMode);
        oImage.draw(oDC, 220, 180);
        oImage.draw(oDC, 220, 180);
        check(oImage.getScaleMode() == sMode, "Image scaling mode: "..sMode);
    end

    for _, sAlign in ipairs({"left", "center", "right"}) do
        for _, sVertical in ipairs({"top", "center", "bottom"}) do
            oLabel.setAlignment(sAlign, sVertical);
            oLabel.draw(oDC, 220, 180);
            check(true, "Label alignment rendering.");
        end
    end

    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    oBitmap:delete();
    local nLoads = 0;
    oImage.on("imageLoaded", function(oSource, tEvent)
        check(tEvent.Width == nSourceWidth and tEvent.Height == nSourceHeight, "Loaded event dimensions.");
        nLoads = nLoads + 1;
    end);
    oImage.setValue(nil, true);
    check(oImage.getValue() == nil and oImage.getImageSize() == 0, "Image clearing releases source.");
    oImage.setValue(pImage, true);
    oImage.setValue(pImage, true);
    check(nLoads == 1, "Image loaded event only for changed source.");

    -- A known solid-color source distinguishes letterboxing from cover/stretch
    -- and native centering through actual RGB pixels, rather than mode names.
    local pFixture = APP_PATH.."/Tests/DisplayContainers-pixel-fixture.png";
    local hExisting = io.open(pFixture, "rb");
    assert(not hExisting, "Refusing to overwrite an existing pixel fixture.");
    local oSolid = _wx.wxImage(40, 20);
    oSolid:SetRGB(_wx.wxRect(0, 0, 40, 20), 240, 30, 20);
    check(oSolid:SaveFile(pFixture, _wx.wxBITMAP_TYPE_PNG), "Write temporary pixel fixture.");
    oSolid:delete();
    oImage.setValue(pFixture);

    for _, sMode in ipairs({"contain", "cover", "stretch", "native"}) do
        oImage.setScaleMode(sMode);
        local oTestBitmap = _wx.wxBitmap(100, 100);
        local oTestDC = _wx.wxMemoryDC();
        oTestDC:SelectObject(oTestBitmap);
        oImage.draw(oTestDC, 100, 100);
        oTestDC:SelectObject(_wx.wxNullBitmap);
        local oPixels = oTestBitmap:ConvertToImage();
        check(oPixels:GetRed(50, 50) == 240 and oPixels:GetGreen(50, 50) == 30,
            "Image center pixel: "..sMode);
        local nExpectedCorner = (sMode == "cover" or sMode == "stretch") and 240 or 24;
        check(oPixels:GetRed(0, 0) == nExpectedCorner, "Image edge geometry: "..sMode);
        oPixels:delete();
        oTestDC:delete();
        oTestBitmap:delete();
    end

    oImage.setValue(pImage);
    check(os.remove(pFixture), "Remove temporary pixel fixture.");

    -- Steady bindings must preserve the earlier redraw optimizations.
    _wx.wxYield();
    local nPaints = 0;

    for _, oComponent in ipairs({oLabel, oImage, oScroll}) do
        local fDraw = oComponent.draw;
        oComponent.draw = function(...)
            nPaints = nPaints + 1;
            return fDraw(...);
        end;
    end

    for nIndex = 1, 100 do
        oLabel.setValue(oLabel.getValue(), true);
        oImage.setValue(oImage.getValue(), true);
        oImage.setScaleMode(oImage.getScaleMode());
        oScroll.setValue(oScroll.getValue(), true);
        oScroll.setContentSize(1200, 1000);
    end

    _wx.wxYield();
    check(nPaints == 0, "Unchanged bindings schedule no native paints.");
    local nViewWidth, nViewHeight = oScroll.getViewportSize();
    check(nViewWidth == 570 and nViewHeight == 420, "Both scrollbars reserve viewport space.");
    check(oScroll.HorizontalScrollbar.Control:IsShown() and oScroll.VerticalScrollbar.Control:IsShown(),
        "Both axes visible for large content.");
    local nScrolled = 0;
    oScroll.on("scrolled", function()
        nScrolled = nScrolled + 1;
    end);
    oScroll.scrollTo(9999, 9999, true);
    local nX, nY = oScroll.getScrollPosition();
    check(nX == 1200 - nViewWidth and nY == 1000 - nViewHeight, "Clamp offsets to content extent.");
    local nContentX, nContentY = oScroll.Content:GetPositionXY();
    check(nContentX == -nX and nContentY == -nY, "Scroll moves native content.");
    local tSnapshot = oScroll.getValue();
    tSnapshot.X = -500;
    check(oScroll.getValue().X == nX, "Scroll snapshots cannot mutate internal offsets.");
    oScroll.scrollTo(nX, nY, true);
    check(nScrolled == 1, "No-op scrolling does not notify.");
    oScroll.handleKey("down", _wx.WXK_HOME);
    check(oScroll.getValue().X == 0 and oScroll.getValue().Y == 0, "Home returns to origin.");
    oScroll.handleKey("down", _wx.WXK_PAGEDOWN);
    check(oScroll.getValue().Y == nViewHeight, "Page navigation uses viewport size.");
    oScroll.wheel(1);
    check(oScroll.getValue().Y == nViewHeight - 96, "Wheel scroll step.");
    oScroll.HorizontalScrollbar.setValue(80, true);
    check(oScroll.getValue().X == 80, "Horizontal bar scrolls container.");
    oScroll.VerticalScrollbar.setValue(120, true);
    check(oScroll.getValue().Y == 120, "Vertical bar scrolls container.");
    oScroll.setContentSize(10, 10, true);
    check(oScroll.getValue().X == 0 and oScroll.getValue().Y == 0, "Shrink clamps offsets.");
    check(not oScroll.HorizontalScrollbar.Control:IsShown() and not oScroll.VerticalScrollbar.Control:IsShown(),
        "Bars disappear for small content.");
    check(oScroll.getViewportSize() == 592, "Hidden bars restore viewport width.");
    oScroll.setContentSize(590, 450);
    check(oScroll.HorizontalScrollbar.Control:IsShown() and oScroll.VerticalScrollbar.Control:IsShown(),
        "Vertical bar can force horizontal overflow.");
    oScroll.setContentSize(1200, 1000);
    oScroll.handleKey("down", _wx.WXK_END);
    _wx.wxYield();
    oChild.handleKey("down", _wx.WXK_SPACE);
    oChild.handleKey("up", _wx.WXK_SPACE);
    check(nChildClicks == 1, "Scrolled child remains interactive.");
    oScroll.setEnabled(false);
    check(not oChild.Control:IsEnabled(), "Disabled container disables descendants.");
    check(not oScroll.handleKey("down", _wx.WXK_HOME), "Disabled container ignores navigation.");
    oScroll.setEnabled(true);
    check(oChild.Control:IsEnabled(), "Enable restores descendants.");
    check(not pcall(oScroll.setValue, {X = 0, Y = 0 / 0}), "Reject nonfinite offsets.");

    local nDestroyed = 0;
    oImage.on("destroyed", function()
        nDestroyed = nDestroyed + 1;
    end);
    oImage.destroy();
    oImage.destroy();
    check(nDestroyed == 1 and oImage.getImageSize() == 0, "Image disposal releases resources once.");
    oChild.destroy();
    oScroll.destroy();
    oLabel.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    _wx.wxYield();
    check(#tWorkbench.Widgets.Tabs.Pages == 12 and tWorkbench.Widgets.Tabs.Items[7] == "Orb meters"
        and tWorkbench.Widgets.Tabs.Items[8] == "Menus",
        "Workbench retains its existing categories and includes Orb meters and Menus.");
    tWorkbench.Widgets.Tabs.setValue(4);
    tWorkbench.Layout();
    _wx.wxYield();
    check(tWorkbench.Widgets.Image.Control:IsShownOnScreen(), "Display sample is visible.");
    -- Exercise the native handler path and real focus ownership. Direct calls
    -- to handleKey cannot catch page-selection or child-focus routing failures.
    local oWorkbenchScroll = tWorkbench.Widgets.ScrollContainer;
    local oWorkbenchTabs = tWorkbench.Widgets.Tabs;
    local tContainerHeader;
    for _, tEntry in ipairs(oWorkbenchTabs.getLayout().Entries) do
        if (tEntry.Index == 5) then
            tContainerHeader = tEntry;
        end
    end
    assert(tContainerHeader, "Container header must be visible in wrapped workbench tabs.");
    local nTabX = tContainerHeader.X + math.floor(tContainerHeader.Width / 2);
    local nTabY = tContainerHeader.Y + math.floor(tContainerHeader.Height / 2);
    fMouse(oWorkbenchTabs.Control, _wx.wxEVT_LEFT_DOWN, nTabX, nTabY);
    fMouse(oWorkbenchTabs.Control, _wx.wxEVT_LEFT_UP, nTabX, nTabY);
    _wx.wxYield();
    check(oWorkbenchScroll.Control:HasFocus(), "Selecting Containers focuses its scroll surface.");

    local function fNativeKey(oTarget, nKey)
        local jEvent = _wx.wxKeyEvent(_wx.wxEVT_KEY_DOWN);
        -- KeyCode has no native setter in this wxLua build. Supply the key at
        -- the callback boundary while retaining native event-handler dispatch.
        jEvent.GetKeyCode = function()
            return nKey;
        end;
        jEvent:SetId(oTarget:GetId());
        jEvent:SetEventObject(oTarget);
        oTarget:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end

    local nContentWidth, nContentHeight = oWorkbenchScroll.getContentSize();
    local nViewportWidth, nViewportHeight = oWorkbenchScroll.getViewportSize();
    fNativeKey(_wx.wxWindow.FindFocus(), _wx.WXK_END);
    check(oWorkbenchScroll.getValue().X == nContentWidth - nViewportWidth
        and oWorkbenchScroll.getValue().Y == nContentHeight - nViewportHeight,
        "Native End reaches both content limits.");
    fNativeKey(_wx.wxWindow.FindFocus(), _wx.WXK_HOME);
    check(oWorkbenchScroll.getValue().X == 0 and oWorkbenchScroll.getValue().Y == 0,
        "Native Home returns to the origin.");
    fNativeKey(_wx.wxWindow.FindFocus(), _wx.WXK_PAGEDOWN);
    check(oWorkbenchScroll.getValue().Y == math.min(nViewportHeight, nContentHeight - nViewportHeight),
        "Native Page Down advances one visible page.");
    fNativeKey(_wx.wxWindow.FindFocus(), _wx.WXK_PAGEUP);
    check(oWorkbenchScroll.getValue().Y == 0, "Native Page Up returns one visible page.");
    fMouse(tWorkbench.Widgets.ScrollLabel.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    fMouse(tWorkbench.Widgets.ScrollLabel.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(oWorkbenchScroll.Control:HasFocus(), "Clicking display content restores scroll focus.");
    fNativeKey(_wx.wxWindow.FindFocus(), _wx.WXK_END);
    check(oWorkbenchScroll.getValue().Y == nContentHeight - nViewportHeight,
        "End works after clicking display content.");
    fMouse(tWorkbench.Widgets.ScrollReset.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    fMouse(tWorkbench.Widgets.ScrollReset.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(oWorkbenchScroll.Control:HasFocus() and oWorkbenchScroll.getValue().Y == 0,
        "Origin button hands keyboard focus back to the container.");
    fMouse(tWorkbench.Widgets.ScrollEnd.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    fMouse(tWorkbench.Widgets.ScrollEnd.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(oWorkbenchScroll.Control:HasFocus()
        and oWorkbenchScroll.getValue().Y == nContentHeight - nViewportHeight,
        "End button hands keyboard focus back to the container.");
    for _, oPanel in ipairs({oWorkbenchScroll.Viewport, oWorkbenchScroll.Content}) do
        oWorkbenchScroll.scrollTo(0, 0);
        fMouse(oPanel, _wx.wxEVT_LEFT_DOWN, 10, 10);
        check(oWorkbenchScroll.Control:HasFocus(), "Owned background click focuses scrolling.");
        fNativeKey(oPanel, _wx.WXK_PAGEDOWN);
        check(oWorkbenchScroll.getValue().Y == math.min(nViewportHeight, nContentHeight - nViewportHeight),
            "Owned native panel routes Page Down.");
        fNativeKey(oPanel, _wx.WXK_PAGEUP);
        check(oWorkbenchScroll.getValue().Y == 0, "Owned native panel routes Page Up.");
    end

    oWorkbenchScroll.scrollTo(0, 100);
    tWorkbench.Widgets.ScrollButton.Control:SetFocus();
    fNativeKey(tWorkbench.Widgets.ScrollButton.Control, _wx.WXK_HOME);
    check(oWorkbenchScroll.getValue().Y == 100,
        "Interactive child keeps its own keyboard ownership.");
    tWorkbench.Widgets.Tabs.setValue(5);
    _wx.wxYield();
    check(tWorkbench.Widgets.ScrollContainer.Control:IsShownOnScreen(), "Container sample is visible.");
    tWorkbench.Widgets.ScrollContainer.handleKey("down", _wx.WXK_END);
    _wx.wxYield();
    check(tWorkbench.Widgets.ScrollContainer.getValue().Y > 0, "Workbench content scrolls.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Display/container regression passed: ".._nChecks.." checks.");