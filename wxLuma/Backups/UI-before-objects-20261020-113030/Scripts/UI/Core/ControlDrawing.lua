local wx = require("wx");
local ControlDrawing = {};

function ControlDrawing.frame(oDC, nX, nY, nW, nH, bEnabled, bActive)
    local oBrush = wx.wxBrush(wx.wxColour(24, 29, 36));
    local oPen   = wx.wxPen(wx.wxColour(bActive and 145 or 68, bActive and 170 or 78, bActive and 191 or 89), 1, wx.wxPENSTYLE_SOLID);
    oDC:SetBrush(oBrush); oDC:SetPen(oPen); oDC:DrawRectangle(nX, nY, nW, nH);
    oPen:delete(); oBrush:delete();
    if (bEnabled) then oDC:GradientFillLinear(wx.wxRect(nX + 1, nY + 1, math.max(1, nW - 2), 3),
        wx.wxColour(67, 76, 87), wx.wxColour(29, 35, 43), wx.wxSOUTH); end
end

return ControlDrawing;
