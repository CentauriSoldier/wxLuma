local _wx           = require("wx");
local _ControlEvents = require("UI.Core.ControlEvents");
local Progress      = {};
local createSurface = require("UI.Core.ControlSurface").create;
local finite        = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn wxLuma.UI.Progress.create
@param table tOptions Skin, Min, Max, Value; optional Text, Colour ({R,G,B}),
    Appearance (colour/skin, default colour), Artwork (material prefix, default
    Progress), Enabled and OnChange.
@desc Determinate progress/resource meter. Value clamps to explicit range. Text
      supports %v/current and %m/max. No input or automatic timing.
!]]
function Progress.create(oParent, tOptions)
    local sAppearance = tOptions.Appearance or "colour";
    local sArtwork = tOptions.Artwork or "Progress";
    assert(sAppearance == "skin" or sAppearance == "colour", "Appearance must be skin or colour.");
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Artwork must be a material prefix.");
    local oComponent = createSurface(oParent, tOptions, "Progress");
    local tEvents = _ControlEvents.attach(oComponent, nil, {"appearanceChanged"});
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
    @fqxn wxLuma.UI.Progress.getAppearance
    @desc Returns colour for the original gradient meter or skin for bitmap materials.
    @ret string sAppearance Current appearance.
    !]]
    function oComponent.getAppearance()
        return sAppearance;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.setAppearance
    @desc Switches colour and skin rendering at runtime without changing progress.
    @param string sMode colour or skin.
    @param boolean|nil bNotify Emit appearanceChanged on an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setAppearance(sMode, bNotify)
        assert(sMode == "skin" or sMode == "colour", "Appearance must be skin or colour.");

        if (not oComponent.Disposed and sAppearance ~= sMode) then
            local sOld = sAppearance;
            sAppearance = sMode;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("appearanceChanged", {Appearance = sMode, OldAppearance = sOld});
            end
        end

        return oComponent;
    end

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
        local nOldValue = oComponent.Value;
        local bChanged = nOldValue ~= nValue;
        oComponent.Value = nValue;
        if (bChanged) then
            oComponent.refresh();
            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOldValue});
            end
        end;
        return oComponent;
    end

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        local nFill = math.floor((nWidth - 8) * (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min));
        if (sAppearance == "skin") then
            local nInnerWidth = math.max(1, nWidth - 8);
            local nInnerHeight = math.max(1, nHeight - 8);
            local sState = oComponent.isEnabled() and "Normal" or "Disabled";
            oComponent.Skin.draw(oDC, sArtwork.." Track "..sState, 4, 4, nInnerWidth, nInnerHeight);

            if (nFill > 0) then
                -- Clip the full-width material instead of stretching its texture
                -- as progress changes. This keeps the artwork fixed in place.
                local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(4, 4, nFill, nInnerHeight));
                oComponent.Skin.draw(oDC, sArtwork.." Fill "..sState, 4, 4, nInnerWidth, nInnerHeight);
                oClip:delete();
            end
        elseif (nFill > 0) then
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
