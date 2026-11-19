local _wx = require("wx");
local _Progress = require("wxLuma.Progress");
-- Keep the renderer-level reference for exact pixel parity after removing the public factories.
local _tPainters = {
    progress = require("wxLuma.Widgets.Progress").create,
    globeProgress = require("wxLuma.Widgets.GlobeProgress").create,
    radialProgress = require("wxLuma.Widgets.RadialProgress").create,
    circularProgress = require("wxLuma.Widgets.CircularProgress").create,
};

local UnifiedProgressRegression = {};

--[[!
@fqxn wxLuma.Tests.UnifiedProgressRegression.run
@desc Compares the numeric progress interface with existing painters using exact
    rendered RGB, capacity bounds, state restoration and callback/event delivery.
    Tests use hidden owned native windows and write no preview files.
@ret number nChecks Successful assertions.
!]]
function UnifiedProgressRegression.run()
    local oLuma = require("wxLuma")();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Unified progress regression");
    local oTheme = require("wxLuma.Core.ControlTheme").create("System", oLuma.Config.SkinPath);
    local oBitmap, oDC = _wx.wxBitmap(96, 96), _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    local nChecks, nRenders = 0, 0;
    local tOwned = {};

    --[[!
    @fqxn wxLuma.Tests.UnifiedProgressRegression.run.check
    @desc Counts a successful behavior or parity assertion.
    !]]
    local function fCheck(bValue, sMessage) assert(bValue, sMessage); nChecks = nChecks + 1; end

    --[[!
    @fqxn wxLuma.Tests.UnifiedProgressRegression.run.pixels
    @desc Draws a production object and returns a detached RGB snapshot.
    !]]
    local function fPixels(oMeter)
        oMeter.draw(oDC, 96, 96); nRenders = nRenders + 1;
        oDC:SelectObject(_wx.wxNullBitmap);
        local oImage = oBitmap:ConvertToImage();
        local sData = oImage:GetData(); oImage:delete();
        oDC:SelectObject(oBitmap);
        return sData;
    end

    local tCases = {
        {Factory = "progress", Shape = 0, FillMode = 0},
        {Factory = "globeProgress", Shape = 1, FillMode = 0},
        {Factory = "radialProgress", Shape = 1, FillMode = 1},
        {Factory = "circularProgress", Shape = 1, FillMode = 2},
    };
    local bOK, sError = xpcall(function()
        -- Only the unified constructor and the separate iris are public.
        for _, sFactory in ipairs({"globeProgress", "radialProgress", "circularProgress"}) do
            fCheck(oLuma.Controls[sFactory] == nil and require("wxLuma.Controls")[sFactory] == nil,
                "Retired progress factory: "..sFactory);
        end
        fCheck(type(oLuma.Controls.irisProgress) == "function", "Iris retains its public factory.");
        fCheck(_Progress.Fill.LINEAR == 0 and _Progress.Fill.RADIAL == 1 and _Progress.Fill.ANGULAR == 2
            and _Progress.Direction.FORWARD == 0 and _Progress.Direction.REVERSE == 1, "Public numeric constant values.");
        local oReserveOnly = oLuma.Controls.progress(oFrame, {Min = 0, Max = 100, Value = 50, ReserveDirection = 0});
        tOwned[#tOwned + 1] = oReserveOnly;
        fCheck(oReserveOnly.getShape() == 0 and oReserveOnly.getReserveFillDirection() == 0,
            "A zero reserve-direction option selects the numeric interface even with default shape/mode.");
        oReserveOnly.destroy(); oReserveOnly.Control:Destroy();
        local nChildren = oFrame:GetChildren():GetCount();
        for _, tBad in ipairs({{Shape = 3}, {FillMode = false}, {Direction = 2}, {Shape = 2},
            {Shape = 0, Direction = 0, Origin = "right"}, {Shape = 1, FillMode = 1, Direction = false}}) do
            tBad.Min, tBad.Max, tBad.Value = 0, 100, 50;
            fCheck(not pcall(oLuma.Controls.progress, oFrame, tBad) and oFrame:GetChildren():GetCount() == nChildren,
                "Invalid numeric selections fail before native allocation.");
        end
        for _, sSkin in ipairs({"System", "Obsidian"}) do
            oTheme.setName(sSkin);
            for _, tCase in ipairs(tCases) do
                for nDirection = 0, 1 do
                    local tNew = {Theme = oTheme, Min = 10, Max = 110, Value = 60,
                        Shape = tCase.Shape, FillMode = tCase.FillMode, Direction = nDirection, ReserveDirection = 1};
                    local tOld = {Theme = oTheme, Min = 10, Max = 110, Value = 60};
                    if (tCase.FillMode == 0) then
                        local bGlobe = tCase.Shape == 1;
                        tOld.Origin = nDirection == 0 and (bGlobe and "bottom" or "left") or (bGlobe and "top" or "right");
                        tOld.ReserveOrigin = bGlobe and "top" or "right";
                    else
                        tOld.Direction = tCase.FillMode == 1 and (nDirection == 0 and "outward" or "inward") or (nDirection == 0 and "CW" or "CCW");
                        tOld.ReserveDirection = tCase.FillMode == 1 and "inward" or "CCW";
                        tNew.InnerRadius, tNew.OuterRadius, tOld.InnerRadius, tOld.OuterRadius = 25, 90, 25, 90;
                        if (tCase.FillMode == 2) then
                            tNew.StartAngle, tNew.ReserveStartAngle, tOld.StartAngle, tOld.ReserveStartAngle = 45, 135, 45, 135;
                        end
                    end
                    local oNew, oOld = oLuma.Progress.create(oFrame, tNew), _tPainters[tCase.Factory](oFrame, tOld);
                    tOwned[#tOwned + 1], tOwned[#tOwned + 2] = oNew, oOld;
                    oNew.layout(0, 0, 96, 96); oOld.layout(0, 0, 96, 96);
                    fCheck(oNew.getShape() == tCase.Shape and oNew.getFillMode() == tCase.FillMode
                        and oNew.getFillDirection() == nDirection and oNew.getReserveFillDirection() == 1, "Numeric option mapping.");
                    local nCallbacks, nEvents = 0, 0;
                    oNew.OnChange = function() nCallbacks = nCallbacks + 1; end;
                    oNew.on("valueChanged", function() nEvents = nEvents + 1; end);
                    for _, nReserve in ipairs({0, 25, 100}) do
                        oNew.setReserved(nReserve); oOld.setReserved(nReserve);
                        for _, nValue in ipairs({10, 35, 60, 85, 110}) do
                            oNew.setValue(nValue, true); oOld.setValue(nValue);
                            fCheck(oNew.getValue() == math.min(nValue, 110 - nReserve)
                                and oNew.getEffectiveMax() == 110 - nReserve, "Shared reserve capacity semantics.");
                            for _, bEnabled in ipairs({true, false}) do
                                oNew.setEnabled(bEnabled); oOld.setEnabled(bEnabled);
                                fCheck(fPixels(oNew) == fPixels(oOld), "Exact legacy rendering parity: "..tCase.Factory.."/"..sSkin);
                            end
                        end
                    end
                    fCheck(nCallbacks == nEvents, "Continuous callback/event counts remain paired.");
                    oNew.setEnabled(true); oNew.setReserved(25); oNew.setValue(60);
                    local tState = oNew.getObjectState();
                    oNew.setFillDirection(1 - nDirection); oNew.setReserved(0); oNew.setValue(10);
                    oNew.setObjectState(tState);
                    fCheck(oNew.getValue() == 60 and oNew.getReserved() == 25 and oNew.getFillDirection() == nDirection,
                        "Numeric interface preserves value, reserve and direction through state.");
                    oNew.setReserveFillDirection(nil);
                    fCheck(oNew.getReserveFillDirection() == nil, "Automatic reserve policy remains expressible.");
                    local nBefore = oNew.getFillDirection();
                    fCheck(not pcall(oNew.setFillDirection, 2) and oNew.getFillDirection() == nBefore,
                        "Invalid runtime constants preserve current direction.");
                    oNew.destroy(); oOld.destroy(); oNew.Control:Destroy(); oOld.Control:Destroy();
                end
            end
            _wx.wxYield();
        end
        -- Preserve specialized constructor settings rather than merely matching
        -- the default pictures for each shape/fill combination.
        local tSpecial = {
            {Factory = "progress", Shape = 0, FillMode = 0, Direction = 1,
                Options = {Orientation = "vertical", Origin = "top", Outline = false, Artwork = "Progress"}},
            {Factory = "globeProgress", Shape = 1, FillMode = 0, Direction = 1,
                Options = {Orientation = "horizontal", Origin = "right", Supersampling = 2, ReserveRenderer = "strips", OutlineWidth = 4}},
            {Factory = "radialProgress", Shape = 1, FillMode = 1, Direction = 0,
                Options = {InnerRadius = 15, OuterRadius = 90, Supersampling = 2, ReserveRenderer = "native"}},
            {Factory = "circularProgress", Shape = 1, FillMode = 2, Direction = 1,
                Options = {Thickness = 7, StartAngle = 235, ReserveStartAngle = 37, ReserveDirection = "CW"}},
        };
        for _, tCase in ipairs(tSpecial) do
            local tNew = {Theme = oTheme, Shape = tCase.Shape, FillMode = tCase.FillMode, Direction = tCase.Direction,
                Min = 10, Max = 110, Value = 60, Reserved = 25, Text = "custom %v/%m", Appearance = "colour", Colour = {R = 210, G = 70, B = 110}};
            local tOld = {};
            for sKey, vValue in pairs(tNew) do if (sKey ~= "Shape" and sKey ~= "FillMode" and sKey ~= "Direction") then tOld[sKey] = vValue; end end
            for sKey, vValue in pairs(tCase.Options) do tNew[sKey], tOld[sKey] = vValue, vValue; end
            if (tCase.FillMode == 1) then tOld.Direction = "outward";
            elseif (tCase.FillMode == 2) then tOld.Direction = "CCW"; end
            local oNew, oOld = oLuma.Controls.progress(oFrame, tNew), _tPainters[tCase.Factory](oFrame, tOld);
            tOwned[#tOwned + 1], tOwned[#tOwned + 2] = oNew, oOld;
            fCheck(fPixels(oNew) == fPixels(oOld), "Specialized constructor options retain exact pixels: "..tCase.Factory);
            if (oNew.getSupersampling) then
                fCheck(oNew.getSupersampling() == 2 and oNew.getReserveRenderer() == tCase.Options.ReserveRenderer,
                    "Supersampling and reserve-renderer options survive the numeric interface.");
            end
            if (tCase.FillMode == 0 and tCase.Factory == "progress") then
                oNew.setOrientation("horizontal"); oNew.setReserveOrigin("top");
                local nDirection, sEdge = oNew.getReserveFillDirection();
                fCheck(nDirection == nil and sEdge == "top" and oNew.getReserveOrigin() == "top",
                    "Perpendicular linear reserves retain their explicit edge without inventing a numeric direction.");
            end
            oNew.destroy(); oOld.destroy(); oNew.Control:Destroy(); oOld.Control:Destroy();
        end
    end, debug.traceback);
    for _, oMeter in ipairs(tOwned) do if (not oMeter.Disposed) then oMeter.destroy(); oMeter.Control:Destroy(); end end
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
    oFrame:Destroy(); _wx.wxYield(); oTheme.destroy(); oLuma.Theme.destroy();
    assert(bOK, sError);
    print("Unified progress regression: "..nChecks.." checks and "..nRenders.." renders passed.");
    return nChecks;
end

return UnifiedProgressRegression;
