local wx = require("wx");
local frame = require("UI.Core.ControlDrawing").frame;
local ControlSurface = {};

function ControlSurface.create(oParent, tOptions, sKind)
    assert(tOptions and tOptions.Skin, "Control options require a shared Skin.");
    local oControl = wx.wxControl(oParent, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxBORDER_NONE + wx.wxWANTS_CHARS + wx.wxTAB_TRAVERSAL);
    oControl:SetBackgroundStyle(wx.wxBG_STYLE_PAINT); oControl:SetBackgroundColour(wx.wxColour(24, 29, 36));
    oControl:SetName(tOptions.Text or sKind);
    local c = {Control = oControl, Kind = sKind, Skin = tOptions.Skin, Disposed = false,
        Hover = false, Pressed = false, OnChange = tOptions.OnChange};
    function c.getValue() return c.Value; end
    function c.refresh() if (not c.Disposed) then oControl:Refresh(false); end end
    function c.isEnabled() return not c.Disposed and oControl:IsEnabled(); end
    function c.getState() return not c.isEnabled() and "Disabled" or c.Pressed and "Pressed" or c.Hover and "Hover" or "Normal"; end
    function c.cancel()
        c.Pressed = false; if (oControl:HasCapture()) then oControl:ReleaseMouse(); end
        if (c.onCancel) then c.onCancel(); end
    end
    function c.setEnabled(bEnabled)
        assert(type(bEnabled) == "boolean", "Enabled flag must be boolean.");
        c.cancel(); c.Hover = false; oControl:Enable(bEnabled);
        if (c.onEnable) then c.onEnable(bEnabled); end; c.refresh(); return c;
    end
    function c.layout(nX, nY, nW, nH)
        local nOldX, nOldY = oControl:GetPositionXY(); local nOldW, nOldH = oControl:GetSizeWH();
        if (nX ~= nOldX or nY ~= nOldY or nW ~= nOldW or nH ~= nOldH) then oControl:SetSize(nX, nY, nW, nH); end
        if (c.onLayout) then c.onLayout(nW, nH); end; return c;
    end
    function c.destroy()
        if (c.Disposed) then return; end; c.cancel(); c.Disposed = true;
        if (c.onDestroy) then c.onDestroy(); end
    end
    function c.handlePointer(sEvent, nX, nY)
        if (not c.isEnabled()) then return; end
        local bOldHover, bOldPressed = c.Hover, c.Pressed;
        local nW, nH = oControl:GetClientSizeWH();
        c.Hover = sEvent ~= "leave" and nX >= 0 and nY >= 0 and nX < nW and nY < nH;
        if (sEvent == "down" and c.Hover) then
            oControl:SetFocus(); c.Pressed = true; if (not oControl:HasCapture()) then oControl:CaptureMouse(); end
        end
        if (c.pointer) then c.pointer(sEvent, nX, nY); end
        if (sEvent == "up" or sEvent == "cancel") then c.cancel(); end;
        if (not c.PointerRefresh or (c.PointerStateRefresh and (bOldHover ~= c.Hover or bOldPressed ~= c.Pressed))) then c.refresh(); end
    end
    function c.handleKey(sEvent, nKey) return c.isEnabled() and sEvent == "down" and c.key and c.key(nKey) or false; end
    for _, tBinding in ipairs({{wx.wxEVT_LEFT_DOWN,"down"},{wx.wxEVT_LEFT_DCLICK,"down"},{wx.wxEVT_LEFT_UP,"up"},
        {wx.wxEVT_MOTION,"move"},{wx.wxEVT_ENTER_WINDOW,"move"},{wx.wxEVT_LEAVE_WINDOW,"leave"}}) do
        local sEvent = tBinding[2]; oControl:Connect(tBinding[1], function(oEvent) c.handlePointer(sEvent, oEvent:GetX(), oEvent:GetY()); end);
    end
    oControl:Connect(wx.wxEVT_MOUSE_CAPTURE_LOST, function() c.cancel(); c.refresh(); end);
    oControl:Connect(wx.wxEVT_KEY_DOWN, function(oEvent) if (not c.handleKey("down", oEvent:GetKeyCode())) then oEvent:Skip(); end end);
    oControl:Connect(wx.wxEVT_MOUSEWHEEL, function(oEvent)
        if (c.isEnabled() and c.wheel) then c.wheel(oEvent:GetWheelRotation() / oEvent:GetWheelDelta()); else oEvent:Skip(); end
    end);
    oControl:Connect(wx.wxEVT_KILL_FOCUS, function(oEvent) c.cancel(); c.refresh(); oEvent:Skip(); end);
    oControl:Connect(wx.wxEVT_SET_FOCUS, function(oEvent) c.refresh(); oEvent:Skip(); end);
    oControl:Connect(wx.wxEVT_SIZE, function(oEvent)
        if (c.onLayout) then c.onLayout(oControl:GetClientSizeWH()); end; c.refresh(); oEvent:Skip();
    end);
    function c.draw(oDC, nW, nH)
        if (c.Disposed) then return; end; frame(oDC, 0, 0, nW, nH, c.isEnabled(), oControl:HasFocus());
        if (c.drawContent) then c.drawContent(oDC, nW, nH); end
    end
    oControl:Connect(wx.wxEVT_PAINT, function()
        -- Buffered DCs do not limit our Lua row loop to the native dirty area.
        -- Read it before creating the paint DC, which validates that region.
        if (c.TrackPaintBounds and not c.Disposed) then
            local oBox = oControl:GetUpdateRegion():GetBox();
            c.PaintTop, c.PaintBottom = oBox:GetY(), oBox:GetY() + oBox:GetHeight();
        end
        local oDC = wx.wxAutoBufferedPaintDC(oControl); c.draw(oDC, oControl:GetClientSizeWH());
        c.PaintTop, c.PaintBottom = nil, nil; oDC:delete();
    end);
    local nID = oControl:GetId();
    oControl:Connect(wx.wxEVT_DESTROY, function(oEvent) if (oEvent:GetId() == nID) then c.destroy(); end; oEvent:Skip(); end);
    oControl:Enable(tOptions.Enabled ~= false); return c;
end

return ControlSurface;
