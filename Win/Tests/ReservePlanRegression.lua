--[[!
@fqxn wxLuma.Tests.ReservePlanRegression
@desc Compares prepared disc drawing against the original analytic mask, and
    checks that reserve setters prepare each independent disc before returning.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Reserve = require("wxLuma.Core.ControlProgressReserve");
local _Controls = require("wxLuma")().Controls;
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.ReservePlanRegression.check
@desc Counts successful assertions and identifies a violated rendering contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ReservePlanRegression.coordinate
@desc Evaluates an independent reference coordinate at a supersampled pixel center.
!]]
local function coordinate(tGeometry, nX, nY)
    nX, nY = nX + 0.5, nY + 0.5;
    local nCenter, nRadius, nInner = tGeometry.Center, tGeometry.Radius, tGeometry.Inner;
    local nDistance = math.sqrt((nX - nCenter)^2 + (nY - nCenter)^2);

    if (nDistance < nInner or nDistance >= nRadius) then
        return nil;
    end

    if (tGeometry.Kind == "radial") then
        local nRadial = (nDistance - nInner) / (nRadius - nInner);
        return tGeometry.Direction == "outward" and nRadial or 1 - nRadial,
            tGeometry.ReserveDirection == "outward" and nRadial or 1 - nRadial;
    end

    --[[!
    @fqxn wxLuma.Tests.ReservePlanRegression.coordinate.linear
    @desc Measures distance from a globe's selected edge along its full diameter.
    !]]
    local function fLinear(sOrigin)
        if (sOrigin == "left") then
            return (nX - nCenter + nRadius) / (2 * nRadius);
        elseif (sOrigin == "right") then
            return (nCenter + nRadius - nX) / (2 * nRadius);
        elseif (sOrigin == "top") then
            return (nY - nCenter + nRadius) / (2 * nRadius);
        end

        return (nCenter + nRadius - nY) / (2 * nRadius);
    end

    return fLinear(tGeometry.Origin), fLinear(tGeometry.ReserveOrigin);
end

--[[!
@fqxn wxLuma.Tests.ReservePlanRegression.run
@desc Checks native pixel parity for same/opposite/perpendicular reserve policies,
    saturation, radial bands, and synchronous per-instance preparation hooks.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local tBrushes = {Track = _wx.wxBrush(_wx.wxColour(20, 40, 180)),
        Fill = _wx.wxBrush(_wx.wxColour(20, 210, 60)), Reserve = _wx.wxBrush(_wx.wxColour(220, 40, 180))};
    local oBackground = _wx.wxBrush(_wx.wxColour(0, 0, 0));
    local oBitmap = _wx.wxBitmap(96, 96);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oDC:SetBackground(oBackground);
    oDC:SetPen(_wx.wxTRANSPARENT_PEN);
    local tCases = {};

    for _, sOrigin in ipairs({"left", "right", "top", "bottom"}) do
        for _, sReserve in ipairs({"left", "right", "top", "bottom"}) do
            tCases[#tCases + 1] = {Kind = "globe", Center = 48, Radius = 44, Inner = 0,
                Origin = sOrigin, ReserveOrigin = sReserve};
        end
    end

    for _, sDirection in ipairs({"inward", "outward"}) do
        for _, sReserve in ipairs({"inward", "outward"}) do
            for _, nInner in ipairs({0, 12.5}) do
                tCases[#tCases + 1] = {Kind = "radial", Center = 48, Radius = 43.5, Inner = nInner,
                    Direction = sDirection, ReserveDirection = sReserve};
            end
        end
    end

    for nCase, tGeometry in ipairs(tCases) do
        local fCoordinates = function(nX, nY)
            return coordinate(tGeometry, nX, nY);
        end;

        for _, nReserve in ipairs({0, 0.01, 0.25, 0.5, 0.6, 1}) do
            local tPlan = _Reserve.prepareDisc(96, nReserve, tGeometry, fCoordinates, "strips");
            local tNative = _Reserve.prepareDisc(96, nReserve, tGeometry, fCoordinates);
            check(tNative.Renderer == "native" and #tNative.Base == 0 and next(tNative.Rows) == nil,
                "Supported discs use native shapes without preparing scanline spans.");
            oDC:Clear();
            _Reserve.drawDiscBase(oDC, tNative, tBrushes);
            local oBase = oBitmap:ConvertToImage();
            local sBase = oBase:GetData();
            oBase:delete();

            for _, nCurrent in ipairs({0, 0.01, 0.25, 0.5, 0.75, 0.99, 1}) do
                oDC:Clear();
                _Reserve.drawMask(oDC, 96, 96, fCoordinates, nReserve, nCurrent, tBrushes, tGeometry);
                local oReference = oBitmap:ConvertToImage();
                local sReference = oReference:GetData();
                oDC:Clear();
                _Reserve.drawDiscBase(oDC, tPlan, tBrushes);
                oDC:SetBrush(tBrushes.Fill);
                _Reserve.drawDiscFill(oDC, tPlan, nCurrent * (1 - nReserve));
                local oPrepared = oBitmap:ConvertToImage();
                local bEqual = oReference:GetData() == oPrepared:GetData();
                oReference:delete();
                oPrepared:delete();
                check(bEqual, "Prepared/reference pixel parity: case "..nCase..", reserve "..nReserve..", current "..nCurrent);

                oDC:Clear();
                _Reserve.drawDiscBase(oDC, tNative, tBrushes);
                _Reserve.drawDiscFill(oDC, tNative, nCurrent * (1 - nReserve), tBrushes);
                local oNative = oBitmap:ConvertToImage();
                local sNative = oNative:GetData();
                oNative:delete();
                local bClipped, bBounded = true, true;

                -- Native circle rounding can differ at the supersampled edge.
                -- Interiors must agree; all reserve/background pixels must stay
                -- untouched regardless of the selected current value.
                for nByte = 1, #sReference, 3 do
                    local sPixel = sNative:sub(nByte, nByte + 2);
                    local sOriginal = sReference:sub(nByte, nByte + 2);
                    local nBaseRed = sBase:byte(nByte);

                    if ((nBaseRed == 0 or nBaseRed == 220) and sPixel ~= sBase:sub(nByte, nByte + 2)) then
                        bClipped = false;
                    end

                    if (sPixel ~= sOriginal) then
                        local nPixel = (nByte - 1) / 3;
                        local nX, nY = nPixel % 96, math.floor(nPixel / 96);
                        local bNearEdge = false;

                        for nDY = -2, 2 do
                            for nDX = -2, 2 do
                                local nOtherX, nOtherY = nX + nDX, nY + nDY;

                                if (nOtherX >= 0 and nOtherX < 96 and nOtherY >= 0 and nOtherY < 96) then
                                    local nOther = (nOtherY * 96 + nOtherX) * 3 + 1;
                                    bNearEdge = bNearEdge or sReference:sub(nOther, nOther + 2) ~= sOriginal;
                                end
                            end
                        end

                        bBounded = bBounded and bNearEdge;
                    end
                end

                check(bClipped, "Native fill preserves reserve and background: case "..nCase..", reserve "..nReserve);
                check(bBounded, "Native/reference interiors agree: case "..nCase..", reserve "..nReserve..", current "..nCurrent);
            end

            _Reserve.releaseDisc(tPlan);
            _Reserve.releaseDisc(tNative);
            _Reserve.releaseDisc(tNative);
        end
    end

    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    oBitmap:delete();
    oBackground:delete();

    for _, oBrush in pairs(tBrushes) do
        oBrush:delete();
    end

    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Reserve preparation regression");
    local tMeters = {};
    local nPrepared = 0;
    local nBases = 0;
    local fPrepare = _Reserve.prepareDisc;
    local fBase = _Reserve.drawDiscBase;
    local fMask = _Reserve.drawMask;
    local nStripPasses = 0;
    _Reserve.prepareDisc = function(...)
        nPrepared = nPrepared + 1;
        return fPrepare(...);
    end;
    _Reserve.drawDiscBase = function(...)
        nBases = nBases + 1;
        return fBase(...);
    end;
    _Reserve.drawMask = function(...)
        nStripPasses = nStripPasses + 1;
        return fMask(...);
    end;
    local bOK, sError = pcall(function()
        for _, sFactory in ipairs({"globeProgress", "radialProgress"}) do
            local oMeter = _Controls[sFactory](oFrame, {Skin = oSkin, Min = 0, Max = 100, Value = 35, Supersampling = 2});
            tMeters[#tMeters + 1] = oMeter;
            oMeter.layout(0, 0, 220, 220);
            check(oMeter.getReserveRenderer() == "auto", "Native rendering is the default policy.");
            local nBefore = nPrepared;
            local nBaseBefore = nBases;
            oMeter.setReserved(25, false);
            check(nPrepared == nBefore + 1, "Silent reserve setter prepares geometry before any draw.");
            check(nBases == nBaseBefore + 1, "Silent reserve setter builds its fixed image before any draw.");
            oMeter.setReserved(25, true);
            check(nPrepared == nBefore + 1, "Unchanged reserve does no preparation.");
            oMeter.setValue(50);
            check(nPrepared == nBefore + 1, "Value changes do not rebuild reserve geometry.");

            if (sFactory == "globeProgress") then
                oMeter.setReserveOrigin("left");
                check(nPrepared == nBefore + 2, "Reserve origin prepares immediately.");
                oMeter.setOrigin("right");
                check(nPrepared == nBefore + 3, "Current origin updates dependent reserve geometry immediately.");
            else
                oMeter.setReserveDirection("outward");
                check(nPrepared == nBefore + 2, "Reserve direction prepares immediately.");
                oMeter.setRadii(15, 90);
                check(nPrepared == nBefore + 3, "Radii prepare immediately.");
            end

            oMeter.setSupersampling(4);
            check(nPrepared == nBefore + 4, "Quality changes prepare at the new resolution immediately.");
            oMeter.layout(0, 0, 180, 180);
            check(nPrepared == nBefore + 5, "Layout changes prepare at the new size immediately.");

            oMeter.on("reservedChanged", function()
                check(nPrepared == nBefore + 6, "Reserve observers see prepared geometry.");
                check(nBases == nBaseBefore + 5, "Reserve observers see the rebuilt base image.");
            end);
            oMeter.setReserved(40, true);
            local nAfter = nPrepared;
            local nBaseAfter = nBases;
            local oProbe = _wx.wxBitmap(180, 180);
            local oProbeDC = _wx.wxMemoryDC();
            oProbeDC:SelectObject(oProbe);
            oMeter.draw(oProbeDC, 180, 180);
            check(nPrepared == nAfter and nBases == nBaseAfter,
                "First draw after reserve change performs no deferred reserve preparation.");
            oMeter.setValue(100);
            oMeter.draw(oProbeDC, 180, 180);
            local fBitmap = _wx.wxBitmap;
            local nAllocations = 0;
            _wx.wxBitmap = function(...)
                nAllocations = nAllocations + 1;
                return fBitmap(...);
            end;
            local bDrawOK, sDrawError = pcall(function()
                oMeter.setValue(80);
                oMeter.draw(oProbeDC, 180, 180);
            end);
            _wx.wxBitmap = fBitmap;
            oProbeDC:SelectObject(_wx.wxNullBitmap);
            oProbeDC:delete();
            oProbe:delete();
            assert(bDrawOK, sDrawError);
            check(nAllocations == 0, "Values beyond usable capacity reuse the saturated disc image.");
            check(nStripPasses == 0, "Default preparation and drawing never invoke the strip rasterizer.");
        end

        for _, oMeter in ipairs(tMeters) do
            local nBefore = nStripPasses;
            local nEvents = 0;
            oMeter.on("reserveRendererChanged", function(oSender, tEvent)
                check(oSender == oMeter and tEvent.ReserveRenderer == oMeter.getReserveRenderer(),
                    "Renderer event observes the committed selection.");
                nEvents = nEvents + 1;
            end);
            oMeter.setReserveRenderer("strips", true);
            check(nStripPasses == nBefore + 1 and oMeter.getReserveRenderer() == "strips",
                "Explicit strip policy preserves the analytic fallback.");
            oMeter.setReserveRenderer("strips", true);
            check(nStripPasses == nBefore + 1 and nEvents == 1, "Repeated renderer selection is silent.");
            oMeter.setReserveRenderer("native", true);
            check(nStripPasses == nBefore + 1 and nEvents == 2, "Native selection leaves the strip path.");
            local bAccepted = pcall(oMeter.setReserveRenderer, "invalid");
            check(not bAccepted and oMeter.getReserveRenderer() == "native", "Invalid renderer preserves state.");
        end
    end);
    _Reserve.prepareDisc = fPrepare;
    _Reserve.drawDiscBase = fBase;
    _Reserve.drawMask = fMask;

    for _, oMeter in ipairs(tMeters) do
        oMeter.destroy();
    end

    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxGetApp():Yield();
    assert(bOK, sError);
end

run();
print("Reserve plan regression: ".._nChecks.." checks passed.");
