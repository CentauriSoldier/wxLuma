--[[!
@fqxn wxLuma.Tests.CircularProgressRegression
@desc Exercises native ring pixels, runtime direction, standard events, containment,
    no-op updates, resource disposal and the workbench direction button.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.CircularProgressRegression.check
@desc Counts behavior assertions and reports the failing contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.CircularProgressRegression.pixels
@desc Renders through the production drawing path into an owned image.
!]]
local function pixels(oComponent, nWidth, nHeight)
    local oBitmap = _wx.wxBitmap(nWidth, nHeight);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oComponent.draw(oDC, nWidth, nHeight);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    oDC:delete();
    oBitmap:delete();
    return oImage;
end

--[[!
@fqxn wxLuma.Tests.CircularProgressRegression.colour
@desc Checks a pixel against an expected solid RGB colour.
!]]
local function colour(oImage, nX, nY, nR, nG, nB)
    return oImage:GetRed(nX, nY) == nR and oImage:GetGreen(nX, nY) == nG
        and oImage:GetBlue(nX, nY) == nB;
end

--[[!
@fqxn wxLuma.Tests.CircularProgressRegression.click
@desc Dispatches native button callbacks using event-local coordinate accessors.
!]]
local function click(oTarget)
    for _, nType in ipairs({_wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP}) do
        local jEvent = _wx.wxMouseEvent(nType);
        jEvent.GetX = function()
            return 10;
        end;
        jEvent.GetY = function()
            return 10;
        end;
        jEvent:SetId(oTarget:GetId());
        jEvent:SetEventObject(oTarget);
        oTarget:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end
end

--[[!
@fqxn wxLuma.Tests.CircularProgressRegression.run
@desc Verifies geometry and behavioral contracts on the installed wxLua build.
!]]
local function run()
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Circular regression",
        _wx.wxDefaultPosition, _wx.wxSize(400, 300));
    local oSkin = _Controls.loadSkin();
    local nChanges, nValues, nDirections = 0, 0, 0;
    local oProgress = _Controls.circularProgress(oFrame, {
        Skin = oSkin,
        Min = 0,
        Max = 100,
        Value = 25,
        Text = "",
        Colour = {R = 200, G = 100, B = 50},
        OnChange = function()
            nChanges = nChanges + 1;
        end
    });
    local oSpacer = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    oSpacer:SetSize(300, 200, 1, 1);
    oProgress.layout(0, 0, 100, 100);
    oFrame:Show();
    _wx.wxYield();
    check(next(oProgress) == nil and getmetatable(oProgress) == "wxLuma.UI.CircularProgress", "Uses decoy object.");
    check(oProgress.getDirection() == "CW" and oProgress.getValue() == 25, "Default direction and value.");
    check(oProgress.getContainment() ~= nil, "Inherits top-level containment.");
    oProgress.on("valueChanged", function(oSource, tEvent)
        check(oSource == oProgress and tEvent.Value == oProgress.getValue(), "Value event payload.");
        nValues = nValues + 1;
    end);
    oProgress.on("directionChanged", function(oSource, tEvent)
        check(oSource == oProgress and tEvent.Direction == oProgress.getDirection()
            and tEvent.OldDirection ~= tEvent.Direction, "Direction event payload.");
        nDirections = nDirections + 1;
    end);

    local oImage = pixels(oProgress, 100, 100);
    check(colour(oImage, 80, 20, 200, 100, 50), "CW quarter fills upper right.");
    check(colour(oImage, 20, 20, 43, 50, 59), "CW quarter leaves upper left track.");
    check(colour(oImage, 80, 80, 43, 50, 59), "CW quarter leaves lower right track.");
    oImage:delete();
    check(oProgress.setDirection("CCW", true) == oProgress, "Direction setter chains.");
    check(oProgress.getValue() == 25 and nChanges == 0 and nDirections == 1, "Direction preserves value.");
    oImage = pixels(oProgress, 100, 100);
    check(colour(oImage, 20, 20, 200, 100, 50), "CCW quarter fills upper left.");
    check(colour(oImage, 80, 20, 43, 50, 59), "CCW quarter leaves upper right track.");
    oImage:delete();

    for _, sDirection in ipairs({"CW", "CCW"}) do
        oProgress.setDirection(sDirection);
        oProgress.setValue(50);
        oImage = pixels(oProgress, 100, 100);
        local nFilledX = sDirection == "CW" and 80 or 20;
        local nEmptyX = 100 - nFilledX;
        check(colour(oImage, nFilledX, 80, 200, 100, 50), "Half ring follows direction.");
        check(colour(oImage, nEmptyX, 80, 43, 50, 59), "Other half remains track.");
        oImage:delete();
    end

    oProgress.setValue(-10, true);
    check(oProgress.getValue() == 0 and nChanges == 1 and nValues == 1, "Clamps and notifies once.");
    oImage = pixels(oProgress, 100, 100);
    check(colour(oImage, 20, 20, 43, 50, 59) and colour(oImage, 80, 20, 43, 50, 59), "Zero leaves track.");
    oImage:delete();
    oProgress.setValue(150);
    check(oProgress.getValue() == 100 and nChanges == 1, "Silent update clamps to max.");
    oImage = pixels(oProgress, 200, 100);
    check(colour(oImage, 70, 20, 200, 100, 50) and colour(oImage, 130, 80, 200, 100, 50), "Full circle centered in rectangular bounds.");
    check(colour(oImage, 20, 50, 24, 29, 36) and colour(oImage, 100, 50, 24, 29, 36), "Outside and hole remain background.");
    oImage:delete();
    oProgress.setEnabled(false);
    oImage = pixels(oProgress, 100, 100);
    check(colour(oImage, 80, 20, 61, 67, 73), "Disabled fill uses disabled colour.");
    oImage:delete();
    oProgress.setEnabled(true);

    local nRefreshes = 0;
    local fRefresh = oProgress.refresh;
    oProgress.refresh = function()
        nRefreshes = nRefreshes + 1;
        return fRefresh();
    end;
    oProgress.setValue(100, true);
    oProgress.setDirection(oProgress.getDirection(), true);
    check(nRefreshes == 0 and nDirections == 1 and nValues == 1, "No-op setters neither redraw nor notify.");
    for _, vInvalid in ipairs({"clockwise", false, 0}) do
        check(not pcall(oProgress.setDirection, vInvalid), "Rejects invalid direction.");
    end
    check(not pcall(oProgress.setValue, 0 / 0), "Rejects NaN.");
    check(not pcall(oProgress.setValue, math.huge), "Rejects infinity.");
    check(oProgress.getValue() == 100, "Invalid updates preserve state.");
    for _, tInvalid in ipairs({
        {Min = 1, Max = 1, Value = 1},
        {Min = 0, Max = 1, Value = 0, Direction = "bad"},
        {Min = 0, Max = 1, Value = 0, Thickness = 0}
    }) do
        tInvalid.Skin = oSkin;
        check(not pcall(_Controls.circularProgress, oFrame, tInvalid), "Rejects invalid creation options.");
    end

    -- Repeated shape changes exercise native geometry replacement and tiny bounds.
    for nIndex = 1, 100 do
        oProgress.setValue(nIndex);
        oProgress.setDirection(nIndex % 2 == 0 and "CW" or "CCW");
        oImage = pixels(oProgress, 100, 100);
        oImage:delete();
    end
    oImage = pixels(oProgress, 2, 2);
    oImage:delete();
    local nDestroyed = 0;
    oProgress.on("destroyed", function()
        nDestroyed = nDestroyed + 1;
    end);
    oProgress.destroy();
    oProgress.destroy();
    check(nDestroyed == 1 and oProgress.Disposed, "Disposal is idempotent.");
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(3);
    tWorkbench.Layout();
    _wx.wxYield();
    local oDemo = tWorkbench.Widgets.CircularProgress;
    check(oDemo.getDirection() == "CW" and oDemo.getValue() == 25, "Resource page includes circle.");
    click(tWorkbench.Widgets.CircularDirection.Control);
    check(oDemo.getDirection() == "CCW" and oDemo.getValue() == 25, "Workbench toggles CCW without value change.");
    click(tWorkbench.Widgets.CircularDirection.Control);
    check(oDemo.getDirection() == "CW", "Workbench toggles back to CW.");
    tWorkbench.Widgets.MeterSlider.setValue(63, true);
    check(oDemo.getValue() == 63, "Workbench slider drives circular progress.");
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Layout();
    _wx.wxYield();
    local nCircleX = oDemo.Control:GetPositionXY();
    local nSliderX = tWorkbench.Widgets.MeterSlider.Control:GetPositionXY();
    local nSliderWidth = tWorkbench.Widgets.MeterSlider.Control:GetSizeWH();
    check(nCircleX > nSliderX + nSliderWidth, "Minimum-size workbench controls do not overlap.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("CircularProgress regression passed: ".._nChecks.." checks.");