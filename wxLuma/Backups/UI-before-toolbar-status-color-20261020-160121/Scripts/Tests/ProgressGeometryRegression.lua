--[[!
@fqxn wxLuma.Tests.ProgressGeometryRegression
@desc Checks all fill origins in both appearances, circular start angles and
    direction, normalized no-ops, validation, notifications and workbench examples.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ProgressGeometryRegression.check
@desc Counts assertions and reports the failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ProgressGeometryRegression.pixels
@desc Returns an owned native image from the production paint path.
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
@fqxn wxLuma.Tests.ProgressGeometryRegression.samePixel
@desc Compares one interior pixel against a full/empty reference at the same point.
!]]
local function samePixel(oLeft, oRight, nX, nY)
    return oLeft:GetRed(nX, nY) == oRight:GetRed(nX, nY)
        and oLeft:GetGreen(nX, nY) == oRight:GetGreen(nX, nY)
        and oLeft:GetBlue(nX, nY) == oRight:GetBlue(nX, nY);
end

--[[!
@fqxn wxLuma.Tests.ProgressGeometryRegression.click
@desc Dispatches native button callbacks with event-local coordinates.
!]]
local function click(oComponent)
    for _, nType in ipairs({_wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP}) do
        local jEvent = _wx.wxMouseEvent(nType);
        jEvent.GetX = function()
            return 10;
        end;
        jEvent.GetY = function()
            return 10;
        end;
        jEvent:SetId(oComponent.Control:GetId());
        jEvent:SetEventObject(oComponent.Control);
        oComponent.Control:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end
end

--[[!
@fqxn wxLuma.Tests.ProgressGeometryRegression.run
@desc Validates geometry independently of artwork colour and range minimum.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Progress geometry",
        _wx.wxDefaultPosition, _wx.wxSize(600, 500));
    local oBar = _Controls.progress(oFrame, {Skin = oSkin, Min = 10, Max = 110, Value = 35, Text = ""});
    local oCircle = _Controls.circularProgress(oFrame, {Skin = oSkin, Min = 0, Max = 100, Value = 25, Text = ""});
    oBar.layout(10, 10, 108, 108);
    oCircle.layout(140, 10, 100, 100);
    check(oBar.getOrientation() == "horizontal" and oBar.getOrigin() == "left", "Default horizontal left.");
    check(oCircle.getStartAngle() == 0, "Default circle top.");
    local tSamples = {
        {"left", 14, 54, 94, 54},
        {"right", 94, 54, 14, 54},
        {"top", 54, 14, 54, 94},
        {"bottom", 54, 94, 54, 14}
    };

    for _, sAppearance in ipairs({"colour", "skin"}) do
        oBar.setAppearance(sAppearance);

        for _, tSample in ipairs(tSamples) do
            oBar.setOrigin(tSample[1]);
            oBar.setValue(10);
            local oEmpty = pixels(oBar, 108, 108);
            oBar.setValue(110);
            local oFull = pixels(oBar, 108, 108);
            oBar.setValue(35);
            local oPartial = pixels(oBar, 108, 108);
            check(samePixel(oPartial, oFull, tSample[2], tSample[3]), "Quarter fills from "..tSample[1].." in "..sAppearance);
            check(samePixel(oPartial, oEmpty, tSample[4], tSample[5]), "Opposite end stays empty.");
            check(not samePixel(oPartial, oEmpty, tSample[2], tSample[3]), "Fill is visible.");
            oEmpty:delete();
            oFull:delete();
            oPartial:delete();
        end

        oBar.setOrigin("bottom");
        oBar.setValue(10);
        local oEmpty = pixels(oBar, 54, 208);
        oBar.setValue(110);
        local oFull = pixels(oBar, 54, 208);
        oBar.setValue(35);
        local oPartial = pixels(oBar, 54, 208);
        check(samePixel(oPartial, oFull, 27, 190) and samePixel(oPartial, oEmpty, 27, 20), "Tall bar uses height as fill length.");
        oEmpty:delete();
        oFull:delete();
        oPartial:delete();
    end

    oBar.setOrigin("left");
    oBar.setOrientation("vertical");
    check(oBar.getOrigin() == "bottom", "Forward origin maps left to bottom.");
    oBar.setOrigin("top");
    oBar.setOrientation("horizontal");
    check(oBar.getOrigin() == "right", "Reverse origin maps top to right.");
    local nWidth, nHeight = oBar.Control:GetSizeWH();
    check(nWidth == 108 and nHeight == 108 and oBar.getValue() == 35, "Geometry setters preserve native size and value.");
    local nOrigins, nOrientations, nValues = 0, 0, 0;
    oBar.on("originChanged", function(oSource, tEvent)
        check(oSource == oBar and tEvent.Origin == oBar.getOrigin()
            and tEvent.OldOrigin ~= tEvent.Origin, "Origin event payload.");
        nOrigins = nOrigins + 1;
    end);
    oBar.on("orientationChanged", function(oSource, tEvent)
        check(oSource == oBar and tEvent.Orientation == oBar.getOrientation()
            and tEvent.OldOrientation ~= tEvent.Orientation, "Orientation event payload.");
        nOrientations = nOrientations + 1;
    end);
    oBar.on("valueChanged", function()
        nValues = nValues + 1;
    end);
    oBar.setOrigin("bottom", true);
    oBar.setOrigin("bottom", true);
    oBar.setOrientation("vertical", true);
    check(nOrigins == 1 and nOrientations == 1 and nValues == 0, "Changed-only geometry events do not notify value.");
    check(not pcall(oBar.setOrigin, "center") and not pcall(oBar.setOrientation, "diagonal"), "Invalid geometry rejected.");
    check(oBar.getOrigin() == "bottom", "Invalid origin leaves state intact.");

    for _, sAppearance in ipairs({"colour", "skin"}) do
        oCircle.setAppearance(sAppearance);
        oCircle.setValue(0);
        local oEmpty = pixels(oCircle, 100, 100);
        oCircle.setValue(100);
        local oFull = pixels(oCircle, 100, 100);
        oCircle.setValue(25);

        for _, sDirection in ipairs({"CW", "CCW"}) do
            oCircle.setDirection(sDirection);

            for _, nAngle in ipairs({0, 90, 180, 270, 45.5, -90, 450}) do
                oCircle.setStartAngle(nAngle);
                local nSign = sDirection == "CW" and 1 or -1;
                local nMiddle = (nAngle + nSign * 45) * math.pi / 180;
                local nFilledX = math.floor(50 + math.sin(nMiddle) * 42 + 0.5);
                local nFilledY = math.floor(50 - math.cos(nMiddle) * 42 + 0.5);
                local oPartial = pixels(oCircle, 100, 100);
                check(samePixel(oPartial, oFull, nFilledX, nFilledY), "Circle sweeps from requested angle.");
                check(samePixel(oPartial, oEmpty, 100 - nFilledX, 100 - nFilledY), "Opposite quadrant remains track.");
                check(oCircle.getValue() == 25 and oCircle.getDirection() == sDirection, "Angle preserves value and direction.");
                oPartial:delete();
            end
        end

        oEmpty:delete();
        oFull:delete();
    end

    oCircle.setStartAngle(0);
    local nAngles, nRefreshes = 0, 0;
    local fRefresh = oCircle.refresh;
    oCircle.refresh = function()
        nRefreshes = nRefreshes + 1;
        return fRefresh();
    end;
    oCircle.on("startAngleChanged", function(oSource, tEvent)
        check(oSource == oCircle and tEvent.StartAngle == 45.5 and tEvent.OldStartAngle == 0, "Angle event payload.");
        nAngles = nAngles + 1;
    end);
    check(oCircle.setStartAngle(45.5, true) == oCircle, "Angle setter chains.");
    oCircle.setStartAngle(405.5, true);
    check(nAngles == 1 and nRefreshes == 1, "Equivalent wrapped angles neither redraw nor notify.");
    for _, vInvalid in ipairs({false, "90", math.huge, 0 / 0}) do
        check(not pcall(oCircle.setStartAngle, vInvalid), "Reject invalid start angle.");
    end
    check(oCircle.getStartAngle() == 45.5, "Invalid angle preserves state.");
    local nBeforeBuild = 0;
    local fBitmap = oSkin.getBitmap;
    oSkin.getBitmap = function(...)
        nBeforeBuild = nBeforeBuild + 1;
        return fBitmap(...);
    end;
    local oImage = pixels(oCircle, 100, 100);
    oImage:delete();
    local nAfterBuild = nBeforeBuild;
    oCircle.setStartAngle(45.5 + 360);
    oImage = pixels(oCircle, 100, 100);
    oImage:delete();
    check(nAfterBuild == 2 and nBeforeBuild == nAfterBuild, "Angle cache reuses unchanged normalized geometry.");

    local tExtra = {};
    for _, tOptions in ipairs({{Orientation = "vertical"}, {Origin = "top"}}) do
        tOptions.Skin, tOptions.Min, tOptions.Max, tOptions.Value = oSkin, 0, 100, 50;
        local oExtra = _Controls.progress(oFrame, tOptions);
        check(oExtra.getOrientation() == "vertical", "Creation infers vertical axis.");
        check(oExtra.getOrigin() == (tOptions.Origin or "bottom"), "Creation default/inferred origin.");
        tExtra[#tExtra + 1] = oExtra;
    end
    for _, tOptions in ipairs({{Orientation = "vertical", Origin = "left"}, {Origin = false}, {Orientation = false}}) do
        tOptions.Skin, tOptions.Min, tOptions.Max, tOptions.Value = oSkin, 0, 100, 50;
        check(not pcall(_Controls.progress, oFrame, tOptions), "Reject conflicting/invalid creation geometry.");
    end
    check(not pcall(_Controls.circularProgress, oFrame,
        {Skin = oSkin, Min = 0, Max = 100, Value = 50, StartAngle = false}), "Reject invalid creation angle.");
    for _, oExtra in ipairs(tExtra) do
        oExtra.destroy();
    end
    oBar.destroy();
    oCircle.destroy();
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(3);
    tWorkbench.Layout();
    _wx.wxYield();
    local oDemo = tWorkbench.Widgets.DirectionalProgress;
    check(oDemo.getOrigin() == "bottom", "Workbench starts with bottom-up meter.");
    for _, sOrigin in ipairs({"top", "right", "left", "bottom"}) do
        click(tWorkbench.Widgets.ProgressOrigin);
        check(oDemo.getOrigin() == sOrigin and oDemo.getValue() == 70, "Workbench cycles origins without changing value.");
    end
    click(tWorkbench.Widgets.CircularStartAngle);
    check(tWorkbench.Widgets.CircularProgress.getStartAngle() == 45
        and tWorkbench.Widgets.CircularProgress.getDirection() == "CW", "Workbench circle angle button.");
    tWorkbench.Widgets.MeterSlider.setValue(63, true);
    check(oDemo.getValue() == 63, "Shared slider also drives directional meter.");
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Layout();
    _wx.wxYield();
    local nBarX = oDemo.Control:GetPositionXY();
    local nMeterX = tWorkbench.Widgets.Health.Control:GetPositionXY();
    local nMeterWidth = tWorkbench.Widgets.Health.Control:GetSizeWH();
    check(nBarX > nMeterX + nMeterWidth, "Minimum-size example meters do not overlap.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Progress geometry regression passed: ".._nChecks.." checks.");