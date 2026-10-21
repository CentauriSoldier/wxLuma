local wx = require("wx");
local List = {};
local surface = require("UI.Core.ControlSurface").create;
local finite = require("UI.Core.ControlNumeric").finite;
local Scrollbar = require("UI.Widgets.Scrollbar");

--[[!
@fqxn OpenWar.UI.List.create
@param table tOptions Skin, Items (strings); optional Value (1-based index, 0 for none), RowHeight (28), Enabled, OnChange, OnActivate, OnCancel.
@desc Single selection. Only visible rows draw. Wheel/scrollbar, arrows, Page keys,
      Home/End and character search keep selection visible. Enter activates.
@ret table c Standard methods plus setItems/getText/scrollTo/getVisibleCount and Scrollbar.
!]]
function List.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "List"); c.RowHeight = tOptions.RowHeight or 28; c.First = 1; c.Value = 0; c.HoverRow = 0; c.PointerRefresh = true; c.TrackPaintBounds = true;
    assert(finite(c.RowHeight) and c.RowHeight >= 20 and c.RowHeight % 1 == 0, "Invalid list RowHeight.");
    function c.getVisibleCount()
        local _, nH = c.Control:GetClientSizeWH(); return math.max(1, math.floor((nH - 8) / c.RowHeight));
    end
    local function fRow(nIndex)
        if (c.Disposed or nIndex < c.First or nIndex >= c.First + c.getVisibleCount()) then return; end
        local nW = c.Control:GetClientSizeWH();
        c.Control:RefreshRect(wx.wxRect(4, 4 + (nIndex - c.First) * c.RowHeight, math.max(1, nW - 30), c.RowHeight), false);
    end
    function c.setHover(nIndex)
        if (not c.isEnabled() or nIndex < c.First or nIndex >= c.First + c.getVisibleCount() or nIndex > #c.Items) then nIndex = 0; end
        if (nIndex ~= c.HoverRow) then local nOld = c.HoverRow; c.HoverRow = nIndex; fRow(nOld); fRow(nIndex); end
    end
    function c.scrollTo(nFirst)
        nFirst = math.max(1, math.min(math.max(1, #c.Items - c.getVisibleCount() + 1), math.floor(nFirst)));
        if (nFirst == c.First) then return c; end
        c.setHover(0); local nDelta = c.First - nFirst; c.First = nFirst;
        if (c.Scrollbar) then c.Scrollbar.setValue(c.First - 1); end
        local nW = c.Control:GetClientSizeWH();
        if (math.abs(nDelta) < c.getVisibleCount() and c.Control:IsShownOnScreen()) then
            c.Control:ScrollWindow(0, nDelta * c.RowHeight, wx.wxRect(4, 4, math.max(1, nW - 30), c.getVisibleCount() * c.RowHeight));
        else c.refresh(); end
        return c;
    end
    function c.setValue(nValue, bNotify)
        assert(finite(nValue) and nValue % 1 == 0 and nValue >= 0 and nValue <= #c.Items, "Invalid list selection.");
        local nOld = c.Value; local bChanged = nOld ~= nValue; c.Value = nValue;
        if (nValue > 0) then
            if (nValue < c.First) then c.scrollTo(nValue);
            elseif (nValue >= c.First + c.getVisibleCount()) then c.scrollTo(nValue - c.getVisibleCount() + 1); end
        end
        if (bChanged) then fRow(nOld); fRow(nValue); if (bNotify and c.OnChange) then c.OnChange(nValue, c); end end; return c;
    end
    function c.getText() return c.Items[c.Value] or ""; end
    function c.setItems(tItems)
        assert(type(tItems) == "table", "List Items must be an array of strings.");
        local tCopy = {}; for nIndex, sText in ipairs(tItems) do assert(type(sText) == "string", "List items must be strings."); tCopy[nIndex] = sText; end
        c.setHover(0); c.Items = tCopy; c.Value = math.min(c.Value, #tCopy); c.First = 1;
        if (c.onLayout) then c.onLayout(c.Control:GetClientSizeWH()); end; c.refresh(); return c;
    end
    c.Items = {};
    c.Scrollbar = Scrollbar.create(c.Control, {Skin = c.Skin, Min = 0, Max = 0, Page = 1, Value = 0,
        OnChange = function(nValue) c.scrollTo(nValue + 1); end});
    c.onLayout = function(nW, nH)
        c.setHover(0);
        c.Scrollbar.layout(math.max(1, nW - 23), 4, 20, math.max(40, nH - 8));
        c.Scrollbar.setRange(0, math.max(0, #c.Items - c.getVisibleCount()), c.getVisibleCount()); c.scrollTo(c.First);
        c.Scrollbar.Control:Show(#c.Items > c.getVisibleCount());
    end;
    c.onEnable = function(bEnabled) c.setHover(0); c.Scrollbar.setEnabled(bEnabled); end;
    c.onDestroy = function() c.Scrollbar.destroy(); end;
    local nDown;
    c.pointer = function(sEvent, nX, nY)
        local nW = c.Control:GetClientSizeWH(); local nIndex = c.First + math.floor((nY - 4) / c.RowHeight);
        c.setHover((sEvent ~= "leave" and sEvent ~= "cancel" and c.Hover and nX >= 4 and nX < nW - 26 and nY >= 4) and nIndex or 0);
        if (sEvent == "down") then nDown = nIndex;
        elseif (sEvent == "up" and c.Pressed and c.Hover and nY >= 4 and nX < nW - 24 and nIndex == nDown and nIndex <= #c.Items) then
            c.setValue(nIndex, true); c.cancel(); if (tOptions.OnActivate) then tOptions.OnActivate(nIndex, c); end
        end
    end;
    c.key = function(nKey)
        c.setHover(0);
        local nValue = c.Value;
        if (nKey == wx.WXK_UP) then nValue = math.max(1, nValue - 1);
        elseif (nKey == wx.WXK_DOWN) then nValue = math.min(#c.Items, nValue + 1);
        elseif (nKey == wx.WXK_HOME) then nValue = 1;
        elseif (nKey == wx.WXK_END) then nValue = #c.Items;
        elseif (nKey == wx.WXK_PAGEUP) then nValue = math.max(1, nValue - c.getVisibleCount());
        elseif (nKey == wx.WXK_PAGEDOWN) then nValue = math.min(#c.Items, nValue + c.getVisibleCount());
        elseif (nKey == wx.WXK_RETURN or nKey == wx.WXK_NUMPAD_ENTER) then
            if (c.Value > 0 and tOptions.OnActivate) then tOptions.OnActivate(c.Value, c); end; return true;
        elseif (nKey == wx.WXK_ESCAPE and tOptions.OnCancel) then tOptions.OnCancel(c); return true;
        else return false; end
        c.setValue(#c.Items == 0 and 0 or nValue, true); return true;
    end;
    c.wheel = function(nSteps) c.scrollTo(c.First - nSteps * 3); end;
    c.Control:Connect(wx.wxEVT_CHAR, function(oEvent)
        local nKey = oEvent:GetKeyCode();
        if (c.isEnabled() and nKey >= 32 and nKey <= 126 and #c.Items > 0) then
            local sChar = string.char(nKey):lower();
            for nOffset = 1, #c.Items do
                local nIndex = (c.Value + nOffset - 1) % #c.Items + 1;
                if (c.Items[nIndex]:sub(1, 1):lower() == sChar) then c.setValue(nIndex, true); break; end
            end
        else oEvent:Skip(); end
    end);
    c.drawContent = function(oDC, nW, nH)
        oDC:SetClippingRegion(4, 4, math.max(1, nW - 30), math.max(1, nH - 8));
        local nFirst = c.PaintTop and math.max(c.First, c.First + math.floor((c.PaintTop - 4) / c.RowHeight)) or c.First;
        local nLast  = math.min(#c.Items, c.First + c.getVisibleCount() - 1);
        if (c.PaintBottom) then nLast = math.min(nLast, c.First + math.floor((c.PaintBottom - 5) / c.RowHeight)); end
        for nIndex = nFirst, nLast do
            local nY = 4 + (nIndex - c.First) * c.RowHeight;
            if (nIndex == c.Value) then oDC:GradientFillLinear(wx.wxRect(4, nY, nW - 30, c.RowHeight),
                c.isEnabled() and wx.wxColour(65, 82, 99) or wx.wxColour(41, 46, 53), wx.wxColour(28, 36, 45), wx.wxSOUTH); end
            if (nIndex == c.HoverRow) then
                if (nIndex ~= c.Value) then oDC:GradientFillLinear(wx.wxRect(4, nY, nW - 30, c.RowHeight),
                    wx.wxColour(43, 55, 67), wx.wxColour(29, 38, 48), wx.wxSOUTH); end
                local oPen = wx.wxPen(wx.wxColour(117, 145, 166), 1, wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen); oDC:SetBrush(wx.wxTRANSPARENT_BRUSH); oDC:DrawRectangle(4, nY, nW - 30, c.RowHeight); oPen:delete();
            end
            if (nIndex == c.CommittedValue) then
                local oPen = wx.wxPen(wx.wxColour(145, 175, 198), 2, wx.wxPENSTYLE_SOLID); oDC:SetPen(oPen);
                oDC:DrawLine(6, nY + 5, 6, nY + c.RowHeight - 5); oPen:delete();
            end
            c.Skin.text(oDC, c.Items[nIndex], 10, nY + (c.RowHeight - 18) / 2, c.isEnabled());
        end; oDC:DestroyClippingRegion();
    end;
    c.setItems(tOptions.Items); c.setValue(tOptions.Value or 0); c.setEnabled(tOptions.Enabled ~= false); return c;
end

return List;
