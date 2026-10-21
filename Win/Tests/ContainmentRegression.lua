--[[!
@fqxn wxLuma.Tests.ContainmentRegression
@desc Exercises default/explicit/inherited boundaries and oversized policy against
    actual native popups. Verifies independent axis movement and unchanged sizes,
    ordinary layout, ancestor lifecycle, dropdown input and common visual APIs.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ContainmentRegression.check
@desc Counts assertions and raises the failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ContainmentRegression.rectangle
@desc Copies an actual native popup's screen rectangle into a plain table.
!]]
local function rectangle(oWindow)
    local nX, nY = oWindow:GetPositionXY();
    local nWidth, nHeight = oWindow:GetSizeWH();
    return {X = nX, Y = nY, Width = nWidth, Height = nHeight};
end

--[[!
@fqxn wxLuma.Tests.ContainmentRegression.inside
@desc Checks every edge against the resolved boundary and compares natural size.
!]]
local function inside(oComponent, oPopup, nWidth, nHeight)
    local tBounds = oComponent.getContainmentBounds();
    local tPopup = rectangle(oPopup);
    check(tPopup.X >= tBounds.X and tPopup.Y >= tBounds.Y
        and tPopup.X + tPopup.Width <= tBounds.X + tBounds.Width
        and tPopup.Y + tPopup.Height <= tBounds.Y + tBounds.Height,
        "All popup edges remain inside the boundary.");
    check(tPopup.Width == nWidth and tPopup.Height == nHeight, "Containment preserves popup size.");
end

--[[!
@fqxn wxLuma.Tests.ContainmentRegression.run
@desc Runs visible native windows, then validates workbench API coverage.
!]]
local function run()
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Containment regression",
        _wx.wxPoint(80, 80), _wx.wxSize(620, 460));
    oFrame:SetClientSize(_wx.wxSize(600, 420));
    -- wxFrame automatically expands a sole child; keep this geometry fixture
    -- independent of that native layout convenience.
    local oSpacer = _wx.wxPanel(oFrame, _wx.wxID_ANY, _wx.wxPoint(0, 0), _wx.wxSize(1, 1));
    local oSkin = _Controls.loadSkin();
    local oTarget = _Controls.label(oFrame, {Skin = oSkin, Value = "Target"});
    local oTip = _Controls.tooltip(oTarget, {Skin = oSkin, Text = "A contained tooltip"});
    oTarget.layout(100, 100, 50, 30);
    oFrame:Show(true);
    _wx.wxYield();
    check(oTip.getContainment():GetId() == oFrame:GetId(), "Default boundary is the top-level parent.");
    check(_Controls.getDefaultContainmentOverflow() == "hide", "POLA default hides oversized popups.");
    check(oTip.show(), "Fitting tooltip opens.");
    local nNaturalWidth, nNaturalHeight = oTip.Control:GetSizeWH();
    local tInitialBounds = oTip.getContainmentBounds();
    local oPoint = oTarget.Control:ClientToScreen(_wx.wxPoint(0, 0));
    local tInitial = rectangle(oTip.Control);
    check(tInitial.X == oPoint:GetX() and tInitial.Y == oPoint:GetY() + 30,
        "Fitting popup keeps its preferred position on both axes.");
    inside(oTip, oTip.Control, nNaturalWidth, nNaturalHeight);

    for _, tCase in ipairs({
        {540, 100, true, false}, {100, 380, false, true}, {540, 380, true, true}
    }) do
        oTarget.layout(tCase[1], tCase[2], 50, 30);
        check(oTip.show(), "Edge tooltip opens without resizing.");
        local tPopup = rectangle(oTip.Control);
        local tBounds = oTip.getContainmentBounds();
        local oAnchor = oTarget.Control:ClientToScreen(_wx.wxPoint(0, 0));
        local nExpectedX = tCase[3] and tBounds.X + tBounds.Width - nNaturalWidth or oAnchor:GetX();
        local nExpectedY = tCase[4] and tBounds.Y + tBounds.Height - nNaturalHeight or oAnchor:GetY() + 30;
        check(tPopup.X == nExpectedX and tPopup.Y == nExpectedY,
            "Only overflowing axes move, by their minimum necessary distance.");
        inside(oTip, oTip.Control, nNaturalWidth, nNaturalHeight);
    end

    local oPanel = _Controls.panel(oFrame, {Skin = oSkin, MinWidth = 100, MinHeight = 100});
    oPanel.layout(220, 60, 300, 240);
    local oNested = _Controls.label(oPanel.Content, {Skin = oSkin, Value = "Nested"});
    oNested.layout(210, 140, 60, 30);
    local oNestedTip = _Controls.tooltip(oNested.Control, {Skin = oSkin, Text = "Nested tooltip"});
    check(oNestedTip.getContainment():GetId() == oFrame:GetId(), "Unconfigured nested targets default to the top-level window.");
    oNested.setContainment(oPanel.Content);
    check(oNestedTip.getContainment():GetId() == oPanel.Content:GetId(), "Tooltip inherits its target's boundary.");
    check(oNestedTip.show(), "Inherited panel tooltip opens.");
    local nNestedWidth, nNestedHeight = oNestedTip.Control:GetSizeWH();
    inside(oNestedTip, oNestedTip.Control, nNestedWidth, nNestedHeight);
    local nBeforeX, nBeforeY = oNested.Control:GetPositionXY();
    local nBeforeWidth, nBeforeHeight = oNested.Control:GetSizeWH();
    oNested.setContainment(oPanel);
    local nAfterX, nAfterY = oNested.Control:GetPositionXY();
    local nAfterWidth, nAfterHeight = oNested.Control:GetSizeWH();
    check(nBeforeX == nAfterX and nBeforeY == nAfterY and nBeforeWidth == nAfterWidth and nBeforeHeight == nAfterHeight,
        "Ordinary containment does not move/resize the target.");
    check(oNestedTip.getContainment():GetId() == oPanel.Control:GetId(), "Visual components are accepted as boundaries.");
    oPanel.Content:Move(-1000, -1000);
    check(not oNestedTip.isShown() and not oNestedTip.show(),
        "Fully clipped/scrolled targets do not leave floating tooltips visible.");
    oPanel.Content:Move(8, 34);
    check(oNestedTip.show(), "Tooltip reopens when its target becomes visible again.");    oNestedTip.setContainment(oFrame);
    check(oNestedTip.getContainment():GetId() == oFrame:GetId(), "Explicit tooltip boundary overrides inherited policy.");
    oNestedTip.setContainment(nil);
    check(oNestedTip.getContainment():GetId() == oPanel.Control:GetId(), "Nil restores inherited policy.");
    local oUnrelated = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    check(not pcall(oNestedTip.setContainment, oUnrelated), "Reject unrelated boundary windows.");
    check(oNestedTip.getContainment():GetId() == oPanel.Control:GetId(), "Invalid boundary changes are atomic.");

    -- A target-sized boundary is deliberately smaller than the natural popup.
    oTip.setContainment(oTarget);
    check(not oTip.show() and not oTip.isShown(), "Oversized tooltip is hidden under POLA policy.");
    check(oTip.Control:GetSizeWH() == nNaturalWidth, "Oversized rejection never shrinks the tooltip.");
    oTip.setContainmentOverflow("allow");
    check(oTip.show(), "Per-object allow policy permits an oversized tooltip.");
    local tAllowed = rectangle(oTip.Control);
    local tSmall = oTip.getContainmentBounds();
    check(tAllowed.X == tSmall.X and tAllowed.Y == tSmall.Y
        and tAllowed.Width == nNaturalWidth and tAllowed.Height == nNaturalHeight,
        "Allowed overflow aligns oversized axes without changing dimensions.");
    oTip.setContainmentOverflow("hide");
    check(not oTip.isShown(), "Switching a visible oversized popup to hide dismisses it.");
    oTip.setContainmentOverflow(nil);
    _Controls.setDefaultContainmentOverflow("allow");
    check(oTip.getContainmentOverflow() == "allow" and oTip.show(), "Framework default is configurable.");
    oTarget.setContainmentOverflow("hide");
    check(oTip.getContainmentOverflow() == "hide" and not oTip.isShown(), "Inherited object override wins over global policy.");
    oTip.setContainmentOverflow("allow");
    check(oTip.getContainmentOverflow() == "allow" and oTip.show(), "Direct popup override wins over target/global policy.");
    check(not pcall(oTip.setContainmentOverflow, "resize"), "Position-only policy rejects resizing modes.");
    _Controls.setDefaultContainmentOverflow("hide");
    oTarget.setContainmentOverflow(nil);
    oTip.setContainmentOverflow(nil);
    oTip.setContainment(nil);

    -- Visible popup placement follows ancestor movement and size changes.
    oTarget.layout(540, 380, 50, 30);
    check(oTip.show(), "Tooltip reopens in normal containment.");
    oFrame:Move(120, 100);
    _wx.wxYield();
    inside(oTip, oTip.Control, nNaturalWidth, nNaturalHeight);
    oFrame:SetClientSize(_wx.wxSize(560, 400));
    _wx.wxYield();
    inside(oTip, oTip.Control, nNaturalWidth, nNaturalHeight);
    oPanel.show(false);
    _wx.wxYield();
    check(not oNestedTip.isShown(), "Hiding an ancestor dismisses its tooltip.");
    oPanel.show(true);

    -- Root-level observation must not retain disposed popup objects after their
    -- native targets are gone, even while the root window remains alive.
    local tWeak = setmetatable({}, {__mode = "v"});

    do
        local oTransient = _Controls.label(oFrame, {Skin = oSkin, Value = "Transient"});
        oTransient.layout(10, 10, 80, 30);
        local oTransientTip = _Controls.tooltip(oTransient, {Skin = oSkin, Text = "Transient tooltip"});
        tWeak[1] = oTransientTip;
        oTransientTip.destroy();
        oTransient.destroy();
        oTransient.Control:Destroy();
    end

    _wx.wxYield();
    collectgarbage("collect");
    collectgarbage("collect");
    check(tWeak[1] == nil, "Ancestor observers do not retain disposed tooltip objects.");
    local tItems = {};

    for nIndex = 1, 30 do
        tItems[nIndex] = "Option "..nIndex;
    end

    local oDropdown = _Controls.dropdown(oFrame, {Skin = oSkin, Items = tItems, Value = 2, Rows = 4});
    oDropdown.layout(430, 330, 110, 30);
    oTip.hide();
    check(oDropdown.open(), "Contained dropdown opens.");
    local nDropdownWidth, nDropdownHeight = oDropdown.Popup:GetSizeWH();
    inside(oDropdown, oDropdown.Popup, 110, 4 * oDropdown.List.RowHeight + 8);
    local tDropdown = rectangle(oDropdown.Popup);
    local tDropdownBounds = oDropdown.getContainmentBounds();
    check(tDropdown.Y == tDropdownBounds.Y + tDropdownBounds.Height - nDropdownHeight,
        "Dropdown overflow shifts to the bottom boundary instead of flipping.");
    oDropdown.List.setValue(3);
    oDropdown.close(true);
    check(oDropdown.getValue() == 3, "Contained dropdown still commits selection.");
    oDropdown.setContainment(oDropdown.Control);
    check(not oDropdown.open() and not oDropdown.isOpen(), "Oversized dropdown obeys hide policy.");
    check(oDropdown.Popup:GetSizeWH() == nDropdownWidth, "Rejected dropdown retains its normal width.");
    oDropdown.setContainmentOverflow("allow");
    check(oDropdown.open(), "Dropdown can opt into oversized overflow.");
    check(oDropdown.Popup:GetSizeWH() == nDropdownWidth, "Allowed dropdown never changes width.");
    oDropdown.setContainmentOverflow("hide");
    check(not oDropdown.isOpen(), "Runtime overflow policy can dismiss an open dropdown.");
    oDropdown.setContainment(nil);
    check(oDropdown.open(), "Dropdown reopens after restoring normal boundary.");
    oFrame:Show(false);
    _wx.wxYield();
    check(not oDropdown.isOpen() and not oTip.isShown(), "Root hiding dismisses floating content.");
    oDropdown.destroy();
    oNestedTip.destroy();
    oTip.destroy();
    oNested.destroy();
    oPanel.destroy();
    oTarget.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    _wx.wxYield();

    for sName, oWidget in pairs(tWorkbench.Widgets) do
        check(type(oWidget.getContainment) == "function" and type(oWidget.setContainment) == "function"
            and type(oWidget.getContainmentOverflow) == "function", "Shared containment API: "..sName);
    end

    for _, oTooltip in ipairs(tWorkbench.Tooltips) do
        check(type(oTooltip.getContainment) == "function", "Tooltips share containment policy.");
    end

    check(tWorkbench.Widgets.TooltipBoundary and tWorkbench.Widgets.TooltipOverflow,
        "Workbench includes boundary and overflow-policy examples.");    check(tWorkbench.Window.getContainment():GetId() == tWorkbench.Frame:GetId(), "Window surface shares the default boundary.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);
_Controls.setDefaultContainmentOverflow("hide");

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Containment regression passed: ".._nChecks.." checks.");