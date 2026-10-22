--[[!
@fqxn wxLuma.Tests.OrbRenderingRegression
@desc Checks bounded work-buffer reuse, material reuse and pixel parity after
    value, appearance, enabled, size, reserve and supersampling changes.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Controls = require("wxLuma")().Controls;
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.OrbRenderingRegression.check
@desc Counts assertions and identifies the failed rendering contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.OrbRenderingRegression.run
@desc Compares reused renderers with fresh instances and counts native work
    bitmap allocations after warmup. Timing is reported without fragile limits.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Orb rendering regression");
    local oSkin = _Controls.loadSkin();
    local oBitmap = _wx.wxBitmap(220, 220);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);

    --[[!
    @fqxn wxLuma.Tests.OrbRenderingRegression.run.pixels
    @desc Captures RGB bytes after a draw, leaving the shared destination alive.
    !]]
    local function fPixels(oMeter, nDiameter)
        oMeter.draw(oDC, nDiameter, nDiameter);
        local oImage = oBitmap:ConvertToImage();
        local sData = oImage:GetData();
        oImage:delete();
        return sData;
    end

    for _, sFactory in ipairs({"globeProgress", "radialProgress", "irisProgress"}) do
        local oMeter = _Controls[sFactory](oFrame, {Skin = oSkin, Min = 0, Max = 100,
            Value = 0, Text = "", Supersampling = 2});

        for _, nReserve in ipairs({0, 25}) do
            oMeter.setReserved(nReserve);
            oMeter.setValue(30);
            oMeter.draw(oDC, 220, 220);
            local fBitmap = _wx.wxBitmap;
            local fBrush = _wx.wxBrush;
            local fMask = _wx.wxMask;
            local nWorkAllocations = 0;
            local nBrushAllocations = 0;
            local nMaskAllocations = 0;
            _wx.wxBitmap = function(vWidth, ...)
                if (type(vWidth) == "number" and vWidth >= 440) then
                    nWorkAllocations = nWorkAllocations + 1;
                end

                return fBitmap(vWidth, ...);
            end;
            _wx.wxBrush = function(...)
                nBrushAllocations = nBrushAllocations + 1;
                return fBrush(...);
            end;
            _wx.wxMask = function(...)
                nMaskAllocations = nMaskAllocations + 1;
                return fMask(...);
            end;
            local oWatch = _wx.wxStopWatch();
            local bOK, sError = pcall(function()
                for nValue = 1, 60 do
                    oMeter.setValue(nValue);
                    oMeter.draw(oDC, 220, 220);
                end
            end);
            local nElapsed = oWatch:Time();
            _wx.wxBitmap = fBitmap;
            _wx.wxBrush = fBrush;
            _wx.wxMask = fMask;
            assert(bOK, sError);
            check(nWorkAllocations == 0, sFactory.." reuses supersampled work bitmaps while dragging.");
            check(nBrushAllocations == 0, sFactory.." reuses material brushes while dragging.");

            if (sFactory ~= "irisProgress") then
                check(nMaskAllocations == 0, sFactory.." reuses native clipping masks while dragging.");
            end
            print(sFactory.." reserve "..nReserve..": "..string.format("%.2f", nElapsed / 60).." ms/draw");
        end

        for _, tCase in ipairs({
            {220, 2, "skin", true, 0, 1}, {110, 4, "colour", false, 25, 50},
            {180, 2, "skin", true, 100, 100}, {220, 4, "colour", true, 25, 75},
            {220, 2, "skin", false, 0, 0}, {220, 2, "skin", true, 25, 35}
        }) do
            local nSize, nScale, sAppearance, bEnabled, nReserve, nValue = table.unpack(tCase);
            oMeter.setSupersampling(nScale);
            oMeter.setAppearance(sAppearance);
            oMeter.setEnabled(bEnabled);
            oMeter.setReserved(nReserve);
            oMeter.setValue(nValue);
            local oFresh = _Controls[sFactory](oFrame, {Skin = oSkin, Min = 0, Max = 100,
                Value = nValue, Text = "", Supersampling = nScale, Appearance = sAppearance,
                Enabled = bEnabled, Reserved = nReserve});
            check(fPixels(oMeter, nSize) == fPixels(oFresh, nSize),
                sFactory.." reused resources match a fresh renderer after visual changes.");
            oFresh.destroy();
        end

        oMeter.destroy();
        oMeter.destroy();
    end

    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    oBitmap:delete();
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxGetApp():Yield();
end

run();
print("Orb rendering regression: ".._nChecks.." checks passed.");
