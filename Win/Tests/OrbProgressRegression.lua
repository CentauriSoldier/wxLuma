--[[!
@fqxn wxLuma.Tests.OrbProgressRegression
@desc Verifies globe/radial geometry, custom materials, antialiasing, object/event
    identity, runtime policies, cache reuse, disposal and workbench demonstrations.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
local _tFixtures = {};
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.OrbProgressRegression.check
@desc Counts assertions and identifies the failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.OrbProgressRegression.pixels
@desc Returns an owned native image rendered by the production draw method.
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
@fqxn wxLuma.Tests.OrbProgressRegression.samePixel
@desc Compares a point against a reference while allowing arbitrary skin materials.
!]]
local function samePixel(oLeft, oRight, nX, nY)
    return oLeft:GetRed(nX, nY) == oRight:GetRed(nX, nY)
        and oLeft:GetGreen(nX, nY) == oRight:GetGreen(nX, nY)
        and oLeft:GetBlue(nX, nY) == oRight:GetBlue(nX, nY);
end

--[[!
@fqxn wxLuma.Tests.OrbProgressRegression.colour
@desc Checks a pixel against a known solid fixture colour.
!]]
local function colour(oImage, nX, nY, nR, nG, nB)
    return oImage:GetRed(nX, nY) == nR and oImage:GetGreen(nX, nY) == nG
        and oImage:GetBlue(nX, nY) == nB;
end

--[[!
@fqxn wxLuma.Tests.OrbProgressRegression.click
@desc Dispatches native mouse callbacks using event-local coordinates. This tests
    callback routing rather than simulated hardware input.
!]]
local function click(oComponent, bRight)
    local tTypes = bRight and {_wx.wxEVT_RIGHT_DOWN, _wx.wxEVT_RIGHT_UP}
        or {_wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP};

    for _, nType in ipairs(tTypes) do
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
@fqxn wxLuma.Tests.OrbProgressRegression.run
@desc Exercises both independent identities and the common renderer on real DCs.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Orb progress regression",
        _wx.wxDefaultPosition, _wx.wxSize(700, 450));
    local oGlobe = _Controls.globeProgress(oFrame, {Skin = oSkin, Min = 10, Max = 110,
        Value = 35, Text = "", Colour = {R = 200, G = 100, B = 50}});
    local oRadial = _Controls.radialProgress(oFrame, {Skin = oSkin, Min = 10, Max = 110,
        Value = 60, Text = "", Colour = {R = 200, G = 100, B = 50}});
    oGlobe.layout(0, 0, 100, 100);
    oRadial.layout(120, 0, 100, 100);
    oFrame:Show();
    _wx.wxYield();
    check(oGlobe.getOrigin() == "bottom" and oGlobe.getOrientation() == "vertical", "Globe defaults bottom-up.");
    check(oRadial.getDirection() == "outward", "Radial defaults outward.");

    for _, oComponent in ipairs({oGlobe, oRadial}) do
        check(next(oComponent) == nil and getmetatable(oComponent) == "wxLuma.UI."..oComponent.Kind,
            "Each new object has its own actual/decoy/metatable identity.");
        check(oComponent.getContainment() ~= nil, "Shared containment is installed.");
        local nRight = 0;
        oComponent.on("rightClick", function(oSource)
            check(oSource == oComponent, "Native input event returns public object.");
            nRight = nRight + 1;
        end);
        click(oComponent, true);
        check(nRight == 1, "Standard right-click subscriptions work.");
    end

    local tSamples = {
        {"bottom", 50, 85, 50, 15},
        {"top", 50, 15, 50, 85},
        {"left", 15, 50, 85, 50},
        {"right", 85, 50, 15, 50}
    };

    for _, sAppearance in ipairs({"colour", "skin"}) do
        oGlobe.setAppearance(sAppearance);
        oRadial.setAppearance(sAppearance);
        oGlobe.setValue(10);
        local oEmpty = pixels(oGlobe, 100, 100);
        oGlobe.setValue(110);
        local oFull = pixels(oGlobe, 100, 100);
        oGlobe.setValue(35);

        for _, tSample in ipairs(tSamples) do
            oGlobe.setOrigin(tSample[1]);
            local oPartial = pixels(oGlobe, 100, 100);
            check(samePixel(oPartial, oFull, tSample[2], tSample[3]), "Globe fills from "..tSample[1].." in "..sAppearance);
            check(samePixel(oPartial, oEmpty, tSample[4], tSample[5]), "Opposite globe side remains track.");
            check(not samePixel(oPartial, oEmpty, tSample[2], tSample[3]), "Globe fill is visible.");
            check(colour(oPartial, 5, 5, 24, 29, 36), "Globe fill stays within circular silhouette.");
            oPartial:delete();
        end

        oEmpty:delete();
        oFull:delete();
        oRadial.setValue(10);
        oEmpty = pixels(oRadial, 100, 100);
        oRadial.setValue(110);
        oFull = pixels(oRadial, 100, 100);

        for _, sDirection in ipairs({"outward", "inward"}) do
            oRadial.setDirection(sDirection);
            oRadial.setValue(60);
            local oPartial = pixels(oRadial, 100, 100);
            local nFillX = sDirection == "outward" and 50 or 90;
            local nTrackX = sDirection == "outward" and 90 or 50;
            check(samePixel(oPartial, oFull, nFillX, 50), "Radial fill follows "..sDirection);
            check(samePixel(oPartial, oEmpty, nTrackX, 50), "Radial unfilled portion stays track.");
            check(not samePixel(oPartial, oEmpty, nFillX, 50), "Radial fill is visible.");
            oPartial:delete();
            oRadial.setValue(10);
            oPartial = pixels(oRadial, 100, 100);
            check(samePixel(oPartial, oEmpty, 50, 50) and samePixel(oPartial, oEmpty, 90, 50), "Radial minimum is empty in both directions.");
            oPartial:delete();
            oRadial.setValue(110);
            oPartial = pixels(oRadial, 100, 100);
            check(samePixel(oPartial, oFull, 50, 50) and samePixel(oPartial, oFull, 90, 50), "Radial maximum is full in both directions.");
            oPartial:delete();
        end

        oEmpty:delete();
        oFull:delete();
    end

    oGlobe.setOrigin("left");
    oGlobe.setOrientation("vertical");
    check(oGlobe.getOrigin() == "bottom", "Forward globe origins map left/bottom.");
    oGlobe.setOrigin("top");
    oGlobe.setOrientation("horizontal");
    check(oGlobe.getOrigin() == "right", "Reverse globe origins map top/right.");
    local nOrigins, nOrientations, nDirections = 0, 0, 0;
    oGlobe.on("originChanged", function(oSource, tEvent)
        check(oSource == oGlobe and tEvent.Origin == "bottom" and tEvent.OldOrigin == "right", "Globe origin event payload.");
        nOrigins = nOrigins + 1;
    end);
    oGlobe.on("orientationChanged", function(oSource, tEvent)
        check(oSource == oGlobe and tEvent.Orientation == "vertical", "Globe orientation event payload.");
        nOrientations = nOrientations + 1;
    end);
    oRadial.on("directionChanged", function(oSource, tEvent)
        check(oSource == oRadial and tEvent.Direction == "outward" and tEvent.OldDirection == "inward", "Radial direction event payload.");
        nDirections = nDirections + 1;
    end);
    oGlobe.setOrigin("bottom", true);
    oGlobe.setOrigin("bottom", true);
    oRadial.setDirection("outward", true);
    oRadial.setDirection("outward", true);
    check(nOrigins == 1 and nOrientations == 1 and nDirections == 1, "Geometry changes notify once.");

    for _, oComponent in ipairs({oGlobe, oRadial}) do
        local nChanges, nValues, nAppearance = 0, 0, 0;
        oComponent.OnChange = function(nValue, oSource)
            check(oSource == oComponent and oSource.getValue() == nValue, "OnChange receives exact proxy.");
            nChanges = nChanges + 1;
        end;
        oComponent.on("valueChanged", function(oSource, tEvent)
            check(oSource == oComponent and tEvent.Value == oSource.getValue(), "Value event payload.");
            nValues = nValues + 1;
        end);
        oComponent.on("appearanceChanged", function(oSource, tEvent)
            check(oSource == oComponent and tEvent.Appearance == "colour", "Appearance event payload.");
            nAppearance = nAppearance + 1;
        end);
        oComponent.setAppearance("colour", true);
        oComponent.setAppearance("colour", true);
        check(nAppearance == 1, "Appearance changed-only event.");
        oComponent.setValue(40, true);
        oComponent.setValue(40, true);
        check(nChanges == 1 and nValues == 1, "Value changed-only notification.");
        oComponent.setValue(-1);
        check(oComponent.getValue() == 10, "Clamps below minimum.");
        oComponent.setValue(999);
        check(oComponent.getValue() == 110 and nChanges == 1, "Clamps above maximum silently.");
        check(not pcall(oComponent.setValue, 0 / 0) and not pcall(oComponent.setValue, math.huge), "Reject nonfinite progress.");
        check(not pcall(oComponent.setAppearance, "invalid"), "Reject invalid appearance.");
        local oImage = pixels(oComponent, 200, 100);
        check(colour(oImage, 100, 50, 200, 100, 50) and colour(oImage, 20, 50, 24, 29, 36), "Rectangular bounds center a circle.");
        oImage:delete();
        oComponent.setEnabled(false);
        oImage = pixels(oComponent, 100, 100);
        check(colour(oImage, 50, 50, 61, 67, 73), "Disabled colour fill.");
        oImage:delete();
        oComponent.setEnabled(true);
        local nRefreshes = 0;
        local fRefresh = oComponent.refresh;
        oComponent.refresh = function()
            nRefreshes = nRefreshes + 1;
            return fRefresh();
        end;
        oComponent.setValue(110, true);
        oComponent.setAppearance("colour", true);
        check(nRefreshes == 0, "Unchanged visual setters do not refresh.");
        oImage = pixels(oComponent, 100, 100);
        local nMixed = 0;

        for nY = 0, 99 do
            for nX = 0, 99 do
                if (not colour(oImage, nX, nY, 200, 100, 50) and not colour(oImage, nX, nY, 24, 29, 36)) then
                    nMixed = nMixed + 1;
                end
            end
        end

        check(nMixed > 150, "Disc silhouettes contain antialiased coverage pixels.");
        oImage:delete();
        oImage = pixels(oComponent, 2, 2);
        oImage:delete();
    end

    check(not pcall(oGlobe.setOrigin, "middle") and not pcall(oGlobe.setOrientation, false), "Globe rejects invalid policy.");
    check(not pcall(oRadial.setDirection, "CW"), "Radial rejects angular direction.");
    local nMaterials = 0;
    local fBitmap = oSkin.getBitmap;
    oSkin.getBitmap = function(...)
        nMaterials = nMaterials + 1;
        return fBitmap(...);
    end;

    for _, oComponent in ipairs({oGlobe, oRadial}) do
        oComponent.setAppearance("skin");
        local oImage = pixels(oComponent, 100, 100);
        oImage:delete();
        local nFirstBuild = nMaterials;
        oImage = pixels(oComponent, 100, 100);
        oImage:delete();
        check(nMaterials == nFirstBuild, "Unchanged disc reuses raster without material requests.");
        oComponent.setEnabled(false);
        oImage = pixels(oComponent, 100, 100);
        oImage:delete();
        check(nMaterials == nFirstBuild + 2, "Disabled state loads its dedicated material pair.");
        oComponent.setEnabled(true);
    end

    -- External root and unmistakable solid materials prove both renderers use
    -- the supplied skin instead of their built-in colour fallback.
    local pTemp = assert(os.getenv("TEMP")):gsub("\\", "/").."/";
    local sArtwork = "wxLuma Orb Fixture "..os.time().." "..math.random(1000000);

    for _, tMaterial in ipairs({
        {"Track Normal", 120, 40, 170}, {"Fill Normal", 30, 210, 80},
        {"Track Disabled", 60, 40, 70}, {"Fill Disabled", 70, 100, 80}
    }) do
        local pFile = pTemp.."Control "..sArtwork.." "..tMaterial[1]..".png";
        local oImage = _wx.wxImage(16, 16);
        oImage:SetRGB(_wx.wxRect(0, 0, 16, 16), tMaterial[2], tMaterial[3], tMaterial[4]);
        check(oImage:SaveFile(pFile, _wx.wxBITMAP_TYPE_PNG), "Save custom material fixture.");
        _tFixtures[#_tFixtures + 1] = pFile;
        oImage:delete();
    end

    local oExternal = _Controls.loadSkin(pTemp);
    local oCustomGlobe = _Controls.globeProgress(oFrame, {Skin = oExternal, Min = 0, Max = 100,
        Value = 25, Text = "", Artwork = sArtwork});
    local oCustomRadial = _Controls.radialProgress(oFrame, {Skin = oExternal, Min = 0, Max = 100,
        Value = 50, Direction = "inward", Text = "", Artwork = sArtwork});
    local oImage = pixels(oCustomGlobe, 100, 100);
    check(colour(oImage, 50, 85, 30, 210, 80) and colour(oImage, 50, 15, 120, 40, 170), "Globe uses external root/materials.");
    oImage:delete();
    oImage = pixels(oCustomRadial, 100, 100);
    check(colour(oImage, 90, 50, 30, 210, 80) and colour(oImage, 50, 50, 120, 40, 170), "Radial uses external root/materials.");
    oImage:delete();
    oCustomGlobe.setEnabled(false);
    oImage = pixels(oCustomGlobe, 100, 100);
    check(colour(oImage, 50, 85, 70, 100, 80), "External disabled material used.");
    oImage:delete();
    oCustomGlobe.destroy();
    oCustomRadial.destroy();
    oExternal.destroy();

    for _, tOptions in ipairs({
        {Min = 0, Max = 0, Value = 0}, {Min = 0, Max = 1, Value = math.huge},
        {Min = 0, Max = 1, Value = 0, Appearance = false},
        {Min = 0, Max = 1, Value = 0, Colour = {R = -1, G = 0, B = 0}}
    }) do
        tOptions.Skin = oSkin;
        check(not pcall(_Controls.globeProgress, oFrame, tOptions), "Invalid globe creation rejected.");
        check(not pcall(_Controls.radialProgress, oFrame, tOptions), "Invalid radial creation rejected.");
    end
    check(not pcall(_Controls.globeProgress, oFrame, {Skin = oSkin, Min = 0, Max = 1,
        Value = 0, Orientation = "vertical", Origin = "left"}), "Conflicting globe geometry rejected.");
    check(not pcall(_Controls.radialProgress, oFrame, {Skin = oSkin, Min = 0, Max = 1,
        Value = 0, Direction = false}), "Invalid radial creation direction rejected.");

    -- Rapid changes exercise owned raster replacement and shared material reuse.
    for nIndex = 1, 100 do
        for _, oComponent in ipairs({oGlobe, oRadial}) do
            oComponent.setValue(nIndex + 10);
            oImage = pixels(oComponent, 100, 100);
            oImage:delete();
        end
    end

    for _, oComponent in ipairs({oGlobe, oRadial}) do
        local nDestroyed = 0;
        oComponent.on("destroyed", function()
            nDestroyed = nDestroyed + 1;
        end);
        oComponent.destroy();
        oComponent.destroy();
        check(nDestroyed == 1 and oComponent.Disposed, "Disposal is idempotent.");
    end

    -- Render a standalone visual check through the production draw path. These
    -- are control renders, not desktop captures or approximated mockups.
    local oPreview = _wx.wxBitmap(960, 280);
    local oPreviewDC = _wx.wxMemoryDC();
    local oPreviewBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oPreviewDC:SelectObject(oPreview);
    oPreviewDC:SetBackground(oPreviewBrush);
    oPreviewDC:Clear();
    local tPreview = {
        {"Globe / skin", _Controls.globeProgress, {}},
        {"Globe / colour", _Controls.globeProgress, {Colour = {R = 185, G = 50, B = 60}}},
        {"Radial / outward", _Controls.radialProgress, {Direction = "outward"}},
        {"Radial / inward", _Controls.radialProgress, {Direction = "inward"}}
    };

    for nIndex, tPreviewItem in ipairs(tPreview) do
        local tOptions = tPreviewItem[3];
        tOptions.Skin, tOptions.Min, tOptions.Max = oSkin, 0, 100;
        tOptions.Value, tOptions.Text = 65, "%v%";
        local oPreviewComponent = tPreviewItem[2](oFrame, tOptions);
        local nX = 30 + (nIndex - 1) * 240;
        oPreviewDC:SetDeviceOrigin(nX, 36);
        oPreviewComponent.draw(oPreviewDC, 180, 180);
        oPreviewDC:SetDeviceOrigin(0, 0);
        oSkin.text(oPreviewDC, tPreviewItem[1], nX + 16, 238, true);
        oPreviewComponent.destroy();
    end

    oPreviewDC:SelectObject(_wx.wxNullBitmap);
    local oPreviewImage = oPreview:ConvertToImage();
    check(oPreviewImage:SaveFile(APP_PATH.."/Tests/OrbProgressPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save production-render preview.");
    oPreviewImage:delete();
    oPreviewDC:delete();
    oPreviewBrush:delete();
    oPreview:delete();
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(7);
    tWorkbench.Layout();
    _wx.wxYield();
    local oGlobeDemo, oRadialDemo = tWorkbench.Widgets.GlobeProgress, tWorkbench.Widgets.RadialProgress;
    check(oGlobeDemo.Control:IsShownOnScreen() and oRadialDemo.Control:IsShownOnScreen(), "Orb meters category displays both new objects.");
    check(oGlobeDemo.getAppearance() == "skin" and oRadialDemo.getAppearance() == "skin", "Workbench starts skinned.");
    for _, sOrigin in ipairs({"top", "right", "left", "bottom"}) do
        click(tWorkbench.Widgets.GlobeOrigin);
        check(oGlobeDemo.getOrigin() == sOrigin and oGlobeDemo.getValue() == 65, "Workbench cycles globe origins without value change.");
    end
    click(tWorkbench.Widgets.RadialDirection);
    check(oRadialDemo.getDirection() == "inward" and oRadialDemo.getValue() == 65, "Workbench radial direction toggles.");
    click(tWorkbench.Widgets.GlobeSkin);
    click(tWorkbench.Widgets.RadialSkin);
    check(oGlobeDemo.getAppearance() == "colour" and oRadialDemo.getAppearance() == "colour", "Independent workbench skin switches.");
    tWorkbench.Widgets.OrbValue.setValue(23, true);
    check(oGlobeDemo.getValue() == 23 and oRadialDemo.getValue() == 23, "Shared orb slider drives both.");
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Layout();
    _wx.wxYield();
    local nGlobeX = oGlobeDemo.Control:GetPositionXY();
    local nRadialX = oRadialDemo.Control:GetPositionXY();
    local nGlobeWidth = oGlobeDemo.Control:GetSizeWH();
    check(nGlobeX + nGlobeWidth < nRadialX, "Minimum-size orb examples do not overlap.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

for _, pFile in ipairs(_tFixtures) do
    os.remove(pFile);
end

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Orb progress regression passed: ".._nChecks.." checks.");