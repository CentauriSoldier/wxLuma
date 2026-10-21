--[[!
@fqxn wxLuma.Tests.IrisProgressRegression
@desc Native checks for blade geometry, background clipping, reserves, events,
    image replacement, cache parity, disposal and the workbench demonstration.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _pFramework = require("wxLuma")().Config.ImagePath;
local _Controls = require("wxLuma.Controls");
local _nChecks = 0;
local _pFixture = APP_PATH.."/Tests/IrisImageFixture.png";
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.IrisProgressRegression.check
@desc Counts assertions and reports the failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.IrisProgressRegression.pixels
@desc Renders through the public draw API into an owned image.
!]]
local function pixels(oComponent, nWidth, nHeight)
    nWidth, nHeight = nWidth or 100, nHeight or 100;
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
@fqxn wxLuma.Tests.IrisProgressRegression.isPicture
@desc Identifies the saturated red fixture image away from antialiased boundaries.
!]]
local function isPicture(oImage, nX, nY)
    return oImage:GetRed(nX, nY) == 245 and oImage:GetGreen(nX, nY) == 15 and oImage:GetBlue(nX, nY) == 25;
end

--[[!
@fqxn wxLuma.Tests.IrisProgressRegression.run
@desc Runs geometry and event contracts on real wx surfaces without hardware input.
!]]
local function run()
    local oFixture = _wx.wxImage(160, 80);
    oFixture:SetRGB(_wx.wxRect(0, 0, 160, 80), 245, 15, 25);
    check(oFixture:SaveFile(_pFixture, _wx.wxBITMAP_TYPE_PNG), "fixture saved");
    oFixture:delete();
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Iris regression", _wx.wxDefaultPosition, _wx.wxSize(500, 300));
    local oIris = _Controls.irisProgress(oFrame, {Skin = oSkin, Min = 10, Max = 110, Value = 10,
        BackgroundImage = _pFixture, Text = ""});
    oIris.layout(0, 0, 100, 100);
    check(next(oIris) == nil and oIris.Kind == "IrisProgress", "independent proxy identity");
    check(oIris.getBladeCount() == 6 and oIris.getRotation() == 0 and oIris.getDirection() == "opening", "defaults");
    check(oIris.getBackgroundImageFit() == "cover" and oIris.getBackgroundImage() == _pFixture, "image defaults");
    local nValueEvents, nBladeEvents, nImageEvents = 0, 0, 0;
    oIris.on("valueChanged", function()
        nValueEvents = nValueEvents + 1;
    end);
    oIris.on("bladeCountChanged", function(oSender, tEvent)
        nBladeEvents = nBladeEvents + 1;
        check(oSender == oIris and tEvent.BladeCount == oIris.getBladeCount(), "coherent geometry event");
    end);
    oIris.on("backgroundImageChanged", function()
        nImageEvents = nImageEvents + 1;
    end);

    for _, nCount in ipairs({3, 6, 12, 32}) do
        oIris.setBladeCount(nCount, true);
        oIris.setBladeCount(nCount, true);

        for _, nAngle in ipairs({0, 33, 270}) do
            oIris.setRotation(nAngle);
            oIris.setValue(10);
            local oClosed = pixels(oIris);
            local nVisible = 0;

            for nY = 0, 99 do
                for nX = 0, 99 do
                    nVisible = nVisible + (isPicture(oClosed, nX, nY) and 1 or 0);
                end
            end

            check(nVisible == 0, "closed blades completely cover picture");
            oClosed:delete();
            oIris.setValue(40);
            local oPartial = pixels(oIris);
            check(isPicture(oPartial, 50, 50), "picture visible through opening");
            check(not isPicture(oPartial, 90, 50) and not isPicture(oPartial, 1, 1), "picture clipped by blades and globe");
            local nEscaped = 0;

            for nY = 0, 99 do
                for nX = 0, 99 do
                    if (isPicture(oPartial, nX, nY)) then
                        local nDX, nDY = nX + 0.5 - 50, nY + 0.5 - 50;
                        local nPosition = 0;

                        for nBlade = 0, nCount - 1 do
                            local nNormal = math.rad(nAngle - 90) + nBlade * 2 * math.pi / nCount;
                            nPosition = math.max(nPosition, (nDX * math.cos(nNormal) + nDY * math.sin(nNormal)) / 48);
                        end

                        if (nDX^2 + nDY^2 > 48^2 or nPosition > 0.315) then
                            nEscaped = nEscaped + 1;
                        end
                    end
                end
            end

            check(nEscaped == 0, "all picture pixels stay inside circle and rotated aperture");
            oPartial:delete();
            oIris.setValue(110);
            local oOpen = pixels(oIris);
            check(isPicture(oOpen, 50, 50) and isPicture(oOpen, 90, 50) and not isPicture(oOpen, 1, 1), "full opening preserves outer clip");
            oOpen:delete();
        end
    end

    check(nBladeEvents == 4 and nValueEvents == 0, "no-op geometry and silent value setters");
    oIris.setRotation(-90, true);
    check(oIris.getRotation() == 270, "rotation normalized");

    for _, nBad in ipairs({2, 33, 5.5, math.huge, 0/0}) do
        check(not pcall(oIris.setBladeCount, nBad) and oIris.getBladeCount() == 32, "invalid blades preserve state");
    end

    check(not pcall(oIris.setDirection, "CW") and oIris.getDirection() == "opening", "invalid direction rejected");
    check(not pcall(oIris.setBackgroundImage, APP_PATH.."/does-not-exist.png")
        and oIris.getBackgroundImage() == _pFixture, "failed image load is atomic");
    oIris.setBladeCount(6);
    oIris.setValue(110);

    for _, sFit in ipairs({"cover", "contain", "stretch"}) do
        oIris.setBackgroundImageFit(sFit, true);
        local oImage = pixels(oIris);
        check(isPicture(oImage, 50, 50) and not isPicture(oImage, 1, 1), "all image fit modes clipped");

        if (sFit == "contain") then
            check(not isPicture(oImage, 50, 10), "contain letterboxing retained");
        else
            check(isPicture(oImage, 50, 10), "cover/stretch fills globe");
        end

        oImage:delete();
    end

    oIris.setDirection("closing", true);
    oIris.setValue(10);
    local oClosingMin = pixels(oIris);
    check(isPicture(oClosingMin, 50, 50), "closing starts open");
    oClosingMin:delete();
    oIris.setValue(110);
    local oClosingMax = pixels(oIris);
    check(not isPicture(oClosingMax, 50, 50), "closing ends closed");
    oClosingMax:delete();

    for _, sDirection in ipairs({"opening", "closing"}) do
        oIris.setDirection(sDirection);

        for _, sReserve in ipairs({"inward", "outward"}) do
            oIris.setReserveDirection(sReserve, true);
            oIris.setReserved(25, true);
            oIris.setValue(85);
            check(oIris.isFull() and oIris.getEffectiveMax() == 85, "reserve full threshold");
            local oReserved = pixels(oIris);
            check(not isPicture(oReserved, 1, 1), "reserved iris retains outer clip");
            oReserved:delete();
        end
    end

    oIris.setReserved(100);
    local oReservedAll = pixels(oIris);
    check(not isPicture(oReservedAll, 50, 50) and oIris.isFull(), "entire capacity reserved");
    oReservedAll:delete();
    oIris.setReserved(0);
    oIris.setDirection("opening");
    oIris.setValue(110);
    oIris.setBackgroundImage(nil, true);
    oIris.setBackgroundImage(nil, true);
    check(nImageEvents == 1, "clear image and repeated-clear silence");
    oIris.setBackgroundImage(_pFixture, true);
    check(nImageEvents == 2, "image replacement event");
    oIris.setEnabled(false);
    local oDisabled = pixels(oIris);
    oDisabled:delete();
    oIris.setAppearance("colour", true);
    local oColour = pixels(oIris, 140, 100);
    check(not isPicture(oColour, 1, 50) and isPicture(oColour, 70, 50), "non-square layout centered and clipped");
    oColour:delete();
    local oFirst, oSecond = pixels(oIris), pixels(oIris);
    check(oFirst:GetData() == oSecond:GetData(), "cached raster parity");
    oFirst:delete();
    oSecond:delete();
    oIris.destroy();
    oIris.destroy();
    check(oIris.Disposed, "idempotent destruction");

    local oPreview = _wx.wxBitmap(1000, 270);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oPreview);
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oDC:SetBackground(oBackground);
    oDC:Clear();

    for nIndex, nValue in ipairs({0, 25, 50, 75, 100}) do
        local oSample = _Controls.irisProgress(oFrame, {Skin = oSkin, Min = 0, Max = 100, Value = nValue,
            Text = "", BackgroundImage = _pFramework.."/Menu/Command Shield.png"});
        oDC:SetDeviceOrigin((nIndex - 1) * 200 + 10, 24);
        oSample.draw(oDC, 180, 180);
        oDC:SetDeviceOrigin(0, 0);
        oSkin.text(oDC, "Iris "..nValue.."%", (nIndex - 1) * 200 + 55, 230, true);
        oSample.destroy();
    end

    oDC:SelectObject(_wx.wxNullBitmap);
    local oPreviewImage = oPreview:ConvertToImage();
    check(oPreviewImage:SaveFile(APP_PATH.."/Tests/IrisProgressPreview.png", _wx.wxBITMAP_TYPE_PNG), "production preview saved");
    oPreviewImage:delete();
    oDC:delete();
    oPreview:delete();
    oBackground:delete();
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Widgets.Tabs.setValue(7);
    tWorkbench.Layout();
    _wx.wxYield();
    local oDemo = tWorkbench.Widgets.IrisProgress;
    check(oDemo.Control:IsShownOnScreen(), "iris workbench example visible");
    tWorkbench.Widgets.OrbValue.setValue(42, true);
    tWorkbench.Widgets.OrbReserved.setValue(20, true);
    check(oDemo.getValue() == 42 and oDemo.getReserved() == 20, "shared workbench sliders drive iris");
    local oSlider = tWorkbench.Widgets.OrbValue;
    local nSliderWidth, nSliderHeight = oSlider.Control:GetClientSizeWH();
    local nPrevious = -1;
    oSlider.handlePointer("down", 16, math.floor(nSliderHeight / 2));

    for nStep = 1, 20 do
        local nPointerX = 16 + (nSliderWidth - 32) * nStep / 20;
        oSlider.handlePointer("move", nPointerX, math.floor(nSliderHeight / 2));
        _wx.wxYield();
        local nValue = oSlider.getValue();
        check(nValue >= nPrevious, "ordered drag never moves backwards");

        for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "IrisProgress"}) do
            check(tWorkbench.Widgets[sKey].getValue() == nValue, "live drag synchronizes "..sKey);
        end

        nPrevious = nValue;
    end

    oSlider.handlePointer("up", nSliderWidth - 16, math.floor(nSliderHeight / 2));
    check(oSlider.getValue() == 100 and not oSlider.Control:HasCapture(), "drag reaches endpoint and releases capture");

    for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "IrisProgress"}) do
        local oMeter = tWorkbench.Widgets[sKey];
        check(oMeter.getSupersampling() == 2, "live demo uses lighter antialiasing");
        oMeter.setSupersampling(4, true);
        check(oMeter.getSupersampling() == 4 and oMeter.getValue() == 100, "runtime quality preserves value");
        check(not pcall(oMeter.setSupersampling, 0), "invalid quality rejected");
    end

    local nX, nY = oDemo.Control:GetPositionXY();
    local nWidth, nHeight = oDemo.Control:GetSizeWH();
    local nPageWidth, nPageHeight = oDemo.Control:GetParent():GetClientSizeWH();
    check(nX >= 0 and nY >= 0 and nX + nWidth <= nPageWidth and nY + nHeight <= nPageHeight, "minimum-size iris fits page");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);
os.remove(_pFixture);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Iris progress regression passed: ".._nChecks.." checks.");
