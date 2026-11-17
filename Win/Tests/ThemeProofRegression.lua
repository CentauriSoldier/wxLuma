local _wx = require("wx");
local _Theme = require("wxLuma.Core.ControlTheme");
local _Skin = require("wxLuma.Core.ControlSkin");
local _load = require("wxLuma");
local ThemeProofRegression = {};

--[[!
@fqxn wxLuma.Tests.ThemeProofRegression.run
@desc Verifies provider changes on production controls: no System artwork loads,
    native palette/font adoption, unchanged editing/input/state, raster invalidation,
    independent contexts and disposal. Uses memory bitmaps without image fixtures.
@ret number nChecks Number of successful assertions.
!]]
function ThemeProofRegression.run()
    local nChecks, nLoads, nClicks, nChanges = 0, 0, 0, 0;
    local fLoad = _Skin.load;
    _Skin.load = function(...)
        nLoads = nLoads + 1;
        return fLoad(...);
    end;
    --[[!
    @fqxn wxLuma.Tests.ThemeProofRegression.check
    @desc Counts assertions and identifies the violated appearance contract.
    !]]
    local function fCheck(bPassed, sMessage)
        assert(bPassed, sMessage); nChecks = nChecks + 1;
    end
    --[[!
    @fqxn wxLuma.Tests.ThemeProofRegression.pixels
    @desc Exercises production drawing in a memory DC and returns RGB bytes.
    !]]
    local function fPixels(oControl, nWidth, nHeight)
        local oBitmap = _wx.wxBitmap(nWidth, nHeight);
        local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        oControl.draw(oDC, nWidth, nHeight);
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete();
        local oImage = oBitmap:ConvertToImage(); local sPixels = oImage:GetData();
        oImage:delete(); oBitmap:delete(); return sPixels;
    end
    local oFrame, oTheme, oOther;
    local tOwned = {};
    local bOK, sError = xpcall(function()
        local tLuma = _load(); oTheme = tLuma.Theme;
        oTheme.setName("System");
        oOther = _Theme.create("System");
        oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Theme proof regression");
        local tOptions = {Text = "Action", OnClick = function() nClicks = nClicks + 1; end};
        local oButton = tLuma.Controls.button(oFrame, tOptions);
        local oEditor = tLuma.Controls.textfield(oFrame, {Value = "Retained selection", OnChange = function() nChanges = nChanges + 1; end});
        local oIris = tLuma.Controls.irisProgress(oFrame, {Min = 0, Max = 100, Value = 55, Reserved = 10, Rotation = 28});
        local oIndependent = tLuma.Controls.button(oFrame, {Theme = oOther, Text = "Independent"});
        tOwned = {oButton, oEditor, oIris, oIndependent};
        oButton.layout(0, 0, 200, 40); oEditor.layout(0, 50, 260, 40); oIris.layout(0, 100, 140, 140);
        oEditor.TextControl:SetSelection(2, 9);
        local oNativeEditor, oNativeIris = oEditor.TextControl, oIris.Control;
        local sButton = fPixels(oButton, 200, 40);
        local sIris = fPixels(oIris, 140, 140);
        fCheck(nLoads == 0, "System construction/rendering must not load image skins.");
        fCheck(tOptions.Skin == nil and tOptions.Theme == nil, "Constructor options remain caller-owned.");
        fCheck(oButton.Theme == oTheme and oEditor.Theme == oTheme and oIris.Theme == oTheme, "Factories share the configured context.");
        local oColor = _wx.wxSystemSettings.GetColour(_wx.wxSYS_COLOUR_WINDOW);
        fCheck(oEditor.TextControl:GetBackgroundColour():GetAsString() == oColor:GetAsString(), "Native editor uses the system editor color."); oColor:delete();
        local oFont = _wx.wxSystemSettings.GetFont(_wx.wxSYS_DEFAULT_GUI_FONT);
        fCheck(oEditor.TextControl:GetFont():GetFaceName() == oFont:GetFaceName()
            and oEditor.TextControl:GetFont():GetPointSize() == oFont:GetPointSize(), "Native editor uses the system GUI font."); oFont:delete();
        fCheck(not pcall(oTheme.destroy), "A context cannot be destroyed before its controls.");
        for nPass = 1, 4 do
            oTheme.setName("Obsidian");
            fCheck(fPixels(oButton, 200, 40) ~= sButton, "Button rendering changes provider.");
            fCheck(fPixels(oIris, 140, 140) ~= sIris, "Iris raster invalidates on provider change.");
            fCheck(oOther.getName() == "System", "Separate contexts remain independent.");
            oTheme.setName("System");
            fCheck(fPixels(oIris, 140, 140) == sIris, "Returning to System rebuilds the original iris pixels.");
            local nStart, nEnd = oEditor.TextControl:GetSelection();
            fCheck(oEditor.getValue() == "Retained selection" and nStart == 2 and nEnd == 9, "Switch preserves editor text/selection.");
            fCheck(oEditor.TextControl == oNativeEditor and oIris.Control == oNativeIris, "Switch preserves native identities.");
            fCheck(oIris.getValue() == 55 and oIris.getReserved() == 10 and oIris.getRotation() == 28, "Switch preserves iris state.");
        end
        fCheck(nChanges == 0, "Appearance changes emit no value callbacks.");
        oButton.handleKey("down", _wx.WXK_RETURN); oButton.handleKey("up", _wx.WXK_RETURN);
        fCheck(nClicks == 1, "Button retains exact-once keyboard activation.");
        oButton.setEnabled(false); oButton.handleKey("down", _wx.WXK_RETURN); oButton.handleKey("up", _wx.WXK_RETURN);
        fCheck(nClicks == 1, "Disabled button cannot activate.");
        fCheck(fPixels(oButton, 200, 40) ~= sButton, "Disabled button paints a distinct state.");
        oEditor.setEnabled(false); oTheme.setName("Obsidian"); oTheme.setName("System");
        fPixels(oEditor, 260, 40); oEditor.setEnabled(true);
        fCheck(oEditor.getValue() == "Retained selection" and oEditor.TextControl:IsShown(), "Disabled editor survives switching and re-enabling.");
        oIris.setEnabled(false); fCheck(fPixels(oIris, 140, 140) ~= sIris, "Disabled iris paints a distinct state.");
        oIris.setEnabled(true); oIris.setValue(20); fCheck(fPixels(oIris, 140, 140) ~= sIris, "System iris retains progress geometry.");
        oIris.setValue(55); oTheme.setName("System"); fCheck(fPixels(oIris, 140, 140) == sIris, "System refresh invalidates caches without changing state.");
        fCheck(not pcall(oTheme.setName, "Unknown"), "Unknown provider names are rejected.");
    end, debug.traceback);
    for _, oControl in ipairs(tOwned) do oControl.destroy(); oControl.destroy(); end
    -- A failed constructor can leave a native child outside tOwned. Release
    -- its parent first so cleanup cannot hide the original assertion failure.
    if (oFrame) then oFrame:Destroy(); _wx.wxYield(); end
    _Skin.load = fLoad;
    assert(bOK, sError);
    if (oTheme) then oTheme.destroy(); oTheme.destroy(); end
    if (oOther) then oOther.destroy(); end
    print("Theme proof regression: "..nChecks.." checks passed.");
    return nChecks;
end

return ThemeProofRegression;
