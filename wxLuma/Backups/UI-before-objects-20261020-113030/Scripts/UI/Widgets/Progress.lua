local wx = require("wx");
local Progress = {};
local surface = require("UI.Core.ControlSurface").create;
local finite = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn OpenWar.UI.Progress.create
@param table tOptions Skin, Min, Max, Value; optional Text, Colour ({R,G,B}), Enabled, OnChange.
@desc Determinate progress/resource meter. Value clamps to explicit range. Text
      supports %v/current and %m/max. No input or automatic timing.
!]]
function Progress.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Progress");
    assert(finite(tOptions.Min) and finite(tOptions.Max) and tOptions.Max > tOptions.Min, "Invalid progress range.");
    c.Min, c.Max = tOptions.Min, tOptions.Max; c.Text = tOptions.Text or "%v / %m"; c.Colour = tOptions.Colour or {R = 88, G = 120, B = 148};
    function c.setValue(nValue, bNotify)
        assert(finite(nValue), "Progress value must be finite.");
        nValue = math.max(c.Min, math.min(c.Max, nValue)); local bChanged = c.Value ~= nValue; c.Value = nValue;
        if (bChanged) then c.refresh(); if (bNotify and c.OnChange) then c.OnChange(nValue, c); end end; return c;
    end
    c.drawContent = function(oDC, nW, nH)
        local nFill = math.floor((nW - 8) * (c.Value - c.Min) / (c.Max - c.Min));
        if (nFill > 0) then
            local tColour = c.isEnabled() and c.Colour or {R = 61, G = 67, B = 73};
            oDC:GradientFillLinear(wx.wxRect(4, 4, nFill, math.max(1, nH - 8)), wx.wxColour(tColour.R, tColour.G, tColour.B),
                wx.wxColour(math.floor(tColour.R / 3), math.floor(tColour.G / 3), math.floor(tColour.B / 3)), wx.wxSOUTH);
        end
        local sText = c.Text:gsub("%%v", tostring(c.Value)):gsub("%%m", tostring(c.Max));
        oDC:SetFont(c.Skin.Font); local nTextW, nTextH = oDC:GetTextExtent(sText);
        oDC:SetClippingRegion(4, 4, math.max(1, nW - 8), math.max(1, nH - 8));
        c.Skin.text(oDC, sText, (nW - nTextW) / 2, (nH - nTextH) / 2, c.isEnabled()); oDC:DestroyClippingRegion();
    end;
    c.setValue(tOptions.Value); return c;
end

return Progress;
