--[[!
@fqxn wxLuma.Tests.ProgressReserveRegression
@desc Exercises real native rendering of reserves, independent geometry, circular
    pie/radial bands, state validation, events, no-op setters and owned resources.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Controls = require("wxLuma.Controls");
local _nChecks = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ProgressReserveRegression.check
@desc Counts assertions and reports the violated contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ProgressReserveRegression.pixels
@desc Captures the production draw method into an owned image.
!]]
local function pixels(oComponent)
    local oBitmap = _wx.wxBitmap(100, 100);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oComponent.draw(oDC, 100, 100);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    oDC:delete();
    oBitmap:delete();
    return oImage;
end

--[[!
@fqxn wxLuma.Tests.ProgressReserveRegression.state
@desc Recognizes solid fixture pixels, excluding antialiased boundaries.
!]]
local function state(oImage, nX, nY)
    local nR, nG, nB = oImage:GetRed(nX, nY), oImage:GetGreen(nX, nY), oImage:GetBlue(nX, nY);

    if (nR == 220 and nG == 40 and nB == 180) then
        return "reserve";
    elseif (nR == 20 and nG == 210 and nB == 60) then
        return "fill";
    elseif (nR == 30 and nG == 60 and nB == 200) then
        return "track";
    end
end

--[[!
@fqxn wxLuma.Tests.ProgressReserveRegression.run
@desc Runs general resource tests without importing or modifying LuaEx.
!]]
local function run()
    local oRealSkin = _Controls.loadSkin();
    local tMaterials = {};
    local tSkin = {Font = oRealSkin.Font};
    local tColours = {
        Track = {30, 60, 200}, Fill = {20, 210, 60}, Reserve = {220, 40, 180}, Other = {24, 29, 36}
    };

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveRegression.fixtureSkin.getBitmap
    @desc Caches owned, solid fixture materials by part and requested size.
    !]]
    function tSkin.getBitmap(sName, nWidth, nHeight)
        local sPart = sName:match(" (Track) ") or sName:match(" (Fill) ")
            or sName:match(" (Reserve) ") or "Other";
        local sKey = sPart..":"..nWidth..":"..nHeight;

        if (not tMaterials[sKey]) then
            local tRGB = tColours[sPart];
            local oBitmap = _wx.wxBitmap(nWidth, nHeight);
            local oDC = _wx.wxMemoryDC();
            local oBrush = _wx.wxBrush(_wx.wxColour(table.unpack(tRGB)));
            oDC:SelectObject(oBitmap);
            oDC:SetBackground(oBrush);
            oDC:Clear();
            oDC:SelectObject(_wx.wxNullBitmap);
            oDC:delete();
            oBrush:delete();
            tMaterials[sKey] = oBitmap;
        end

        return tMaterials[sKey];
    end

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveRegression.fixtureSkin.draw
    @desc Draws the same stationary fixture material through the normal skin API.
    !]]
    function tSkin.draw(oDC, sName, nX, nY, nWidth, nHeight)
        oDC:DrawBitmap(tSkin.getBitmap(sName, nWidth, nHeight), nX, nY, false);
    end

    --[[!
    @fqxn wxLuma.Tests.ProgressReserveRegression.fixtureSkin.text
    @desc Suppresses text so geometry assertions inspect only meter pixels.
    !]]
    function tSkin.text()
        -- Pixel tests intentionally omit captions.
    end

    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Reserve regression",
        _wx.wxDefaultPosition, _wx.wxSize(800, 500));
    local tComponents = {};

    for _, sKind in ipairs({"progress", "circularProgress", "globeProgress", "radialProgress"}) do
        local oComponent = _Controls[sKind](oFrame, {
            Skin = tSkin, Min = 10, Max = 110, Value = 40, Text = "", Appearance = "skin"
        });
        tComponents[#tComponents + 1] = oComponent;
        oComponent.layout(0, 0, 100, 100);
        check(oComponent.getReserved() == 0 and oComponent.getEffectiveMax() == 110, sKind.." defaults");
        local nEvents, nValues = 0, 0;
        oComponent.on("reservedChanged", function(oSender, tEvent)
            nEvents = nEvents + 1;
            check(oSender == oComponent and tEvent.EffectiveMax == oComponent.getEffectiveMax(), "coherent reserve event");
        end);
        oComponent.on("valueChanged", function()
            nValues = nValues + 1;
        end);
        oComponent.setReserved(20, true);
        oComponent.setReserved(20, true);
        check(nEvents == 1 and nValues == 0 and oComponent.getValue() == 40, "reserve preserves current and no-op silence");
        check(oComponent.getEffectiveMax() == 90 and not oComponent.isFull(), "effective capacity");

        for _, nInvalid in ipairs({-1, 101, math.huge, 0/0}) do
            check(not pcall(oComponent.setReserved, nInvalid, true) and oComponent.getReserved() == 20,
                "invalid reserve is atomic");
        end

        local tPolicies;

        if (oComponent.setReserveOrigin) then
            tPolicies = {"left", "right", "top", "bottom", "auto"};
        elseif (sKind == "circularProgress") then
            tPolicies = {"CW", "CCW", "auto"};
            oComponent.setReserveStartAngle(-90, true);
            check(oComponent.getReserveStartAngle() == 270, "normalized reserve angle");
            oComponent.setReserveStartAngle(nil, true);
        else
            tPolicies = {"inward", "outward", "auto"};
        end

        for _, sPolicy in ipairs(tPolicies) do
            local sValue = sPolicy ~= "auto" and sPolicy or nil;

            if (oComponent.setReserveOrigin) then
                oComponent.setReserveOrigin(sValue, true);
            else
                oComponent.setReserveDirection(sValue, true);
            end

            oComponent.setValue(10);
            local oEmpty = pixels(oComponent);
            oComponent.setValue(90);
            local oFull = pixels(oComponent);
            local nReserve, nFill, nTrack, nChangedReserve = 0, 0, 0, 0;

            for nY = 0, 99 do
                for nX = 0, 99 do
                    local sEmpty, sFull = state(oEmpty, nX, nY), state(oFull, nX, nY);

                    if (sEmpty == "reserve") then
                        nReserve = nReserve + 1;
                        nChangedReserve = nChangedReserve + (sFull ~= "reserve" and 1 or 0);
                    end

                    nFill = nFill + (sFull == "fill" and 1 or 0);
                    nTrack = nTrack + (sFull == "track" and 1 or 0);
                end
            end

            check(nReserve > 0 and nFill > 0 and nTrack == 0, sKind.." full usable region: "..sPolicy);
            check(nChangedReserve == 0, "current never overwrites reserve");
            check(oComponent.isFull(), "full predicate");
            oComponent.setValue(40);
            local oPartial = pixels(oComponent);
            local nMismatches = 0;

            -- Independent scalar oracle checks intermediate geometry as well as
            -- full/empty endpoints. Unknown antialiased boundary colours are omitted.
            for nY = 6, 93 do
                for nX = 6, 93 do
                    local sActual = state(oPartial, nX, nY);

                    if (sActual) then
                        local nFill, nReserved, nThreshold;
                        local nDX, nDY = nX + 0.5 - 50, nY + 0.5 - 50;
                        local nRadius = math.sqrt(nDX * nDX + nDY * nDY) / 48;

                        if (sKind == "circularProgress") then
                            nFill = ((math.deg(math.atan(nDY, nDX)) + 90) % 360) / 360;
                            local bSame = sPolicy == "CW";
                            nReserved = bSame and nFill or (1 - nFill) % 1;
                            nThreshold = bSame and 0.5 or 0.3;
                        elseif (sKind == "radialProgress") then
                            nFill = nRadius;
                            local bSame = sPolicy == "outward";
                            nReserved = bSame and nRadius or 1 - nRadius;
                            nThreshold = bSame and 0.5 or 0.3;
                        else
                            local nLeft = sKind == "progress" and (nX + 0.5 - 4) / 92 or (nDX + 48) / 96;
                            local nTop = sKind == "progress" and (nY + 0.5 - 4) / 92 or (nDY + 48) / 96;
                            nFill = sKind == "progress" and nLeft or 1 - nTop;
                            local sNormal = sKind == "progress" and "left" or "bottom";
                            local sOpposite = sKind == "progress" and "right" or "top";
                            local sEdge = sPolicy == "auto" and sOpposite or sPolicy;
                            nReserved = sEdge == "left" and nLeft or sEdge == "right" and 1 - nLeft
                                or sEdge == "top" and nTop or 1 - nTop;
                            nThreshold = sEdge == sNormal and 0.5 or sEdge == sOpposite and 0.3 or 0.375;
                        end

                        local sExpected = nReserved < 0.2 and "reserve" or nFill < nThreshold and "fill" or "track";

                        if (sExpected ~= sActual) then
                            nMismatches = nMismatches + 1;
                        end
                    end
                end
            end

            check(nMismatches == 0, sKind.." partial fill oracle: "..sPolicy.." mismatches="..nMismatches);
            oPartial:delete();
            oEmpty:delete();
            oFull:delete();
        end

        oComponent.setReserved(100);
        oComponent.setValue(10);
        local oAllReserved = pixels(oComponent);
        local nFill, nTrack = 0, 0;

        for nY = 0, 99 do
            for nX = 0, 99 do
                local sState = state(oAllReserved, nX, nY);
                nFill = nFill + (sState == "fill" and 1 or 0);
                nTrack = nTrack + (sState == "track" and 1 or 0);
            end
        end

        check(nFill == 0 and nTrack == 0 and oComponent.isFull(), "entire capacity reserved");
        oAllReserved:delete();
        oComponent.setReserved(20);
        oComponent.setValue(110);
        check(oComponent.getValue() == 110 and oComponent.isFull(), "over-effective current retained and saturated");
        oComponent.setEnabled(false);
        local oDisabled = pixels(oComponent);
        oDisabled:delete();
        oComponent.setAppearance("colour");
        local oColour = pixels(oComponent);
        oColour:delete();
        oComponent.setEnabled(true);
        oComponent.setAppearance("skin");
    end

    local oCircle, oRadial = tComponents[2], tComponents[4];

    for _, oComponent in ipairs({oCircle, oRadial}) do
        oComponent.setReserved(0);
        oComponent.setRadii(0, 100, true);
        oComponent.setValue(110);
        local oPie = pixels(oComponent);
        check(state(oPie, 50, 50) == "fill", "solid center fill");
        oPie:delete();
        oComponent.setRadii(25, 60, true);
        local oBand = pixels(oComponent);
        check(state(oBand, 50, 50) == nil and state(oBand, 70, 50) == "fill"
            and state(oBand, 90, 50) == nil, "inner and outer radius bounds");
        oBand:delete();
        check(not pcall(oComponent.setRadii, 80, 20), "invalid radii rejected");
        local nInner, nOuter = oComponent.getRadii();
        check(nInner == 25 and nOuter == 60, "invalid radii preserve state");
        oComponent.setReserved(20);
        local oReservedBand = pixels(oComponent);
        check(state(oReservedBand, 50, 50) == nil and state(oReservedBand, 90, 50) == nil,
            "reserve respects radial band");
        oReservedBand:delete();
        oComponent.setRadii(nil, nil);
    end

    -- Independently march the circular path to verify rotated, wrapped reserve
    -- sectors. This oracle does not use the production interval/intersection math.
    oCircle.setRadii(0, 100);
    oCircle.setReserved(20);
    oCircle.setValue(40);
    oCircle.setStartAngle(45);

    for _, sDirection in ipairs({"CW", "CCW"}) do
        oCircle.setDirection(sDirection);

        for _, sReserveDirection in ipairs({"CW", "CCW"}) do
            oCircle.setReserveDirection(sReserveDirection);

            for _, nAngle in ipairs({130, 350}) do
                oCircle.setReserveStartAngle(nAngle);
                local nUsableSteps, nThreshold = 0, 0;

                for nStep = 0, 9999 do
                    local nClock = (45 + (sDirection == "CW" and 1 or -1) * nStep * 360 / 10000) % 360;
                    local nReserve = (sReserveDirection == "CW" and (nClock - nAngle)
                        or (nAngle - nClock)) % 360 / 360;

                    if (nReserve >= 0.2) then
                        nUsableSteps = nUsableSteps + 1;
                    end

                    nThreshold = nStep / 10000;

                    if (nUsableSteps >= 3000) then
                        break;
                    end
                end

                local oRotated = pixels(oCircle);
                local nMismatches = 0;

                for nY = 8, 91 do
                    for nX = 8, 91 do
                        local sActual = state(oRotated, nX, nY);

                        if (sActual) then
                            local nClock = (math.deg(math.atan(nY + 0.5 - 50, nX + 0.5 - 50)) + 90) % 360;
                            local nFill = (sDirection == "CW" and (nClock - 45) or (45 - nClock)) % 360 / 360;
                            local nReserve = (sReserveDirection == "CW" and (nClock - nAngle)
                                or (nAngle - nClock)) % 360 / 360;
                            local sExpected = nReserve < 0.2 and "reserve" or nFill < nThreshold and "fill" or "track";

                            if (sExpected ~= sActual and math.abs(nFill - nThreshold) > 0.001) then
                                nMismatches = nMismatches + 1;
                            end
                        end
                    end
                end

                check(nMismatches == 0, "rotated reserve oracle "..sDirection.."/"..sReserveDirection.."/"..nAngle);
                oRotated:delete();
            end
        end
    end

    -- Repeated unchanged draws exercise owned raster reuse, then double disposal.
    for _, oComponent in ipairs(tComponents) do
        local oFirst = pixels(oComponent);
        local oSecond = pixels(oComponent);
        check(oFirst:GetData() == oSecond:GetData(), "cached repeat draw parity");
        oFirst:delete();
        oSecond:delete();
        oComponent.destroy();
        oComponent.destroy();
        check(oComponent.Disposed, "idempotent destruction");
    end

    local oPreview = _wx.wxBitmap(900, 260);
    local oPreviewDC = _wx.wxMemoryDC();
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oPreviewDC:SelectObject(oPreview);
    oPreviewDC:SetBackground(oBackground);
    oPreviewDC:Clear();

    for nIndex, sKind in ipairs({"progress", "circularProgress", "globeProgress", "radialProgress"}) do
        local oSample = _Controls[sKind](oFrame, {Skin = oRealSkin, Min = 0, Max = 100,
            Value = 45, Reserved = 25, Text = "", Appearance = "skin"});

        if (sKind == "circularProgress") then
            oSample.setRadii(0, 100);
        end

        oPreviewDC:SetDeviceOrigin(20 + (nIndex - 1) * 220, 30);
        oSample.draw(oPreviewDC, 200, sKind == "progress" and 80 or 200);
        oPreviewDC:SetDeviceOrigin(0, 0);
        oRealSkin.text(oPreviewDC, sKind, 24 + (nIndex - 1) * 220, 238, true);
        oSample.destroy();
    end

    oPreviewDC:SelectObject(_wx.wxNullBitmap);
    local oPreviewImage = oPreview:ConvertToImage();
    check(oPreviewImage:SaveFile(APP_PATH.."/Tests/ProgressReservePreview.png", _wx.wxBITMAP_TYPE_PNG),
        "production skin preview saved");
    oPreviewImage:delete();
    oPreviewDC:delete();
    oBackground:delete();
    oPreview:delete();
    oFrame:Destroy();
    _wx.wxGetApp():Yield();

    for _, oBitmap in pairs(tMaterials) do
        oBitmap:delete();
    end

    oRealSkin.destroy();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(7);
    tWorkbench.Layout();
    _wx.wxYield();
    tWorkbench.Widgets.OrbReserved.setValue(25, true);

    for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "CircularProgress", "Progress"}) do
        check(tWorkbench.Widgets[sKey].getReserved() == 25, "workbench reserve slider: "..sKey);
    end

    check(tWorkbench.Widgets.OrbReserved.Control:IsShownOnScreen()
        and not tWorkbench.Widgets.CircularPie.Control:IsShownOnScreen(), "orb page contains reserve controls only");
    tWorkbench.Widgets.Tabs.setValue(3);
    tWorkbench.Layout();
    _wx.wxYield();
    check(tWorkbench.Widgets.CircularPie.Control:IsShownOnScreen()
        and tWorkbench.Widgets.CircularPie.Control:GetParent():GetId()
            == tWorkbench.Widgets.CircularProgress.Control:GetParent():GetId(),
        "solid pie option belongs beside circular meter");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

run();
print("Progress reserve regression passed: ".._nChecks.." checks.");
