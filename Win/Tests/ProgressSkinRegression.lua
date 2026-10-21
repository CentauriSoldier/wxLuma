--[[!
@fqxn wxLuma.Tests.ProgressSkinRegression
@desc Verifies material skin loading, antialiased ring/sector edges, colour
    compatibility, cache reuse, runtime appearance and workbench skin switches.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _pFramework = require("wxLuma")().Config.ImagePath;
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
local _tFixtures = {};
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ProgressSkinRegression.check
@desc Counts behavior assertions and identifies the failed contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ProgressSkinRegression.pixels
@desc Returns an owned image rendered through the component's production draw.
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
@fqxn wxLuma.Tests.ProgressSkinRegression.colour
@desc Tests a solid material pixel against expected RGB channels.
!]]
local function colour(oImage, nX, nY, tColour)
    return oImage:GetRed(nX, nY) == tColour[1] and oImage:GetGreen(nX, nY) == tColour[2]
        and oImage:GetBlue(nX, nY) == tColour[3];
end

--[[!
@fqxn wxLuma.Tests.ProgressSkinRegression.click
@desc Dispatches checkbox callback input with event-local coordinate accessors.
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
@fqxn wxLuma.Tests.ProgressSkinRegression.run
@desc Checks built-in assets and unmistakable external materials through real DCs.
!]]
local function run()
    local oSkin = _Controls.loadSkin();

    for _, sKind in ipairs({"Circular Progress", "Progress"}) do
        for _, sPart in ipairs({"Track", "Fill"}) do
            for _, sState in ipairs({"Normal", "Disabled"}) do
                local oImage = _wx.wxImage(_pFramework.."/Controls/Control "..sKind.." "..sPart.." "..sState..".png", _wx.wxBITMAP_TYPE_PNG);
                check(oImage:IsOk() and oImage:GetWidth() == 256, "Built-in progress material exists.");
                oImage:delete();
            end
        end
    end

    -- Solid fixture materials prove that supplied skin data, rather than the
    -- hard-coded colour mode, reaches both the circular and linear renderers.
    local pTemp = assert(os.getenv("TEMP")):gsub("\\", "/").."/";
    local sArtwork = "wxLuma Progress Fixture "..os.time().." "..math.random(1000000);
    local tMaterials = {
        {"Track Normal", {120, 40, 170}},
        {"Fill Normal", {30, 210, 80}},
        {"Track Disabled", {60, 40, 70}},
        {"Fill Disabled", {70, 100, 80}}
    };

    for _, tMaterial in ipairs(tMaterials) do
        local pFile = pTemp.."Control "..sArtwork.." "..tMaterial[1]..".png";
        check(io.open(pFile, "rb") == nil, "Fixture does not overwrite a file.");
        local oImage = _wx.wxImage(16, 16);
        oImage:SetRGB(_wx.wxRect(0, 0, 16, 16), table.unpack(tMaterial[2]));
        check(oImage:SaveFile(pFile, _wx.wxBITMAP_TYPE_PNG), "Write external skin fixture.");
        _tFixtures[#_tFixtures + 1] = pFile;
        oImage:delete();
    end

    local oExternal = _Controls.loadSkin(pTemp);
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Progress skin regression",
        _wx.wxDefaultPosition, _wx.wxSize(700, 400));
    local oCircle = _Controls.circularProgress(oFrame, {Skin = oExternal, Min = 0, Max = 100,
        Value = 25, Text = "", Artwork = sArtwork});
    local oLinear = _Controls.progress(oFrame, {Skin = oExternal, Min = 0, Max = 100,
        Value = 25, Text = "", Artwork = sArtwork, Appearance = "skin"});
    local oColour = _Controls.circularProgress(oFrame, {Skin = oSkin, Min = 0, Max = 100,
        Value = 100, Text = "", Colour = {R = 200, G = 100, B = 50}});
    oCircle.layout(0, 0, 100, 100);
    oLinear.layout(150, 0, 208, 40);
    oColour.layout(400, 0, 100, 100);
    check(oCircle.getAppearance() == "skin", "Circle defaults to skin.");
    check(oColour.getAppearance() == "colour", "Explicit Colour preserves colour mode.");
    local nMaterials = 0;
    local fBitmap = oExternal.getBitmap;
    oExternal.getBitmap = function(...)
        nMaterials = nMaterials + 1;
        return fBitmap(...);
    end;
    local oImage = pixels(oCircle, 100, 100);
    check(colour(oImage, 80, 20, {30, 210, 80}), "Circular fill uses external material.");
    check(colour(oImage, 20, 20, {120, 40, 170}), "Circular track uses external material.");
    oImage:delete();
    local nFirstBuild = nMaterials;
    oImage = pixels(oCircle, 100, 100);
    oImage:delete();
    check(nFirstBuild == 2 and nMaterials == nFirstBuild, "Unchanged ring reuses raster without loading materials.");
    oCircle.setDirection("CCW");
    oImage = pixels(oCircle, 100, 100);
    check(colour(oImage, 20, 20, {30, 210, 80}) and colour(oImage, 80, 20, {120, 40, 170}), "Skinned direction switches at runtime.");
    oImage:delete();
    oCircle.setEnabled(false);
    oImage = pixels(oCircle, 100, 100);
    check(colour(oImage, 20, 20, {70, 100, 80}), "Circle disabled fill uses disabled artwork.");
    check(colour(oImage, 80, 20, {60, 40, 70}), "Circle disabled track uses disabled artwork.");
    oImage:delete();
    oCircle.setEnabled(true);
    oImage = pixels(oLinear, 208, 40);
    check(colour(oImage, 20, 20, {30, 210, 80}) and colour(oImage, 100, 20, {120, 40, 170}), "Linear fill and track use external skin.");
    oImage:delete();
    oLinear.setEnabled(false);
    oImage = pixels(oLinear, 208, 40);
    check(colour(oImage, 20, 20, {70, 100, 80}), "Linear disabled material.");
    oImage:delete();
    oLinear.setEnabled(true);
    oLinear.setValue(0);
    oImage = pixels(oLinear, 208, 40);
    check(colour(oImage, 20, 20, {120, 40, 170}), "Empty skinned linear meter shows track.");
    oImage:delete();
    oLinear.setValue(100);
    oImage = pixels(oLinear, 208, 40);
    check(colour(oImage, 190, 20, {30, 210, 80}), "Full skinned linear meter fills track.");
    oImage:delete();

    oImage = pixels(oColour, 100, 100);
    local nMixed = 0;

    for nY = 0, 99 do
        for nX = 0, 99 do
            if (not colour(oImage, nX, nY, {24, 29, 36}) and not colour(oImage, nX, nY, {200, 100, 50})) then
                nMixed = nMixed + 1;
            end
        end
    end

    check(nMixed > 150, "Circular edges contain antialiased coverage pixels.");
    oImage:delete();
    oColour.setValue(12.5);
    oImage = pixels(oColour, 100, 100);
    local nSectorMixed = 0;

    for nY = 10, 40 do
        for nX = 60, 90 do
            local nDistance = math.sqrt((nX - 50)^2 + (nY - 50)^2);

            if (nDistance > 39 and nDistance < 44
                and not colour(oImage, nX, nY, {43, 50, 59})
                and not colour(oImage, nX, nY, {200, 100, 50})) then
                nSectorMixed = nSectorMixed + 1;
            end
        end
    end

    check(nSectorMixed > 2, "Moving sector edge is antialiased inside ring.");
    oImage:delete();

    for _, oComponent in ipairs({oCircle, oLinear}) do
        local nEvents = 0;
        local nValue = oComponent.getValue();
        oComponent.on("appearanceChanged", function(oSource, tEvent)
            check(oSource == oComponent and tEvent.Appearance == "colour" and tEvent.OldAppearance == "skin", "Appearance event payload.");
            nEvents = nEvents + 1;
        end);
        check(oComponent.setAppearance("colour", true) == oComponent, "Appearance setter chains.");
        oComponent.setAppearance("colour", true);
        check(nEvents == 1 and oComponent.getValue() == nValue, "Changed-only appearance preserves progress.");
        check(not pcall(oComponent.setAppearance, "invalid"), "Invalid appearance rejected.");
        check(oComponent.getAppearance() == "colour", "Invalid mode preserves state.");
        oComponent.setAppearance("skin");
        oImage = pixels(oComponent, 180, 120);
        oImage:delete();
    end

    -- A preview uses the same production drawing calls as native paint.
    local oPreview = _wx.wxBitmap(640, 230);
    local oDC = _wx.wxMemoryDC();
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oDC:SelectObject(oPreview);
    oDC:SetBackground(oBackground);
    oDC:Clear();
    local oDemo = _Controls.circularProgress(oFrame, {Skin = oSkin, Min = 0, Max = 100, Value = 65, Text = "%v%"});
    oDC:SetDeviceOrigin(20, 20);
    oDemo.draw(oDC, 160, 160);
    oDemo.setAppearance("colour");
    oDC:SetDeviceOrigin(220, 20);
    oDemo.draw(oDC, 160, 160);
    local oBar = _Controls.progress(oFrame, {Skin = oSkin, Min = 0, Max = 100, Value = 65, Text = "%v%", Appearance = "skin"});
    oDC:SetDeviceOrigin(410, 40);
    oBar.draw(oDC, 200, 40);
    oBar.setAppearance("colour");
    oDC:SetDeviceOrigin(410, 110);
    oBar.draw(oDC, 200, 40);
    oDC:SetDeviceOrigin(0, 0);
    oDC:SelectObject(_wx.wxNullBitmap);
    oImage = oPreview:ConvertToImage();
    check(oImage:SaveFile(APP_PATH.."/Tests/ProgressSkinPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save render preview.");
    oImage:delete();
    oDC:delete();
    oPreview:delete();
    oBackground:delete();

    for _, oComponent in ipairs({oCircle, oLinear, oColour, oDemo, oBar}) do
        oComponent.destroy();
        oComponent.destroy();
    end

    oExternal.destroy();
    oExternal.destroy();
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(3);
    tWorkbench.Layout();
    _wx.wxYield();
    check(tWorkbench.Widgets.CircularProgress.getAppearance() == "skin", "Workbench circle starts skinned.");
    click(tWorkbench.Widgets.CircularProgressSkin);
    check(tWorkbench.Widgets.CircularProgress.getAppearance() == "colour", "Workbench circle skin toggle.");
    click(tWorkbench.Widgets.ProgressSkin);

    for _, sKey in ipairs({"Health", "Mana", "Progress"}) do
        check(tWorkbench.Widgets[sKey].getAppearance() == "skin", "Workbench linear skin toggle.");
    end

    tWorkbench.Frame:Close();
    _wx.wxYield();
    print("Antialiased edge pixels: "..nMixed.."; sector boundary: "..nSectorMixed);
end

local bPassed, sError = xpcall(run, debug.traceback);

for _, pFile in ipairs(_tFixtures) do
    os.remove(pFile);
end

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Progress skin regression passed: ".._nChecks.." checks.");