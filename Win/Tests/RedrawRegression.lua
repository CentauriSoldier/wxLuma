--[[!
@fqxn wxLuma.Tests.RedrawRegression
@desc Compares actual native paint counts before and after redraw optimization.
    Tests unchanged bindings, pointer motion, key repeat, layouts and selection;
    verifies changed state, editor canonicalization and custom backgrounds too.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path  = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";

local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _pBefore  = APP_PATH.."/Backups/UI-before-redraw-optimization/Scripts/";
local _tCache   = {};
local _wBefore  = setmetatable({}, {__index = _G});
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.RedrawRegression.before
@desc Loads the preserved object implementation and its original dependencies.
@param string sModule The module name.
@ret table Module The preserved module.
!]]
local function before(sModule)
    if (sModule == "wx") then
        return _wx;
    end

    if (not _tCache[sModule]) then
        local pModule = _pBefore..sModule:gsub("%.", "/")..".lua";
        _tCache[sModule] = assert(loadfile(pModule, "t", _wBefore))();
    end

    return _tCache[sModule];
end

_wBefore.require = before;

--[[!
@fqxn wxLuma.Tests.RedrawRegression.check
@desc Counts passing checks and raises the supplied description on failure.
@param boolean bPassed Whether the check passed.
@param string sMessage The failure description.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.RedrawRegression.run
@desc Runs one visible control set and records native paints for repeated no-ops.
@param table Controls The control factories.
@param boolean bOptimized Whether zero redundant paints are expected.
@ret table tCounts The measured per-case paint counts.
!]]
local function run(Controls, bOptimized)
    local sLabel = bOptimized and "After" or "Before";
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma redraw checks — "..sLabel,
        _wx.wxDefaultPosition, _wx.wxSize(1000, 700));
    local oSkin   = Controls.loadSkin();
    local oGroup  = Controls.radioGroup();
    local tCounts = {};
    local tPaints = {};
    local tWidgets = {};
    local nChanges = 0;
    local nClicks  = 0;
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));

    local function fAdd(sName, sFactory, tOptions, nX, nY, nWidth, nHeight)
        tOptions.Skin = oSkin;
        tOptions.OnChange = function()
            nChanges = nChanges + 1;
        end;
        local oWidget = Controls[sFactory](oFrame, tOptions);
        tWidgets[sName] = oWidget;
        tPaints[oWidget] = 0;
        local fDraw = oWidget.draw;

        oWidget.draw = function(oDC, nDrawWidth, nDrawHeight)
            fDraw(oDC, nDrawWidth, nDrawHeight);
            tPaints[oWidget] = tPaints[oWidget] + 1;
        end;
        oWidget.layout(nX, nY, nWidth, nHeight);
        return oWidget;
    end

    fAdd("Checkbox", "checkbox", {Selected = false}, 10, 10, 180, 36);
    fAdd("Slider", "slider", {Min = 0, Max = 100, Step = 5, Value = 50}, 200, 10, 240, 44);
    fAdd("Spinner", "spinner", {Min = 0, Max = 100, Step = 1, Value = 4}, 450, 10, 140, 40);
    fAdd("Button", "button", {
        Text = "Action",
        OnClick = function()
            nClicks = nClicks + 1;
        end,
    }, 610, 10, 160, 40);
    fAdd("Radio1", "radio", {Group = oGroup, Value = "one", Selected = true}, 10, 70, 180, 36);
    fAdd("Radio2", "radio", {Group = oGroup, Value = "two"}, 200, 70, 180, 36);
    fAdd("Text", "textfield", {Value = "Command"}, 450, 70, 250, 40);
    fAdd("Progress", "progress", {Min = 0, Max = 100, Value = 50}, 10, 120, 240, 36);
    fAdd("Dropdown", "dropdown", {Items = {"one", "two", "three"}, Value = 1}, 300, 120, 250, 40);
    fAdd("List", "list", {Items = {"one", "two", "three"}, Value = 1}, 600, 120, 240, 200);
    fAdd("Custom", "checkbox", {
        Selected = false,
        Background = function(oDC)
            oDC:SetBackground(oBackground);
            oDC:Clear();
        end,
    }, 10, 200, 180, 36);
    fAdd("CustomRadio", "radio", {
        Group = Controls.radioGroup(), Value = "custom", Selected = true,
        Background = function(oDC)
            oDC:SetBackground(oBackground);
            oDC:Clear();
        end,
    }, 10, 250, 180, 36);

    oFrame:Centre();
    oFrame:Show(true);
    oFrame:Raise();
    _wx.wxYield();

    local function fFlush()
        for _, oWidget in pairs(tWidgets) do
            oWidget.Control:Update();
        end
    end

    local function fSample(sName, tTargets, fAction, bExpectBeforePaint)
        fFlush();
        local nBefore = 0;

        for _, oWidget in ipairs(tTargets) do
            nBefore = nBefore + tPaints[oWidget];
        end

        for nIndex = 1, 100 do
            fAction(nIndex);

            for _, oWidget in ipairs(tTargets) do
                oWidget.Control:Update();
            end
        end

        local nAfter = 0;

        for _, oWidget in ipairs(tTargets) do
            nAfter = nAfter + tPaints[oWidget];
        end

        tCounts[sName] = nAfter - nBefore;

        if (bOptimized) then
            check(tCounts[sName] == 0, sName.." still causes redundant native paints.");
        elseif (bExpectBeforePaint) then
            check(tCounts[sName] > 0, sName.." did not exercise the original repaint path.");
        end
    end

    fSample("checkboxValue", {tWidgets.Checkbox}, function()
        tWidgets.Checkbox.setValue(false, true);
    end, true);
    fSample("sliderValue", {tWidgets.Slider}, function()
        tWidgets.Slider.setValue(51, true);
    end, true);
    fSample("spinnerValue", {tWidgets.Spinner}, function()
        tWidgets.Spinner.setValue(4, true);
    end, true);
    fSample("radioSelection", {tWidgets.Radio1, tWidgets.Radio2}, function()
        tWidgets.Radio1.setValue(true, true);
    end, true);

    tWidgets.Checkbox.handlePointer("move", 20, 18);
    fFlush();
    fSample("pointerMotion", {tWidgets.Checkbox}, function(nIndex)
        tWidgets.Checkbox.handlePointer("move", 20 + nIndex % 50, 18);
    end, true);

    tWidgets.Progress.handlePointer("move", 20, 18);
    fFlush();
    fSample("surfaceMotion", {tWidgets.Progress}, function(nIndex)
        tWidgets.Progress.handlePointer("move", 20 + nIndex % 50, 18);
    end, true);

    tWidgets.Checkbox.setEnabled(true);
    fFlush();
    fSample("enabledState", {tWidgets.Checkbox}, function()
        tWidgets.Checkbox.setEnabled(true);
    end, true);
    fSample("inputLayout", {tWidgets.Slider}, function()
        tWidgets.Slider.layout(200, 10, 240, 44);
    end, true);

    tWidgets.Button.handleKey("down", _wx.WXK_SPACE);
    fFlush();
    fSample("keyRepeat", {tWidgets.Button}, function()
        tWidgets.Button.handleKey("down", _wx.WXK_SPACE);
    end, true);
    tWidgets.Button.handleKey("up", _wx.WXK_SPACE);
    check(nClicks == 1, "Key repeat changed activation count.");
    check(nChanges == 0, "Unchanged values emitted change callbacks.");

    -- Native editor commits still normalize text even when its numeric value stays 4.
    tWidgets.Spinner.TextControl:ChangeValue("004");
    check(tWidgets.Spinner.commitText(), "Spinner failed to canonicalize unchanged input.");
    check(tWidgets.Spinner.TextControl:GetValue() == "4", "Spinner left noncanonical text.");
    check(nChanges == 0, "Canonicalizing unchanged text emitted a change.");

    if (bOptimized) then
        local nPaint = tPaints[tWidgets.Checkbox];
        tWidgets.Checkbox.setValue(true, true);
        tWidgets.Checkbox.Control:Update();
        check(tPaints[tWidgets.Checkbox] > nPaint and nChanges == 1, "A real selection change did not paint and notify.");

        local oEditor = tWidgets.Text.TextControl;
        oEditor:SetInsertionPoint(2);
        tWidgets.Text.setValue("Command", true);
        check(oEditor:GetInsertionPoint() == 2, "An unchanged text binding reset the caret.");

        tWidgets.Text.setEnabled(false);
        fFlush();
        nPaint = tPaints[tWidgets.Text];
        tWidgets.Text.setValue("Disabled update");
        tWidgets.Text.Control:Update();
        check(tPaints[tWidgets.Text] > nPaint, "A disabled text update did not invalidate its painted text.");

        local nLayoutCalls = 0;
        local fLayout = tWidgets.List.onLayout;
        tWidgets.List.onLayout = function(nWidth, nHeight)
            nLayoutCalls = nLayoutCalls + 1;
            fLayout(nWidth, nHeight);
        end;
        tWidgets.List.layout(600, 120, 240, 200);
        check(nLayoutCalls == 0, "An unchanged surface layout reran child layout.");
        tWidgets.List.layout(600, 120, 240, 220);
        check(nLayoutCalls > 0, "A real size change failed to lay out children.");

        check(tWidgets.Dropdown.open(), "Dropdown failed to open.");
        tWidgets.Dropdown.layout(300, 120, 250, 40);
        check(tWidgets.Dropdown.isOpen(), "An unchanged layout dismissed the dropdown.");
        tWidgets.Dropdown.close(false);

        for _, sName in ipairs({"Custom", "CustomRadio"}) do
            fFlush();
            nPaint = tPaints[tWidgets[sName]];
            tWidgets[sName].setValue(sName == "CustomRadio");
            tWidgets[sName].Control:Update();
            check(tPaints[tWidgets[sName]] > nPaint, "An explicit custom-background refresh was suppressed.");
        end

        tWidgets.Button.Control:SetFocus();
        _wx.wxYield();
        fFlush();
        nPaint = tPaints[tWidgets.Button];
        tWidgets.Slider.Control:SetFocus();
        _wx.wxYield();
        fFlush();
        check(tPaints[tWidgets.Button] > nPaint, "Losing focus did not repaint the button focus indicator.");
    end

    local tParts = {};

    for sName, nCount in pairs(tCounts) do
        tParts[#tParts + 1] = sName.."="..nCount;
    end

    table.sort(tParts);
    print(sLabel.." paints per 100 unchanged operations: "..table.concat(tParts, ", "));

    for _, oWidget in pairs(tWidgets) do
        oWidget.destroy();
    end

    oSkin.destroy();
    oFrame:Show(false);
    oFrame:Destroy();
    _wx.wxYield();
    oBackground:delete();
    collectgarbage("collect");
    return tCounts;
end

run(before("UI.Controls"), false);
run(_Controls, true);
print(string.format("PASS: %d redraw checks; changed state, focus, custom backgrounds and native editing preserved.", _nChecks));