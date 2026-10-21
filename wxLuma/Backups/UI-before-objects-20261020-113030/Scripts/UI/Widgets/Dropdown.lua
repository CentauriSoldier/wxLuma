local wx = require("wx");
local Dropdown = {};
local surface = require("UI.Core.ControlSurface").create;
local finite = require("UI.Core.ControlNumeric").finite;
local List = require("UI.Widgets.List");

--[[!
@fqxn OpenWar.UI.Dropdown.create
@param table tOptions Skin, Items (strings); optional Value (index/0), Rows (8), Enabled, OnChange.
@desc Enter/Space/Down opens; popup arrows preview, Enter/click commits; Escape
      cancels. Owned borderless hosting dismisses on native deactivation.
@ret table c Standard methods plus open/close/isOpen/setItems/getText, List and Popup.
!]]
function Dropdown.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Dropdown"); c.Popup = wx.wxFrame(c.Control, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxFRAME_NO_TASKBAR + wx.wxFRAME_FLOAT_ON_PARENT + wx.wxBORDER_NONE);
    c.Value = 0; c.Open = false; local nRows = tOptions.Rows or 8;
    assert(finite(nRows) and nRows >= 1 and nRows % 1 == 0, "Dropdown Rows must be positive integer.");
    function c.isOpen() return not c.Disposed and c.Open and c.Popup:IsShown(); end
    function c.close(bCommit, bFocus)
        if (not c.Open) then return; end; c.Open = false;
        c.List.setHover(0); local nValue = c.List.getValue(); c.Popup:Show(false);
        if (bCommit) then c.setValue(nValue, true); end
        if (bFocus ~= false and c.isEnabled()) then c.Control:SetFocus(); end; c.refresh();
    end
    c.List = List.create(c.Popup, {Skin = c.Skin, Items = tOptions.Items, Value = tOptions.Value or 0,
        OnActivate = function() c.close(true); end, OnCancel = function() c.close(false); end});
    function c.setValue(nValue, bNotify)
        c.List.setValue(nValue); c.List.CommittedValue = nValue; local bChanged = c.Value ~= nValue; c.Value = nValue;
        if (bChanged) then c.refresh(); if (bNotify and c.OnChange) then c.OnChange(nValue, c); end end; return c;
    end
    function c.setItems(tItems) c.close(false, false); c.List.setItems(tItems); c.Value = c.List.getValue(); c.refresh(); return c; end
    function c.getText() return c.List.Items[c.Value] or ""; end
    function c.open()
        if (not c.isEnabled() or not c.Control:IsShownOnScreen() or c.isOpen() or #c.List.Items == 0) then return false; end
        c.cancel(); local nW, nH = c.Control:GetClientSizeWH();
        local oPoint = c.Control:ClientToScreen(wx.wxPoint(0, 0));
        local nDisplay = wx.wxDisplay.GetFromWindow(c.Control);
        local oDisplay = wx.wxDisplay(nDisplay < 0 and 0 or nDisplay); local oArea = oDisplay:GetClientArea();
        nW = math.min(nW, oArea:GetWidth());
        local nVisible = math.max(1, math.floor((oArea:GetHeight() - 8) / c.List.RowHeight));
        local nHeight = math.min(nRows, #c.List.Items, nVisible) * c.List.RowHeight + 8;
        c.Popup:SetSize(nW, nHeight); c.List.layout(0, 0, nW, nHeight); c.List.setValue(c.Value > 0 and c.Value or 1);
        local nX = math.max(oArea:GetX(), math.min(oPoint:GetX(), oArea:GetX() + oArea:GetWidth() - nW));
        local nY = oPoint:GetY() + nH;
        if (nY + nHeight > oArea:GetY() + oArea:GetHeight()) then nY = math.max(oArea:GetY(), oPoint:GetY() - nHeight); end
        c.Popup:SetPosition(wx.wxPoint(nX, nY)); oDisplay:delete();
        c.List.setHover(0); c.List.CommittedValue = c.Value; c.Open = true; c.Popup:Show(true); c.Popup:Raise(); c.List.Control:SetFocus(); c.refresh(); return true;
    end
    c.Popup:Connect(wx.wxEVT_ACTIVATE, function(oEvent) if (not oEvent:GetActive()) then c.close(false, false); end; oEvent:Skip(); end);
    c.Popup:Connect(wx.wxEVT_SHOW, function(oEvent) if (not oEvent:IsShown()) then c.Open = false; c.refresh(); end; oEvent:Skip(); end);
    c.List.Control:Connect(wx.wxEVT_KEY_DOWN, function(oEvent)
        if (oEvent:GetKeyCode() == wx.WXK_TAB) then c.close(true); c.Control:Navigate(not oEvent:ShiftDown()); else oEvent:Skip(); end
    end);
    c.Control:Connect(wx.wxEVT_SHOW, function(oEvent) if (not oEvent:IsShown()) then c.close(false, false); end; oEvent:Skip(); end);
    oParent:Connect(wx.wxEVT_SHOW, function(oEvent) if (not oEvent:IsShown()) then c.close(false, false); end; oEvent:Skip(); end);
    c.onEnable  = function(bEnabled) if (not bEnabled) then c.close(false, false); end; c.List.setEnabled(bEnabled); end;
    c.onLayout  = function() c.close(false, false); end;
    c.onDestroy = function() c.close(false, false); c.List.destroy(); c.Popup:Destroy(); end;
    c.pointer = function(sEvent)
        if (sEvent == "up" and c.Pressed and c.Hover) then if (c.isOpen()) then c.close(false); else c.open(); end end
    end;
    c.key = function(nKey)
        if (nKey == wx.WXK_ESCAPE and c.isOpen()) then c.close(false); return true; end
        if (nKey == wx.WXK_SPACE or nKey == wx.WXK_RETURN or nKey == wx.WXK_DOWN or nKey == wx.WXK_UP or nKey == wx.WXK_F4) then c.open(); return true; end
        return false;
    end;
    c.drawContent = function(oDC, nW, nH)
        oDC:SetClippingRegion(8, 4, math.max(1, nW - 38), math.max(1, nH - 8));
        c.Skin.text(oDC, c.getText(), 10, (nH - 18) / 2, c.isEnabled()); oDC:DestroyClippingRegion();
        c.Skin.drawOpaque(oDC, "Spinner Down " .. c.getState(), nW - 27, (nH - 18) / 2);
    end;
    c.setValue(tOptions.Value or 0); c.setEnabled(tOptions.Enabled ~= false); return c;
end

return Dropdown;
