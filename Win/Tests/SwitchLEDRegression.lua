--[[!
@fqxn wxLuma.Tests.SwitchLEDRegression
@desc Verifies automatic switch skins, boolean input, light rendering, event
    observers and serializer-independent state using the packaged native runtime.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Luma = require("wxLuma")();
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.SwitchLEDRegression.check
@desc Counts behavior assertions and names any failure.
!]]
local function check(bValue, sMessage)
    assert(bValue, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.SwitchLEDRegression.mouse
@desc Sends native pointer events through the real input and observer bindings.
!]]
local function mouse(oControl, nType)
    local oEvent = _wx.wxMouseEvent(nType);
    oEvent.GetX = function() return 20; end;
    oEvent.GetY = function() return 20; end;
    oEvent:SetId(oControl:GetId()); oEvent:SetEventObject(oControl);
    oControl:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.SwitchLEDRegression.run
@desc Checks all switch families/states, rendered light changes, cache reuse,
    validation, changed-only notifications and restoration without constructors.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local oSkin = _Luma.Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Switch and LED regression",
        _wx.wxDefaultPosition, _wx.wxSize(400, 300));
    oFrame:Show(true);
    local nChanges = 0;
    local oSwitch = _Luma.Controls.switch(oFrame, {Skin = oSkin,
        OnChange = function() nChanges = nChanges + 1; end});
    oSwitch.layout(10, 10, 140, 140);
    local oLED = _Luma.Controls.led(oFrame, {Skin = oSkin, Value = true, Size = 64,
        Color = {R = 240, G = 100, B = 40}});
    oLED.layout(160, 10, 120, 120);
    check(oSwitch.Text == "", "Switch text defaults to empty.");
    check(oLED.getGlow() and not oLED.getGlass() and oLED.getBrightness() == 1, "LED defaults enable glow and omit glass.");
    local nSettings, nValues = 0, 0;
    oLED.on("settingChanged", function() nSettings = nSettings + 1; end);
    oLED.on("valueChanged", function() nValues = nValues + 1; end);
    oLED.setBrightness(0.5, true); oLED.setBrightness(0.5, true); oLED.setBrightness(1);
    check(nSettings == 1 and nValues == 0, "LED settings notify only actual requested changes.");
    check(not oSwitch.getValue() and oSwitch.getOrientation() == "horizontal" and not oSwitch.getReversed(), "Switch defaults are standard horizontal off.");
    oSwitch.handleKey("down", _wx.WXK_SPACE); oSwitch.handleKey("down", _wx.WXK_SPACE);
    check(not oSwitch.getValue(), "Repeated key downs do not activate before release.");
    oSwitch.handleKey("up", _wx.WXK_SPACE);
    check(oSwitch.getValue() and nChanges == 1, "Space release toggles once.");
    oSwitch.setValue(true, true); check(nChanges == 1, "Identical boolean writes are silent.");
    oSwitch.handlePointer("down", 20, 20); oSwitch.setOrientation("vertical");
    oSwitch.handlePointer("up", 20, 20);
    check(oSwitch.getValue() and not oSwitch.Control:HasCapture(), "Orientation changes cancel pending activation and preserve Value.");
    oSwitch.handleKey("down", _wx.WXK_DOWN); check(not oSwitch.getValue(), "Standard vertical down selects off.");
    oSwitch.setReversed(true); oSwitch.handleKey("down", _wx.WXK_DOWN);
    check(oSwitch.getValue(), "Reversed vertical down selects on.");
    oSwitch.setOrientation("horizontal"); oSwitch.handleKey("down", _wx.WXK_RIGHT);
    check(not oSwitch.getValue(), "Reversed horizontal right selects off.");
    local tSwitchState = oSwitch.getObjectState();
    oSwitch.setOrientation("vertical"); oSwitch.setReversed(false); oSwitch.setValue(true);
    oSwitch.setObjectState(tSwitchState);
    check(oSwitch.getOrientation() == "horizontal" and oSwitch.getReversed() and not oSwitch.getValue(), "Switch state includes direction, orientation and boolean.");
    check(not pcall(oSwitch.setValue, 1) and not pcall(oSwitch.setOrientation, "diagonal")
        and not pcall(oSwitch.setReversed, 1), "Switch rejects invalid settings.");

    local nClicks = 0;
    for _, oWidget in ipairs({oSwitch, oLED}) do
        oWidget.on("rightDown", function() nClicks = nClicks + 1; end);
        mouse(oWidget.Control, _wx.wxEVT_RIGHT_DOWN);
    end
    check(nClicks == 2, "Both controls expose native right-click audio events.");
    local bOld = oSwitch.getValue();
    mouse(oSwitch.Control, _wx.wxEVT_LEFT_DOWN); mouse(oSwitch.Control, _wx.wxEVT_LEFT_UP);
    check(oSwitch.getValue() ~= bOld, "Native click toggles the switch.");
    mouse(oLED.Control, _wx.wxEVT_LEFT_DOWN); mouse(oLED.Control, _wx.wxEVT_LEFT_UP);
    check(oLED.getValue(), "LED pointer interaction never mutates its indicator value.");
    oSwitch.setEnabled(false); bOld = oSwitch.getValue();
    oSwitch.handleKey("down", _wx.WXK_RETURN); oSwitch.handleKey("up", _wx.WXK_RETURN);
    check(oSwitch.getValue() == bOld, "Disabled switches reject input."); oSwitch.setEnabled(true);

    local oBitmap = _wx.wxBitmap(140, 140);
    local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    local fSkinDraw = oSkin.draw;
    local sDrawn;
    oSkin.draw = function(oTarget, sName, ...)
        sDrawn = sName;
        return fSkinDraw(oTarget, sName, ...);
    end;
    for _, sOrientation in ipairs({"horizontal", "vertical"}) do
        for _, bReversed in ipairs({false, true}) do
            for _, bValue in ipairs({false, true}) do
                oSwitch.setOrientation(sOrientation); oSwitch.setReversed(bReversed); oSwitch.setValue(bValue);
                for _, sState in ipairs({"Normal", "Hover", "Pressed", "Disabled"}) do
                    oSwitch.setEnabled(sState ~= "Disabled");
                    oSwitch.Hover, oSwitch.Pressed = sState == "Hover", sState == "Pressed";
                    if (sState == "Pressed") then oSwitch.Hover = true; end
                    oSwitch.draw(oDC, 140, 140);
                    local sExpected = "Switch "..(sOrientation == "vertical" and "Vertical" or "Horizontal")
                        ..(bReversed and " Reversed" or " Standard")..(bValue and " On " or " Off ")..sState;
                    check(sDrawn == sExpected, "Automatic skin selection: "..sExpected);
                end
            end
        end
    end
    oSkin.draw = fSkinDraw;
    local fDrawText = oDC.DrawText;
    local nCaptions, sCaption = 0;
    oDC.DrawText = function(oTarget, sText, ...)
        nCaptions, sCaption = nCaptions + 1, sText;
        return fDrawText(oTarget, sText, ...);
    end;
    oSwitch.draw(oDC, 140, 140);
    check(nCaptions == 0, "Empty switch text draws no caption.");
    oSwitch.Text = "Power";
    for _, sOrientation in ipairs({"horizontal", "vertical"}) do
        oSwitch.setOrientation(sOrientation); oSwitch.draw(oDC, 140, 140);
    end
    check(nCaptions == 2 and sCaption == "Power", "Optional switch text is rendered in both orientations.");
    local tCaptionState = oSwitch.getObjectState(); oSwitch.Text = "Changed"; oSwitch.setObjectState(tCaptionState);
    check(oSwitch.Text == "Power", "Switch captions round-trip through existing text state.");
    oDC.DrawText = fDrawText;
    local tParts = {};
    oSkin.draw = function(oTarget, sName, ...)
        tParts[sName] = true;
        return fSkinDraw(oTarget, sName, ...);
    end;
    oSwitch.setEnabled(true); oSwitch.Control:SetFocus();
    oSwitch.draw(oDC, 140, 140);
    check(tParts["Switch Surface Normal"] and tParts["Switch Focus"], "Switch background and focus use named skin artwork.");
    for _, bEnabled in ipairs({true, false}) do
        oSwitch.setEnabled(bEnabled); oSwitch.draw(oDC, 140, 140);
        local oTextColor = oDC:GetTextForeground();
        local oMaterial = oSkin.getBitmap(bEnabled and "Switch Text Normal" or "Switch Text Disabled"):ConvertToImage();
        check(oTextColor:Red() == oMaterial:GetRed(0, 0) and oTextColor:Green() == oMaterial:GetGreen(0, 0)
            and oTextColor:Blue() == oMaterial:GetBlue(0, 0), "Switch caption colors follow the skin palette.");
        oMaterial:delete();
    end
    oSkin.draw = fSkinDraw;

    -- Render into a bitmap and compare actual channels, including a pixel in
    -- the halo outside the bezel. This tests the packaged SetRGB/SetAlpha path.
    --[[!
    @fqxn wxLuma.Tests.SwitchLEDRegression.run.pixel
    @desc Reads an actual rendered pixel while retaining ownership of the bitmap.
    !]]
    local function fPixel(nX, nY)
        oLED.draw(oDC, 140, 140);
        local oImage = oBitmap:ConvertToImage();
        local nR, nG, nB = oImage:GetRed(nX, nY), oImage:GetGreen(nX, nY), oImage:GetBlue(nX, nY);
        oImage:delete(); return nR, nG, nB;
    end
    local nFull, nGreen, nBlue = fPixel(70, 70);
    check(nFull > nGreen and nGreen > nBlue, "LED lens is tinted with the configured color.");
    local nAgain = fPixel(70, 70); check(nAgain == nFull, "Repeated cached paints are identical.");
    oLED.setBrightness(0.25); local nDim = fPixel(70, 70);
    check(nDim < nFull and nDim > 0, "Brightness reduces rendered light.");
    oLED.setBrightness(1); oLED.setEnabled(false); local nDisabled = fPixel(70, 70);
    check(nDisabled < nFull, "Disabled rendering dims the light."); oLED.setEnabled(true);
    oLED.setValue(false); local nOff = fPixel(70, 70);
    check(nOff < nDim, "Off state retains only a dim colored lens."); oLED.setValue(true);
    oLED.setGlow(true); local nHalo = fPixel(70, 29);
    oLED.setGlow(false); local nNoHalo = fPixel(70, 29);
    check(nHalo ~= nNoHalo, "Optional glow changes pixels outside the bezel.");
    check(oLED.getGlowRadius() == nil, "Glow radius defaults to automatic proportional sizing.");
    oLED.setGlow(true); oLED.setGlowRadius(20);
    local nSmallHalo = fPixel(70, 29);
    oLED.setGlowRadius(60); local nLargeHalo = fPixel(70, 29);
    check(nSmallHalo == nNoHalo and nLargeHalo ~= nNoHalo, "Larger radius extends the halo into previously unlit pixels.");
    check(oLED.RenderedSize == 64 and oLED.getSize() == 64, "Glow radius changes do not shrink the lens.");
    oLED.setGlowRadius(0); local nZeroHalo = fPixel(70, 29);
    check(nZeroHalo == nNoHalo and oLED.getGlow(), "Zero radius suppresses the halo without changing Glow.");
    oLED.setGlowRadius(70); local nFittedHalo = fPixel(70, 29);
    oLED.setGlowRadius(512); local nClippedHalo = fPixel(70, 29);
    check(nFittedHalo == nClippedHalo and oLED.RenderedSize == 64, "Oversized glow fits bounds while preserving the lens.");
    local nBeforeRadius = nSettings;
    oLED.setGlowRadius(28.5, true); oLED.setGlowRadius(28.5, true);
    check(nSettings == nBeforeRadius + 1 and oLED.getGlowRadius() == 28.5, "Fractional radius changes notify once.");
    check(not pcall(oLED.setGlowRadius, -1) and not pcall(oLED.setGlowRadius, math.huge)
        and not pcall(oLED.setGlowRadius, 0 / 0) and not pcall(oLED.setGlowRadius, 513)
        and oLED.getGlowRadius() == 28.5, "Invalid radius changes preserve the accepted radius.");
    local tRadiusState = oLED.getObjectState(); oLED.setGlowRadius(nil); oLED.setObjectState(tRadiusState);
    check(oLED.getGlowRadius() == 28.5, "Explicit radius round-trips through object state.");
    oLED.setGlowRadius(nil);
    local tAutomaticState = oLED.getObjectState(); oLED.setGlowRadius(30); oLED.setObjectState(tAutomaticState);
    check(oLED.getGlowRadius() == nil, "Automatic radius survives a state round trip.");
    oLED.setGlow(false);
    oLED.setGlass(false); local nBare = fPixel(70, 55);
    oLED.setGlass(true); local nGlass = fPixel(70, 55);
    check(nGlass ~= nBare, "Optional glass adds its own highlight layer.");
    local tColor = oLED.getColor(); tColor.R = 0;
    check(oLED.getColor().R == 240, "Color getters return independent data.");
    check(not pcall(oLED.setBrightness, 2) and not pcall(oLED.setSize, 0)
        and not pcall(oLED.setColor, {R = -1, G = 0, B = 0}) and oLED.getBrightness() == 1,
        "Invalid LED settings preserve the accepted configuration.");
    local tLEDState = oLED.getObjectState();
    oLED.setColor({R = 0, G = 0, B = 255}); oLED.setSize(12); oLED.setBrightness(0);
    oLED.setGlass(false); oLED.setGlow(true); oLED.setValue(false); oLED.setObjectState(tLEDState);
    check(oLED.getColor().R == 240 and oLED.getSize() == 64 and oLED.getBrightness() == 1
        and oLED.getGlass() and not oLED.getGlow() and oLED.getValue(), "LED visual settings and Value round-trip through state.");
    oLED.setSize(24); fPixel(70, 70); check(oLED.RenderedSize == 24, "Size changes rebuild the rendered light.");
    -- Brightness/size drags reuse decoded source artwork; tinting must not
    -- fetch/convert each skin image again on every slider update.
    oLED.setSize(64); oLED.setGlow(true); fPixel(70, 70);
    local fGetBitmap = oSkin.getBitmap;
    local nLightFetches = 0;
    oSkin.getBitmap = function(sName, ...)
        if (sName == "LED Lens" or sName == "LED Glow") then nLightFetches = nLightFetches + 1; end
        return fGetBitmap(sName, ...);
    end;
    local nStart = os.clock();
    for nIndex = 1, 100 do oLED.setBrightness(nIndex / 100); oLED.draw(oDC, 140, 140); end
    local nBrightnessMs = (os.clock() - nStart) * 10;
    check(nLightFetches == 0, "Brightness sweeps reuse decoded source and filtered masks.");
    nStart = os.clock();
    for nIndex = 1, 100 do oLED.setSize(12 + nIndex % 85); oLED.draw(oDC, 140, 140); end
    local nSizeMs = (os.clock() - nStart) * 10;
    check(nLightFetches == 0, "Size sweeps reuse decoded high-resolution artwork.");
    nStart = os.clock();
    for nIndex = 1, 100 do oLED.setGlowRadius(nIndex % 70); oLED.draw(oDC, 140, 140); end
    local nRadiusMs = (os.clock() - nStart) * 10;
    check(nLightFetches == 0, "Glow radius sweeps reuse decoded artwork.");
    oSkin.getBitmap = fGetBitmap;
    print(string.format("LED update + paint: brightness %.2f ms; size %.2f ms; radius %.2f ms (100 updates each).",
        nBrightnessMs, nSizeMs, nRadiusMs));
    for _, sPart in ipairs({"Lens", "Bezel", "Glass"}) do
        local oSource = oSkin.getBitmap("LED "..sPart):ConvertToImage();
        check(oSource:GetWidth() == 384 and oSource:GetHeight() == 384, "High-resolution LED "..sPart.." skin.");
        local oFiltered = oSource:Scale(37, 37, _wx.wxIMAGE_QUALITY_HIGH);
        local sAlpha = oFiltered:GetAlpha();
        local nPartial = 0;
        for nIndex = 1, #sAlpha do
            local nAlpha = sAlpha:byte(nIndex);
            if (nAlpha > 0 and nAlpha < 255) then nPartial = nPartial + 1; end
        end
        check(nPartial > 20, "Filtered LED "..sPart.." retains antialiased coverage.");
        oFiltered:delete(); oSource:delete();
    end
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
    oSwitch.destroy(); oSwitch.destroy(); oLED.destroy(); oLED.destroy();
    check(not pcall(oLED.setValue, true) and not pcall(oSwitch.setOrientation, "vertical"), "Disposed controls reject mutation.");
    oFrame:Destroy(); _wx.wxGetApp():Yield(); oSkin.destroy();
end

run();
print("Switch and LED regression: ".._nChecks.." checks passed.");
