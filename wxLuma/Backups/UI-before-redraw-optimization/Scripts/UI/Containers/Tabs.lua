local _wx           = require("wx");
local Tabs          = {};
local createSurface = require("UI.Core.ControlSurface").create;
local finite        = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn wxLuma.UI.Tabs.create
@param table tOptions Skin, Items (captions); optional Value (1), Enabled, OnChange.
@desc Skinned tab strip owns native child Pages. Arrows/Home/End select and reveal
      one page. Parent page content to Pages[index]. Captions clip to equal widths.
!]]
function Tabs.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Tabs");
    oComponent.Items, oComponent.Pages = {}, {};
    assert(type(tOptions.Items) == "table" and #tOptions.Items > 0, "Tabs require captions.");
    for nIndex, sText in ipairs(tOptions.Items) do
        assert(type(sText) == "string", "Tab captions must be strings.");
        oComponent.Items[nIndex] = sText;
        local oPage = _wx.wxPanel(oComponent.Control, _wx.wxID_ANY, _wx.wxDefaultPosition,
            _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTAB_TRAVERSAL);
        oPage:SetBackgroundColour(_wx.wxColour(24, 29, 36));
        oComponent.Pages[nIndex] = oPage;
    end

    --[[!
    @fqxn wxLuma.UI.Tabs.setValue
    @desc Validates a tab index, shows its page, hides all other pages and optionally reports a
        selection change.
    @param number nValue The requested numeric value or item index.
    @param boolean|nil bNotify Whether to notify when the stored value changes; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(finite(nValue) and nValue % 1 == 0 and oComponent.Pages[nValue], "Invalid tab index.");
        local bChanged = oComponent.Value ~= nValue;
        oComponent.Value = nValue;
        for nIndex, oPage in ipairs(oComponent.Pages) do
            oPage:Show(nIndex == nValue);
        end
        if (bChanged) then
            oComponent.refresh();
            if (bNotify and oComponent.OnChange) then
                oComponent.OnChange(nValue, oComponent);
            end
        end;
        return oComponent;
    end

    -- Lay out owned native children after a size change.
    oComponent.onLayout = function(nWidth, nHeight)
        for _, oPage in ipairs(oComponent.Pages) do
            oPage:SetSize(4, 40, math.max(1, nWidth - 8), math.max(1, nHeight - 44));
        end
    end;

    -- Apply this widget's pointer policy after the shared base updates input state.
    oComponent.pointer = function(sEvent, nX, nY)
        if (sEvent == "up" and oComponent.Pressed and oComponent.Hover and nY < 36) then
            local nWidth = oComponent.Control:GetClientSizeWH();
            oComponent.setValue(math.min(#oComponent.Items,
                math.floor(nX / (nWidth / #oComponent.Items)) + 1), true);
        end
    end;

    -- Handle this widget's supported navigation or resize keys.
    oComponent.key = function(nKey)
        if (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_UP) then
            oComponent.setValue((oComponent.Value - 2) % #oComponent.Items + 1, true);
        elseif (nKey == _wx.WXK_RIGHT or nKey == _wx.WXK_DOWN) then
            oComponent.setValue(oComponent.Value % #oComponent.Items + 1, true);
        elseif (nKey == _wx.WXK_HOME) then
            oComponent.setValue(1, true);
        elseif (nKey == _wx.WXK_END) then
            oComponent.setValue(#oComponent.Items, true);
        else
            return false;
        end;
        return true;
    end;

    -- Draw the widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth)
        for nIndex, sText in ipairs(oComponent.Items) do
            local nX     = math.floor((nIndex - 1) * nWidth / #oComponent.Items);
            local nRight = math.floor(nIndex * nWidth / #oComponent.Items);
            local sState = not oComponent.isEnabled() and "Disabled" or nIndex == oComponent.Value
                and "Pressed" or "Normal";
            oComponent.Skin.drawOpaque(oDC, "Button Left " .. sState, nX, 0);
            oComponent.Skin.drawOpaque(oDC, "Button Middle " .. sState, nX + 12, 0, math.max(1,
                nRight - nX - 24), 36);
            oComponent.Skin.drawOpaque(oDC, "Button Right " .. sState, nRight - 12, 0);
            oDC:SetFont(oComponent.Skin.Font);
            local nTextW = oDC:GetTextExtent(sText);
            oDC:SetClippingRegion(nX + 10, 5, math.max(1, nRight - nX - 20), 25);
            oComponent.Skin.text(oDC, sText, nX + (nRight - nX - nTextW) / 2, 9, oComponent.isEnabled());
            oDC:DestroyClippingRegion();
        end
    end;
    oComponent.setValue(tOptions.Value or 1);
    return oComponent;
end

return Tabs;
