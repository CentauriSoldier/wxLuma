--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression
@desc Checks the real gallery's category membership, documented containers,
    native child bounds, scrolling, popup ownership and representative actions.
    Sound files are validated but playback is replaced with a local recorder.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the Windows host directory.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..APP_PATH.."/?.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _nChecks = 0;
local _Demo;
local _Sound = _wx.wxSound;
local _nPlayed = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression.check
@desc Counts successful assertions and provides a specific layout failure.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression.mouse
@desc Sends a native mouse event through the control's real callback chain.
!]]
local function mouse(oTarget, nType, nX, nY)
    local jEvent = _wx.wxMouseEvent(nType);
    jEvent.GetX = function() return nX or 12; end;
    jEvent.GetY = function() return nY or 18; end;
    jEvent:SetEventObject(oTarget); jEvent:SetId(oTarget:GetId());
    oTarget:GetEventHandler():ProcessEvent(jEvent); jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression.dispatch
@desc Allows actual timer/paint/deactivation delivery inside a bounded native loop.
!]]
local function dispatch()
    local oTimer = _wx.wxTimer(_Demo.Frame);
    local nId = oTimer:GetId();
    _Demo.Frame:Connect(nId, _wx.wxEVT_TIMER, function() _wx.wxGetApp():ExitMainLoop(); end);
    assert(oTimer:Start(50, true)); _wx.wxGetApp():MainLoop();
    _Demo.Frame:Disconnect(nId, _wx.wxEVT_TIMER); oTimer:Stop(); oTimer:delete();
end

--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression.bounds
@desc Ensures an actual native child fits its sample/action parent after layout.
!]]
local function bounds(oControl, oParent, sName)
    check(oControl:GetParent():GetId() == oParent:GetId(), sName.." has its documented native parent.");
    local nX, nY = oControl:GetPositionXY();
    local nW, nH = oControl:GetSizeWH();
    local nParentW, nParentH = oParent:GetClientSizeWH();
    check(nX >= 0 and nY >= 0 and nW > 0 and nH > 0 and nX + nW <= nParentW and nY + nH <= nParentH,
        sName.." fits its own container.");
end

--[[!
@fqxn wxLuma.Tests.DemoGalleryRegression.run
@desc Exercises every documented card at normal, minimum and wide sizes, then
    opens the actual browse/suggestion/menu surfaces from their scrolled cards.
!]]
local function run()
    _wx.wxSound = setmetatable({Stop = _Sound.Stop}, {__call = function(tClass, sPath)
        local oSound = _Sound(sPath);
        assert(oSound:IsOk(), "Demo sound must load: "..sPath);
        return {IsOk = function() return oSound:IsOk(); end,
            Play = function() _nPlayed = _nPlayed + 1; return true; end,
            delete = function() oSound:delete(); end};
    end});
    _Demo = require("Tests.UI")(_wx.NULL);
    local oGallery, tWidgets = _Demo.Gallery, _Demo.Widgets;
    check(#oGallery.Categories == 14 and #tWidgets.Tabs.Pages == 14, "All related categories have tab pages.");
    for sKey, sCategory in pairs({SearchField = "editors", ComboBox = "editors", NumericField = "editors",
        FilePicker = "dialogs", FolderPicker = "dialogs", MenuBar = "menus", Panel = "containers",
        CollapsiblePanel = "containers", Accordion = "containers", List = "lists", CheckListEx = "lists",
        Tree = "trees", TreeEx = "trees", PropertyGrid = "properties", ColorPicker = "properties",
        Switch = "choices", LED = "display", MultilineText = "editors", RangeSlider = "editors", Knob = "editors",
        DateTimePicker = "editors", Notification = "tools", Breadcrumb = "tabs", DockablePanel = "containers",
        LogViewer = "lists", ActionLog = "lists", LineChart = "charts", AreaChart = "charts", BarChart = "charts",
        StackedBarChart = "charts", HorizontalBarChart = "charts", PieChart = "charts", DonutChart = "charts", ScatterChart = "charts"}) do
        check(oGallery.getCategoryIndex(sKey) == oGallery.getCategoryIndex(sCategory), sKey.." is grouped by purpose.");
    end
    for _, tSize in ipairs({{1120, 900}, {920, 780}, {1440, 1000}}) do
        _Demo.Frame:SetClientSize(_wx.wxSize(tSize[1], tSize[2])); _Demo.Layout();
        local nCards = 0;
        for _, tCategory in ipairs(oGallery.Categories) do
            local nBottom = 0;
            local nContentWidth, nContentHeight = tCategory.Scroll.getContentSize();
            for _, tCard in ipairs(tCategory.Cards) do
                nCards = nCards + 1;
                local tSpec = tCard.Spec;
                check(#tSpec.Primary >= 1 and tSpec.Title ~= "" and tSpec.Description ~= "" and tSpec.Usage ~= "" and tSpec.API ~= "",
                    tCard.Id.." includes heading, description, usage and API information.");
                check(tCard.Y >= nBottom and tCard.Y + tCard.Height <= nContentHeight,
                    tCard.Id.." is reachable without overlapping adjacent containers.");
                nBottom = tCard.Y + tCard.Height;
                local nUnused, nUsageY = tCard.Usage:GetPositionXY();
                local nUsageH; nUnused, nUsageH = tCard.Usage:GetSizeWH();
                check(nUsageY + nUsageH < tCard.PreviewY, tCard.Id.." documentation does not overlap its live example.");
                for _, sKey in ipairs(tSpec.Primary) do bounds(tWidgets[sKey].Control, tCard.Preview, sKey); end
                for _, sKey in ipairs(tSpec.Actions or {}) do bounds(tWidgets[sKey].Control, tCard.Actions, sKey); end
            end
        end
        check(nCards == 52, "Every type section survives resize with its related variants.");
    end
    for _, tKeys in ipairs({{"Radio1", "Radio2", "Radio3"}, {"Health", "Mana", "Progress", "DirectionalProgress", "CircularProgress"},
        {"GlobeProgress", "RadialProgress", "IrisProgress"}, {"Checkbox", "DisabledCheckbox"},
        {"Text", "DisabledText"}, {"NumericField", "NumericPlain", "NumericReadOnly"}, {"Slider", "VerticalSlider"},
        {"Label", "WrappedLabel", "AlignedLabel"}, {"ListEx", "CheckListEx"}, {"FilePicker", "FolderPicker"},
        {"ColorPicker", "ColorPickerAlpha"}, {"DialogOpen", "DialogModalOpen"}}) do
        local nParent = tWidgets[tKeys[1]].Control:GetParent():GetId();
        for _, sKey in ipairs(tKeys) do
            check(tWidgets[sKey].Control:GetParent():GetId() == nParent, sKey.." shares its type section with related examples.");
        end
    end
    -- Every loose top-level sample is now inside a registered container. Native
    -- dialog/menu clients and nested content retain their own native ownership.
    for sKey, oWidget in pairs(tWidgets) do
        if (sKey ~= "Tabs") then
            local bLoose = false;
            for _, oPage in ipairs(tWidgets.Tabs.Pages) do
                bLoose = bLoose or oWidget.Control:GetParent():GetId() == oPage:GetId();
            end
            check(not bLoose, sKey.." is not loose on an outer tab page.");
        end
    end
    _Demo.Frame:SetClientSize(_wx.wxSize(920, 780)); _Demo.Layout();
    for _, sKey in ipairs({"FilePicker", "FolderPicker"}) do
        oGallery.show(sKey, true);
        local oPicker = tWidgets[sKey];
        local nWidth = oPicker.Control:GetClientSizeWH();
        mouse(oPicker.Control, _wx.wxEVT_LEFT_DOWN, nWidth - 15, 18);
        mouse(oPicker.Control, _wx.wxEVT_LEFT_UP, nWidth - 15, 18);
        check(oPicker.isOpen(), sKey.." browse works from its own gallery container.");
        dispatch(); check(oPicker.isOpen(), sKey.." survives native browser painting.");
        oPicker.close(false);
    end
    oGallery.show("ComboBox", true);
    tWidgets.ComboBox.TextControl:SetFocus(); tWidgets.ComboBox.TextControl:SetValue("ca");
    check(tWidgets.ComboBox.isOpen() and tWidgets.ComboBox.List.getValue() == 2, "Scrolled combo keeps typing suggestions.");
    dispatch(); check(tWidgets.ComboBox.TextControl:HasFocus(), "Suggestion preview retains editor focus.");
    oGallery.Categories[oGallery.getCategoryIndex("editors")].Scroll.scrollTo(0, 0);
    _wx.wxGetApp():Yield();
    check(not tWidgets.ComboBox.isOpen(), "Scrolling the anchor away dismisses suggestions.");
    oGallery.show("ContextMenuTarget", true);
    check(tWidgets.ContextMenu.showAtObject(tWidgets.ContextMenuTarget), "Context menu opens from its own container.");
    tWidgets.ContextMenu.close();
    oGallery.show("RadialMenuTarget", true);
    check(tWidgets.RadialMenu.showAtObject(tWidgets.RadialMenuTarget), "Radial menu opens from its own container.");
    tWidgets.RadialMenu.close();
    oGallery.show("MenuBar", true);
    check(tWidgets.MenuBar.open("file"), "Menu bar opens in its command category.");
    tWidgets.MenuBar.getMenu("file").activateItem("folder");
    check(tWidgets.Tabs.getValue() == oGallery.getCategoryIndex("FolderPicker") and tWidgets.FolderPicker.isOpen(),
        "Menu commands navigate to and open the related picker.");
    tWidgets.FolderPicker.close(false);
    oGallery.show("ProgressOrigin", true);
    tWidgets.ProgressOrigin.handleKey("down", _wx.WXK_RETURN); tWidgets.ProgressOrigin.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.DirectionalProgress.getOrigin() == "top", "Direction action reflows its own meter preview.");
    oGallery.show("TabsAdd", true);
    local nPages = #tWidgets.ExampleTabs.Pages;
    tWidgets.TabsAdd.handleKey("down", _wx.WXK_RETURN); tWidgets.TabsAdd.handleKey("up", _wx.WXK_RETURN);
    check(#tWidgets.ExampleTabs.Pages == nPages + 1, "Nested tab actions retain child creation.");
    tWidgets.TabsRemove.handleKey("down", _wx.WXK_RETURN); tWidgets.TabsRemove.handleKey("up", _wx.WXK_RETURN);
    check(#tWidgets.ExampleTabs.Pages == nPages, "Nested tab removal retains disposal behavior.");
    oGallery.show("Switch", true);
    tWidgets.SwitchOrientation.handleKey("down", _wx.WXK_RETURN); tWidgets.SwitchOrientation.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.Switch.getOrientation() == "vertical" and tWidgets.SwitchVertical.getOrientation() == "horizontal",
        "Demo orientation action rotates both switch families.");
    tWidgets.SwitchDirection.handleKey("down", _wx.WXK_RETURN); tWidgets.SwitchDirection.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.Switch.getReversed() and not tWidgets.SwitchReverse.getReversed(), "Demo reversal action changes physical mapping.");
    oGallery.show("LED", true); dispatch();
    tWidgets.LEDBrightness.setValue(25, true); tWidgets.LEDSize.setValue(48, true);
    tWidgets.LEDColor.setValue({R = 120, G = 80, B = 240}, true);
    check(tWidgets.LED.getBrightness() == 0.25 and tWidgets.LED.getSize() == 48 and tWidgets.LED.getColor().B == 240,
        "Demo brightness, size and color actions are wired to the LED.");
    tWidgets.LEDGlowRadius.setValue(60, true);
    check(tWidgets.LED.getGlowRadius() == 60 and tWidgets.LED.getSize() == 48, "Demo radius slider adjusts only the halo.");
    tWidgets.LEDGlowAutomatic.handleKey("down", _wx.WXK_RETURN); tWidgets.LEDGlowAutomatic.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.LED.getGlowRadius() == nil and tWidgets.LEDGlowRadius.getValue() == 36,
        "Demo automatic action restores proportional radius and synchronizes its slider.");
    for _, sKey in ipairs({"LEDGlow", "LEDGlassToggle", "LEDValue"}) do
        tWidgets[sKey].handleKey("down", _wx.WXK_SPACE); tWidgets[sKey].handleKey("up", _wx.WXK_SPACE);
    end
    check(not tWidgets.LED.getGlow() and tWidgets.LED.getGlass() and not tWidgets.LED.getValue(),
        "Demo power, glow and glass actions change LED state.");
    oGallery.show("LogViewer", true);
    local nLogEntries = tWidgets.LogViewer.getEntryCount();
    tWidgets.LogAppend.handleKey("down", _wx.WXK_RETURN); tWidgets.LogAppend.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.LogViewer.getEntryCount() == nLogEntries + 1 and tWidgets.ActionLog.getTransparent(), "Log demo appends and retains transparent game presentation.");
    tWidgets.LogSeverity.handleKey("down", _wx.WXK_SPACE); tWidgets.LogSeverity.handleKey("up", _wx.WXK_SPACE);
    check(tWidgets.LogViewer.getSeverityEnabled() and not tWidgets.ActionLog.getSeverityEnabled(), "Severity remains optional in both demo logs.");
    oGallery.show("LineChart", true); dispatch();
    local nPoints = #tWidgets.LineChart.getSeries("north").Points;
    tWidgets.ChartAppend.handleKey("down", _wx.WXK_RETURN); tWidgets.ChartAppend.handleKey("up", _wx.WXK_RETURN);
    check(#tWidgets.LineChart.getSeries("north").Points == nPoints + 1 and #tWidgets.AreaChart.getSeries("north").Points == nPoints + 1, "Graph demo append actions feed both related graphs.");
    tWidgets.ChartLineWidth.setValue(5, true); tWidgets.ChartAreaOpacity.setValue(70, true);
    check(tWidgets.LineChart.getLineWidth() == 5 and tWidgets.AreaChart.getAreaOpacity() > 0.69, "Graph geometry/opacity demo options reach their controls.");
    oGallery.show("BarChart", true); dispatch();
    tWidgets.BarOrientation.handleKey("down", _wx.WXK_RETURN); tWidgets.BarOrientation.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.BarChart.getOrientation() == "horizontal" and tWidgets.StackedBarChart.getStacked(), "Bar demo retains independent orientation and stacking options.");
    oGallery.show("PieChart", true); dispatch();
    tWidgets.DonutHole.setValue(70, true); tWidgets.PieGap.setValue(4, true);
    check(tWidgets.DonutChart.getHoleSize() > 0.69 and tWidgets.PieChart.getSliceGap() == 4, "Pie/donut demo geometry options are connected.");
    oGallery.show("ScatterChart", true); dispatch();
    tWidgets.ScatterMarkerSize.setValue(13, true);
    check(tWidgets.ScatterChart.getMarkerSize() == 13, "Scatter demo marker size is mutable.");
    oGallery.show("Toggle", true);
    tWidgets.Toggle.handleKey("down", _wx.WXK_RETURN); tWidgets.Toggle.handleKey("up", _wx.WXK_RETURN);
    check(not tWidgets.ComboBox.isEnabled() and tWidgets.Tabs.isEnabled(), "Disabled examples leave category navigation available.");
    tWidgets.Toggle.handleKey("down", _wx.WXK_RETURN); tWidgets.Toggle.handleKey("up", _wx.WXK_RETURN);
    check(tWidgets.ComboBox.isEnabled() and not tWidgets.DisabledCheckbox.isEnabled(), "Reenable preserves deliberate disabled samples.");
    check(_nPlayed >= 2, "Native sample interactions retain application audio hooks.");
    dispatch();
end

local bOK, sError = xpcall(run, debug.traceback);
if (_Demo) then _Demo.Frame:Close(); end
_wx.wxGetApp():Yield(); _wx.wxSound = _Sound;
assert(bOK, sError);
print("Demo gallery regression: ".._nChecks.." checks passed.");
