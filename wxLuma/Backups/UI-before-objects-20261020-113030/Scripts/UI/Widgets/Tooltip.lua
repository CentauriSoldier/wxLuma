local wx = require("wx");
local Tooltip = {};
local frame = require("UI.Core.ControlDrawing").frame;

--[[!
@fqxn OpenWar.UI.Tooltip.create
@param wxWindow oTarget Hover/focus target; tooltip lifetime follows target.
@param table tOptions Skin, Text; optional Delay (500 milliseconds), Enabled.
@desc Skinned non-activating popup after hover delay or focus; hides on leave,
      press, key, focus loss, disable, target hiding or destruction.
@ret table c Control, show/hide/setText/setEnabled/destroy/isShown.
!]]
function Tooltip.create(oTarget, tOptions)
    assert(tOptions and tOptions.Skin and type(tOptions.Text) == "string", "Tooltip requires Skin and Text.");
    local oPopup = wx.wxPopupWindow(oTarget, wx.wxBORDER_NONE);
    local c = {Control = oPopup, Text = tOptions.Text, Disposed = false, Enabled = tOptions.Enabled ~= false};
    local oTimer = wx.wxTimer(oTarget); local nTimerID = oTimer:GetId();
    function c.hide() if (c.Disposed) then return; end; oTimer:Stop(); oPopup:Show(false); end
    function c.isShown() return not c.Disposed and oPopup:IsShown(); end
    function c.show()
        if (c.Disposed or not c.Enabled or not oTarget:IsEnabled() or not oTarget:IsShownOnScreen()) then return false; end
        oTimer:Stop(); local oDC = wx.wxClientDC(oTarget); oDC:SetFont(tOptions.Skin.Font);
        local _, nW, nH = oDC:GetMultiLineTextExtent(c.Text); oDC:delete(); local nTargetW, nTargetH = oTarget:GetSizeWH();
        oPopup:SetSize(nW + 24, nH + 20); oPopup:Position(oTarget:ClientToScreen(wx.wxPoint(0, 0)), wx.wxSize(nTargetW, nTargetH));
        oPopup:Show(true); oPopup:Refresh(false); return true;
    end
    function c.setText(sText) assert(type(sText) == "string", "Tooltip text must be a string."); c.Text = sText; c.hide(); return c; end
    function c.setEnabled(bEnabled) c.Enabled = bEnabled; if (not bEnabled) then c.hide(); end; return c; end
    function c.destroy()
        if (c.Disposed) then return; end; c.hide(); c.Disposed = true; oTimer:Stop(); oTimer:delete(); oPopup:Destroy();
    end
    oPopup:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    oPopup:Connect(wx.wxEVT_PAINT, function()
        local oDC = wx.wxAutoBufferedPaintDC(oPopup);
        if (c.Disposed) then oDC:delete(); return; end
        local nW, nH = oPopup:GetClientSizeWH();
        frame(oDC, 0, 0, nW, nH, true, true); tOptions.Skin.text(oDC, c.Text, 12, 10, true); oDC:delete();
    end);
    oTarget:Connect(nTimerID, wx.wxEVT_TIMER, function() if (not c.Disposed) then c.show(); end end);
    oTarget:Connect(wx.wxEVT_ENTER_WINDOW, function(oEvent) if (not c.Disposed) then oTimer:Start(tOptions.Delay or 500, true); end; oEvent:Skip(); end);
    oTarget:Connect(wx.wxEVT_SET_FOCUS, function(oEvent) c.show(); oEvent:Skip(); end);
    for _, nEvent in ipairs({wx.wxEVT_LEAVE_WINDOW, wx.wxEVT_LEFT_DOWN, wx.wxEVT_KILL_FOCUS, wx.wxEVT_KEY_DOWN, wx.wxEVT_SHOW}) do
        oTarget:Connect(nEvent, function(oEvent) if (not c.Disposed) then c.hide(); end; oEvent:Skip(); end);
    end
    local nTargetID = oTarget:GetId();
    oTarget:Connect(wx.wxEVT_DESTROY, function(oEvent) if (oEvent:GetId() == nTargetID) then c.destroy(); end; oEvent:Skip(); end); return c;
end

return Tooltip;
