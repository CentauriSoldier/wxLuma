local _wx           = require("wx");
local Progress      = {};
local createSurface = require("UI.Core.ControlSurface").create;
local finite        = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn wxLuma.UI.Progress.create
@param table tOptions Skin, Min, Max, Value; optional Text, Colour ({R,G,B}), Enabled, OnChange.
@desc Determinate progress/resource meter. Value clamps to explicit range. Text
      supports %v/current and %m/max. No input or automatic timing.
!]]
function Progress.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Progress");
    assert(finite(tOptions.Min) and finite(tOptions.Max) and tOptions.Max > tOptions.Min,
        "Invalid progress range.");
    oComponent.Min, oComponent.Max = tOptions.Min, tOptions.Max;
    oComponent.Text                = tOptions.Text or "%v / %m";
    oComponent.Colour              = tOptions.Colour or {
        R = 88,
        G = 120,
        B = 148
    };

    --[[!
    @fqxn wxLuma.UI.Progress.setValue
    @desc Validates and updates the component value, refreshes its appearance and optionally notifies
        when the value changes.
    @param number nValue The requested value or index.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(finite(nValue), "Progress value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, nValue));
        local bChanged = oComponent.Value ~= nValue;
        oComponent.Value = nValue;
        if (bChanged) then
            oComponent.refresh();
            if (bNotify and oComponent.OnChange) then
                oComponent.OnChange(nValue, oComponent);
            end
        end;
        return oComponent;
    end

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        local nFill = math.floor((nWidth - 8) * (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min));
        if (nFill > 0) then
            local tColour = oComponent.isEnabled() and oComponent.Colour or {
                R = 61,
                G = 67,
                B = 73
            };
            oDC:GradientFillLinear(_wx.wxRect(4, 4, nFill, math.max(1, nHeight - 8)),
                _wx.wxColour(tColour.R, tColour.G, tColour.B),
                _wx.wxColour(math.floor(tColour.R / 3), math.floor(tColour.G / 3),
                    math.floor(tColour.B / 3)), _wx.wxSOUTH);
        end
        local sText = oComponent.Text:gsub("%%v", tostring(oComponent.Value)):gsub("%%m",
            tostring(oComponent.Max));
        oDC:SetFont(oComponent.Skin.Font);
        local nTextW, nTextH = oDC:GetTextExtent(sText);
        oDC:SetClippingRegion(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
        oComponent.Skin.text(oDC, sText, (nWidth - nTextW) / 2, (nHeight - nTextH) / 2, oComponent.isEnabled());
        oDC:DestroyClippingRegion();
    end;
    oComponent.setValue(tOptions.Value);
    return oComponent;
end

return Progress;
