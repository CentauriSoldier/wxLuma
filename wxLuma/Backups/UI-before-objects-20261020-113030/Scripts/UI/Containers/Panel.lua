local wx = require("wx");
local Panel = {};
local surface = require("UI.Core.ControlSurface").create;

--[[!
@fqxn OpenWar.UI.Panel.create
@param table tOptions Skin; optional Text, MinWidth (220), MinHeight (140), OnResize(width,height,component), Enabled.
@desc Embedded panel owns Content. Drag bottom-right grip or use focused arrows
      (Shift for ten pixels) within parent bounds. Escape cancels a drag. show toggles visibility.
!]]
function Panel.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Panel"); c.MinWidth, c.MinHeight = tOptions.MinWidth or 220, tOptions.MinHeight or 140;
    c.Content = wx.wxPanel(c.Control, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxBORDER_NONE + wx.wxTAB_TRAVERSAL);
    c.Content:SetBackgroundColour(wx.wxColour(24, 29, 36));
    local tDrag;
    c.onCancel = function() tDrag = nil; end;
    c.onLayout = function(nW, nH) c.Content:SetSize(8, 34, math.max(1, nW - 16), math.max(1, nH - 58)); end;
    function c.resize(nW, nH, bNotify)
        local nX, nY = c.Control:GetPositionXY(); local nParentW, nParentH = oParent:GetClientSizeWH();
        nW = math.max(math.min(c.MinWidth, nParentW - nX), math.min(nParentW - nX - 4, math.floor(nW)));
        nH = math.max(math.min(c.MinHeight, nParentH - nY), math.min(nParentH - nY - 4, math.floor(nH)));
        local nOldW, nOldH = c.Control:GetSizeWH();
        if (nW ~= nOldW or nH ~= nOldH) then c.layout(nX, nY, nW, nH); if (bNotify and tOptions.OnResize) then tOptions.OnResize(nW, nH, c); end end
        return c;
    end
    function c.show(bShow) c.cancel(); c.Control:Show(bShow); return c; end
    c.pointer = function(sEvent, nX, nY)
        local nW, nH = c.Control:GetClientSizeWH();
        if (sEvent == "down") then
            tDrag = nil; if (nX >= nW - 24 and nY >= nH - 24) then tDrag = {X = nX, Y = nY, Width = nW, Height = nH}; end
        elseif ((sEvent == "move" or sEvent == "up") and c.Pressed and tDrag) then c.resize(tDrag.Width + nX - tDrag.X, tDrag.Height + nY - tDrag.Y, true); end
        if (sEvent == "move" and not c.Pressed) then c.Control:SetCursor(wx.wxCursor(nX >= nW - 24 and nY >= nH - 24 and wx.wxCURSOR_SIZENWSE or wx.wxCURSOR_ARROW)); end
        if (sEvent == "up" or sEvent == "cancel") then tDrag = nil; end
    end;
    c.key = function(nKey)
        if (nKey == wx.WXK_ESCAPE and tDrag) then c.resize(tDrag.Width, tDrag.Height, true); tDrag = nil; c.cancel(); return true; end
        local nW, nH = c.Control:GetClientSizeWH(); local nStep = wx.wxGetKeyState(wx.WXK_SHIFT) and 10 or 1;
        if (nKey == wx.WXK_LEFT) then nW = nW - nStep; elseif (nKey == wx.WXK_RIGHT) then nW = nW + nStep;
        elseif (nKey == wx.WXK_UP) then nH = nH - nStep; elseif (nKey == wx.WXK_DOWN) then nH = nH + nStep; else return false; end
        c.resize(nW, nH, true); return true;
    end;
    c.drawContent = function(oDC, nW, nH)
        c.Skin.text(oDC, tOptions.Text or "Panel", 12, 9, c.isEnabled());
        local oPen = wx.wxPen(wx.wxColour(125, 143, 160), 1, wx.wxPENSTYLE_SOLID); oDC:SetPen(oPen);
        for nOffset = 5, 17, 4 do oDC:DrawLine(nW - nOffset, nH - 4, nW - 4, nH - nOffset); end; oPen:delete();
    end;
    return c;
end

return Panel;
