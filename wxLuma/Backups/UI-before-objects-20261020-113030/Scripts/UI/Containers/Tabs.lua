local wx = require("wx");
local Tabs = {};
local surface = require("UI.Core.ControlSurface").create;
local finite = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn OpenWar.UI.Tabs.create
@param table tOptions Skin, Items (captions); optional Value (1), Enabled, OnChange.
@desc Skinned tab strip owns native child Pages. Arrows/Home/End select and reveal
      one page. Parent page content to Pages[index]. Captions clip to equal widths.
!]]
function Tabs.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Tabs"); c.Items, c.Pages = {}, {};
    assert(type(tOptions.Items) == "table" and #tOptions.Items > 0, "Tabs require captions.");
    for nIndex, sText in ipairs(tOptions.Items) do
        assert(type(sText) == "string", "Tab captions must be strings."); c.Items[nIndex] = sText;
        local oPage = wx.wxPanel(c.Control, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBORDER_NONE + wx.wxTAB_TRAVERSAL);
        oPage:SetBackgroundColour(wx.wxColour(24, 29, 36)); c.Pages[nIndex] = oPage;
    end
    function c.setValue(nValue, bNotify)
        assert(finite(nValue) and nValue % 1 == 0 and c.Pages[nValue], "Invalid tab index.");
        local bChanged = c.Value ~= nValue; c.Value = nValue;
        for nIndex, oPage in ipairs(c.Pages) do oPage:Show(nIndex == nValue); end
        if (bChanged) then c.refresh(); if (bNotify and c.OnChange) then c.OnChange(nValue, c); end end; return c;
    end
    c.onLayout = function(nW, nH) for _, oPage in ipairs(c.Pages) do oPage:SetSize(4, 40, math.max(1, nW - 8), math.max(1, nH - 44)); end end;
    c.pointer = function(sEvent, nX, nY)
        if (sEvent == "up" and c.Pressed and c.Hover and nY < 36) then
            local nW = c.Control:GetClientSizeWH(); c.setValue(math.min(#c.Items, math.floor(nX / (nW / #c.Items)) + 1), true);
        end
    end;
    c.key = function(nKey)
        if (nKey == wx.WXK_LEFT or nKey == wx.WXK_UP) then c.setValue((c.Value - 2) % #c.Items + 1, true);
        elseif (nKey == wx.WXK_RIGHT or nKey == wx.WXK_DOWN) then c.setValue(c.Value % #c.Items + 1, true);
        elseif (nKey == wx.WXK_HOME) then c.setValue(1, true);
        elseif (nKey == wx.WXK_END) then c.setValue(#c.Items, true); else return false; end; return true;
    end;
    c.drawContent = function(oDC, nW)
        for nIndex, sText in ipairs(c.Items) do
            local nX = math.floor((nIndex - 1) * nW / #c.Items); local nRight = math.floor(nIndex * nW / #c.Items);
            local sState = not c.isEnabled() and "Disabled" or nIndex == c.Value and "Pressed" or "Normal";
            c.Skin.drawOpaque(oDC, "Button Left " .. sState, nX, 0);
            c.Skin.drawOpaque(oDC, "Button Middle " .. sState, nX + 12, 0, math.max(1, nRight - nX - 24), 36);
            c.Skin.drawOpaque(oDC, "Button Right " .. sState, nRight - 12, 0);
            oDC:SetFont(c.Skin.Font); local nTextW = oDC:GetTextExtent(sText);
            oDC:SetClippingRegion(nX + 10, 5, math.max(1, nRight - nX - 20), 25);
            c.Skin.text(oDC, sText, nX + (nRight - nX - nTextW) / 2, 9, c.isEnabled()); oDC:DestroyClippingRegion();
        end
    end;
    c.setValue(tOptions.Value or 1); return c;
end

return Tabs;
