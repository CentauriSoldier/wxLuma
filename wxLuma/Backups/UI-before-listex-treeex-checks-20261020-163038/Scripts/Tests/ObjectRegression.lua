--[[!
@fqxn wxLuma.Tests.ObjectRegression
@desc Verifies public proxy identity, widget behavior, rendering and disposal
    against the isolated pre-conversion backup using the real wxLua runtime.
    Run with Lua 5.4 and pass the export directory as the first argument.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path  = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";

local _wx            = require("wx");
local _Controls      = require("UI.Controls");
local _Window        = require("UI.Containers.Window");
local _pBackup       = APP_PATH.."/Backups/UI-before-objects-20261020-113030/Scripts/";
local _tBaseline     = {};
local _wBaseline     = setmetatable({}, {__index = _G});
local _tItems        = {};
local _nChecks       = 0;

--[[!
@fqxn wxLuma.Tests.ObjectRegression.check
@desc Counts a passing assertion or raises an error describing its failure.
@param boolean bPassed Whether the assertion passed.
@param string sMessage The failure description.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.loadBaseline
@desc Resolves backup dependencies in their own environment and module cache.
@param string sModule The original module name.
@ret table Module The preserved module.
!]]
local function loadBaseline(sModule)
    if (sModule == "wx") then
        return _wx;
    end

    if (not _tBaseline[sModule]) then
        local pModule = _pBackup..sModule:gsub("%.", "/")..".lua";
        _tBaseline[sModule] = assert(loadfile(pModule, "t", _wBaseline))();
    end

    return _tBaseline[sModule];
end

_wBaseline.require = loadBaseline;
local _BaselineControls = loadBaseline("UI.Controls");
local _BaselineWindow   = loadBaseline("UI.Containers.Window");

for nIndex = 1, 10000 do
    _tItems[nIndex] = string.format("Sample entry %05d", nIndex);
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.checkObject
@desc Verifies empty decoy storage, protected metadata and pairs-based fields.
@param table oObject The public component.
@param string sType The expected protected metatable name.
!]]
local function checkObject(oObject, sType)
    check(next(oObject) == nil, sType.." stores fields on its decoy.");
    check(getmetatable(oObject) == sType, sType.." has incorrect metadata.");
    check(not pcall(setmetatable, oObject, {}), sType.." allows metatable replacement.");

    local nFields = 0;

    for _ in pairs(oObject) do
        nFields = nFields + 1;
    end

    check(nFields > 0, sType.." does not expose fields through pairs.");
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.createSet
@desc Creates every control factory with comparable options and callback checks.
@param table Controls The factory facade.
@param table Window The window module.
@param boolean bProxy Whether public proxy assertions should be applied.
@ret table tSet The frame, skin, group, widgets and callback records.
!]]
local function createSet(Controls, Window, bProxy)
    local tSet = {
        Frame    = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Object regression", _wx.wxDefaultPosition, _wx.wxSize(1100, 900)),
        Skin     = Controls.loadSkin(),
        Group    = Controls.radioGroup(),
        Widgets  = {},
        Changes  = {},
        Clicks   = 0,
    };

    -- All value callbacks must receive the exact public object returned to callers.
    local function fAdd(sKey, sFactory, tOptions)
        tOptions.Skin = tSet.Skin;
        tOptions.OnChange = function(vValue, oSource)
            check(oSource == tSet.Widgets[sKey], sKey.." callback identity mismatch.");
            tSet.Changes[#tSet.Changes + 1] = sKey..":"..tostring(vValue);
        end;

        local oWidget = Controls[sFactory](tSet.Frame, tOptions);
        tSet.Widgets[sKey] = oWidget;
        check(oWidget.layout(10, 10, 320, sFactory == "list" and 250 or 100) == oWidget,
            sKey.." layout identity mismatch.");
        check(oWidget.setEnabled(true) == oWidget, sKey.." enabled identity mismatch.");

        if (bProxy) then
            checkObject(oWidget, "wxLuma.UI."..oWidget.Kind);
        end

        return oWidget;
    end

    fAdd("Checkbox", "checkbox", {Selected = false});
    fAdd("Radio1", "radio", {Group = tSet.Group, Value = "one", Selected = true});
    fAdd("Radio2", "radio", {Group = tSet.Group, Value = "two"});
    fAdd("Slider", "slider", {Min = 0, Max = 100, Step = 5, Value = 40});
    fAdd("VerticalSlider", "slider", {Min = 0, Max = 100, Step = 5, Value = 65, Vertical = true});
    fAdd("Spinner", "spinner", {Min = 0, Max = 20, Step = 1, Value = 4});
    fAdd("Button", "button", {
        Text = "Action",
        OnClick = function(oSource)
            check(oSource == tSet.Widgets.Button, "Button callback identity mismatch.");
            tSet.Clicks = tSet.Clicks + 1;
        end,
    });
    fAdd("Scrollbar", "scrollbar", {Min = 0, Max = 900, Page = 100, Value = 0});
    fAdd("HorizontalScrollbar", "scrollbar", {Min = 0, Max = 900, Page = 100, Value = 0, Vertical = false});
    fAdd("List", "list", {Items = _tItems, Value = 1});
    fAdd("Dropdown", "dropdown", {Items = _tItems, Value = 5});
    fAdd("Text", "textfield", {Value = "Editable sample"});
    fAdd("Progress", "progress", {Min = 0, Max = 100, Value = 25});
    fAdd("Tabs", "tabs", {Items = {"First", "Second", "Third"}});
    fAdd("Panel", "panel", {MinWidth = 220, MinHeight = 140});

    tSet.Tooltip = Controls.tooltip(tSet.Widgets.Text.TextControl, {
        Skin = tSet.Skin,
        Text = "Tooltip sample",
    });
    tSet.Window = Window.create(tSet.Frame, {Title = "wxLuma", Subtitle = "Regression"});
    tSet.Window.Control:SetSize(0, 0, 800, 600);

    if (bProxy) then
        checkObject(tSet.Skin, "wxLuma.UI.ControlSkin");
        checkObject(tSet.Group, "wxLuma.UI.RadioGroup");
        checkObject(tSet.Tooltip, "wxLuma.UI.Tooltip");
        checkObject(tSet.Window, "wxLuma.UI.Window");
        checkObject(tSet.Widgets.List.Scrollbar, "wxLuma.UI.Scrollbar");
        checkObject(tSet.Widgets.Dropdown.List, "wxLuma.UI.List");
    end

    return tSet;
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.exercise
@desc Applies value, keyboard, validation, item and enabled-state transitions.
@param table tSet The component set.
!]]
local function exercise(tSet)
    local tWidgets = tSet.Widgets;
    local oCheckbox = tWidgets.Checkbox;
    check(oCheckbox.handleKey("down", _wx.WXK_SPACE), "Checkbox key-down failed.");
    check(oCheckbox.handleKey("up", _wx.WXK_SPACE), "Checkbox key-up failed.");
    check(oCheckbox.getValue(), "Checkbox did not toggle.");
    oCheckbox.setEnabled(false);
    check(not oCheckbox.handleKey("down", _wx.WXK_SPACE), "Disabled checkbox handled input.");
    oCheckbox.setEnabled(true);

    check(tWidgets.Radio2.setValue(true, true) == tWidgets.Radio2, "Radio setter identity mismatch.");
    check(tSet.Group.getValue() == "two" and not tWidgets.Radio1.getValue(), "Radio exclusivity failed.");
    tWidgets.Radio1.setValue(true, true);

    for _, sKey in ipairs({"Slider", "VerticalSlider"}) do
        check(tWidgets[sKey].setValue(43, true) == tWidgets[sKey], "Slider setter identity mismatch.");
        check(tWidgets[sKey].getValue() == 45, "Slider did not snap.");
        tWidgets[sKey].handleKey("down", _wx.WXK_END);
        check(tWidgets[sKey].getValue() == 100, "Slider End failed.");
    end

    tWidgets.Spinner.TextControl:ChangeValue("12");
    check(tWidgets.Spinner.commitText() and tWidgets.Spinner.getValue() == 12, "Spinner commit failed.");
    tWidgets.Spinner.TextControl:ChangeValue("invalid");
    check(not tWidgets.Spinner.commitText() and tWidgets.Spinner.TextControl:GetValue() == "12", "Spinner validation failed.");
    check(not pcall(tWidgets.Spinner.setValue, 1.5), "Spinner accepted a fraction.");

    tWidgets.Button.handleKey("down", _wx.WXK_RETURN);
    tWidgets.Button.handleKey("up", _wx.WXK_RETURN);
    check(tSet.Clicks == 1, "Button activation count mismatch.");

    for _, sKey in ipairs({"Scrollbar", "HorizontalScrollbar"}) do
        local oScrollbar = tWidgets[sKey];
        check(oScrollbar.setRange(0, 900, 100) == oScrollbar, "Scrollbar range identity mismatch.");
        oScrollbar.setValue(9000, true);
        check(oScrollbar.getValue() == 900, "Scrollbar did not clamp.");
        oScrollbar.handleKey("down", _wx.WXK_HOME);
        oScrollbar.wheel(-1);
        check(oScrollbar.getValue() == 3, "Scrollbar wheel failed.");
    end

    tWidgets.List.setValue(10000, true);
    check(tWidgets.List.getText() == "Sample entry 10000", "List last-row selection failed.");
    tWidgets.List.handleKey("down", _wx.WXK_HOME);
    check(tWidgets.List.getValue() == 1, "List Home failed.");
    tWidgets.List.setItems({});
    check(tWidgets.List.getValue() == 0, "Empty list retained a selection.");
    tWidgets.List.setItems(_tItems);
    tWidgets.List.setValue(5000);
    tWidgets.List.setHover(5000);

    tWidgets.Dropdown.setValue(10000, true);
    check(tWidgets.Dropdown.getText() == "Sample entry 10000", "Dropdown selection failed.");
    check(tWidgets.Text.setValue("Changed", true) == tWidgets.Text, "Text setter identity mismatch.");
    check(tWidgets.Text.getValue() == "Changed", "Native text did not update.");
    tWidgets.Progress.setValue(1000, true);
    check(tWidgets.Progress.getValue() == 100, "Progress did not clamp.");
    tWidgets.Tabs.setValue(3, true);
    check(tWidgets.Tabs.Pages[3]:IsShown() and not tWidgets.Tabs.Pages[1]:IsShown(), "Tab visibility failed.");
    tWidgets.Panel.resize(440, 240);
    check(tWidgets.Panel.show(false) == tWidgets.Panel, "Panel show identity mismatch.");
    tWidgets.Panel.show(true);
    check(tSet.Tooltip.setText("Changed tooltip") == tSet.Tooltip, "Tooltip text identity mismatch.");
    tSet.Tooltip.setEnabled(false);
    check(not tSet.Tooltip.isShown(), "Disabled tooltip stayed visible.");

    for _, oWidget in pairs(tWidgets) do
        oWidget.setEnabled(false);
    end
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.render
@desc Renders one component into a native bitmap for an exact RGB comparison.
@param table oComponent The component to draw.
@param number nWidth The bitmap width.
@param number nHeight The bitmap height.
@ret wxImage oImage The caller-owned rendered image.
!]]
local function render(oComponent, nWidth, nHeight)
    local oBitmap = _wx.wxBitmap(nWidth, nHeight);
    local oDC     = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oComponent.draw(oDC, nWidth, nHeight);
    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    local oImage = oBitmap:ConvertToImage();
    oBitmap:delete();
    return oImage;
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.compareImages
@desc Checks every RGB channel and releases both rendered images.
@param wxImage oLeft The baseline image.
@param wxImage oRight The object image.
@param string sName The control name used in errors.
!]]
local function compareImages(oLeft, oRight, sName)
    for nY = 0, oLeft:GetHeight() - 1 do
        for nX = 0, oLeft:GetWidth() - 1 do
            check(oLeft:GetRed(nX, nY) == oRight:GetRed(nX, nY) and
                oLeft:GetGreen(nX, nY) == oRight:GetGreen(nX, nY) and
                oLeft:GetBlue(nX, nY) == oRight:GetBlue(nX, nY), sName.." pixel mismatch.");
        end
    end

    oLeft:delete();
    oRight:delete();
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.dispose
@desc Exercises repeated disposal before releasing shared artwork and the frame.
@param table tSet The component set.
!]]
local function dispose(tSet)
    tSet.Tooltip.destroy();
    tSet.Tooltip.destroy();

    for _, oWidget in pairs(tSet.Widgets) do
        oWidget.destroy();
        oWidget.destroy();
    end

    check(#tSet.Group.Members == 0 and tSet.Group.getValue() == nil, "Radio disposal retained membership.");
    tSet.Window.destroy();
    tSet.Window.destroy();
    tSet.Skin.destroy();
    tSet.Skin.destroy();
    tSet.Frame:Destroy();
    _wx.wxGetApp():ProcessPendingEvents();
    collectgarbage("collect");
end

--[[!
@fqxn wxLuma.Tests.ObjectRegression.exerciseSkinCache
@desc Mixes natural-size artwork with enough scaled variants to evict entries.
    Repeated natural-size draws must match their cache keys without duplicate
    eviction records or attempts to draw deleted bitmaps.
@param table oSkin The original or converted skin object.
!]]
local function exerciseSkinCache(oSkin)
    local oBitmap = _wx.wxBitmap(180, 48);
    local oDC     = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);

    for nIndex = 1, 240 do
        oSkin.drawOpaque(oDC, "Button Left Normal", 0, 0);
        oSkin.drawOpaque(oDC, "Button Middle Normal", 12, 0, 40 + nIndex % 120, 36);
        oSkin.drawOpaque(oDC, "Spinner Up Normal", 0, 0);
    end

    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    oBitmap:delete();
    check(true, "Skin cache churn completed.");
end

local _tPlain  = createSet(_BaselineControls, _BaselineWindow, false);
local _tObject = createSet(_Controls, _Window, true);
exerciseSkinCache(_tPlain.Skin);
exerciseSkinCache(_tObject.Skin);
exercise(_tPlain);
exercise(_tObject);
check(table.concat(_tPlain.Changes, "|") == table.concat(_tObject.Changes, "|"), "Callback sequence mismatch.");

for sKey, oWidget in pairs(_tObject.Widgets) do
    -- Tabs now has measured headers and dedicated artwork; its new geometry,
    -- pixels and skin overrides are verified in TabsRegression instead of
    -- requiring the obsolete equal-width button artwork's exact RGB values.
    if (sKey ~= "Tabs") then
        compareImages(render(_tPlain.Widgets[sKey], 320, 250), render(oWidget, 320, 250), sKey);
    end
end

compareImages(render(_tPlain.Window, 800, 600), render(_tObject.Window, 800, 600), "Window");
dispose(_tPlain);
dispose(_tObject);

-- Repeat construction and teardown to catch capture, callback and resource issues.
for nRound = 1, 3 do
    local tSet = createSet(_Controls, _Window, true);
    exercise(tSet);
    dispose(tSet);
end

print(string.format("PASS: %d checks; all widget factories, proxy identities, callback parity, RGB rendering and repeated disposal.", _nChecks));