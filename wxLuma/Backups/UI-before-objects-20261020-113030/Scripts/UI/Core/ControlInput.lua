-- Shared native input/lifecycle for the indicator, button and numeric widgets.
-- Widget policy and artwork live in their individual modules.
local wx = require("wx");
local ControlInput = {};

function ControlInput.create(oParent, tOptions, sKind, fConfigure)
    assert(tOptions and tOptions.Skin, "Control options require a shared Skin.");
    local tSkin = tOptions.Skin;
    local oControl = wx.wxControl(oParent, wx.wxID_ANY, wx.wxDefaultPosition,
        wx.wxDefaultSize, wx.wxBORDER_NONE + wx.wxWANTS_CHARS);
    oControl:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    oControl:SetBackgroundColour(wx.wxColour(24, 29, 36));
    oControl:SetName(tOptions.Text or sKind);
    local c = {Control = oControl, Kind = sKind, Text = tOptions.Text or "", Hover = false,
        Pressed = false, Selected = tOptions.Selected == true, Value = tOptions.Value,
        OnChange = tOptions.OnChange, Disposed = false, Vertical = tOptions.Vertical == true};
    local tInput = {drawPart = tOptions.Background and tSkin.draw or tSkin.drawOpaque};
    function tInput.enabled() return not c.Disposed and oControl:IsEnabled(); end
    function tInput.refresh() if (not c.Disposed) then oControl:Refresh(false); end end
    function tInput.release()
        c.Pressed, tInput.Keyboard, tInput.PressedPart = false, false, nil;
        if (oControl:HasCapture()) then oControl:ReleaseMouse(); end
    end
    function tInput.inside(nX, nY)
        local nW, nH = oControl:GetClientSizeWH();
        return nX >= 0 and nY >= 0 and nX < nW and nY < nH;
    end
    function tInput.part() return 0; end
    function tInput.notify() if (c.OnChange) then c.OnChange(c.getValue(), c); end end
    function c.getValue() return c.Value; end
    function c.setValue(vValue, bNotify)
        local bChanged = c.getValue() ~= vValue; c.Value = vValue;
        tInput.refresh(); if (bChanged and bNotify) then tInput.notify(); end; return c;
    end
    function c.setEnabled(bFlag)
        assert(type(bFlag) == "boolean", "Enabled flag must be boolean.");
        tInput.release(); c.Hover, tInput.HoverPart = false, nil;
        oControl:Enable(bFlag); tInput.refresh(); return c;
    end
    function c.getState()
        if (not tInput.enabled()) then return "Disabled"; end
        return c.Pressed and (c.Hover or tInput.Keyboard or tInput.drag) and "Pressed" or c.Hover and "Hover" or "Normal";
    end
    function c.layout(nX, nY, nWidth, nHeight)
        oControl:SetSize(nX, nY, nWidth, nHeight);
        if (tInput.layout) then tInput.layout(nWidth, nHeight); end
        tInput.refresh(); return c;
    end
    function c.commitText() return false; end
    -- Native bindings use these same adapters; there is no separate test path.
    function c.handlePointer(sEvent, nX, nY)
        if (not tInput.enabled()) then c.Hover, c.Pressed = false, false; return; end
        local bInside = tInput.inside(nX, nY);
        if (sEvent == "down" and bInside) then
            oControl:SetFocus(); c.Hover, c.Pressed = true, true;
            tInput.PressedPart, tInput.HoverPart = tInput.part(nX, nY), tInput.part(nX, nY);
            if (not oControl:HasCapture()) then oControl:CaptureMouse(); end
            if (tInput.drag) then tInput.drag(nX, nY); end
        elseif (sEvent == "move") then
            c.Hover, tInput.HoverPart = bInside, tInput.part(nX, nY);
            if (c.Pressed and tInput.drag and not tInput.Keyboard) then tInput.drag(nX, nY); end
        elseif (sEvent == "leave") then c.Hover, tInput.HoverPart = false, nil;
        elseif (sEvent == "up") then
            local bActivate = c.Pressed and not tInput.Keyboard and bInside and tInput.PressedPart == tInput.part(nX, nY);
            local nPart = tInput.PressedPart;
            if (c.Pressed and not tInput.Keyboard and tInput.drag) then tInput.drag(nX, nY); end
            tInput.release(); c.Hover, tInput.HoverPart = bInside, tInput.part(nX, nY);
            if (bActivate and not tInput.drag) then tInput.activate(nPart); end
        elseif (sEvent == "cancel") then tInput.release(); c.Hover, tInput.HoverPart = false, nil; end
        tInput.refresh();
    end
    function c.handleKey(sEvent, nKey)
        if (not tInput.enabled()) then return false; end
        local bToggle = nKey == wx.WXK_SPACE or (tInput.Enter and nKey == wx.WXK_RETURN);
        if (bToggle and tInput.Toggle) then
            if (sEvent == "down" and not tInput.Keyboard) then tInput.Keyboard, c.Pressed = true, true;
            elseif (sEvent == "up" and tInput.Keyboard) then tInput.release(); tInput.activate(0); end
            tInput.refresh(); return true;
        end
        if (sEvent ~= "down") then return false; end
        return tInput.key and tInput.key(nKey) or false;
    end
    function c.draw(oDC, nWidth, nHeight)
        if (c.Disposed) then return; end
        local sState = c.getState(); local oBrush = wx.wxBrush(wx.wxColour(24, 29, 36));
        if (tOptions.Background) then tOptions.Background(oDC, c); else oDC:SetBackground(oBrush); oDC:Clear(); end
        tInput.draw(oDC, nWidth, nHeight, sState, oBrush);
        if (tInput.enabled() and oControl:HasFocus()) then
            local oPen = wx.wxPen(wx.wxColour(105, 125, 145), 1, wx.wxPENSTYLE_DOT);
            oDC:SetPen(oPen); oDC:SetBrush(wx.wxTRANSPARENT_BRUSH); oDC:DrawRectangle(0, 0, nWidth, nHeight); oPen:delete();
        end
        oBrush:delete();
    end
    function c.destroy()
        if (c.Disposed) then return; end
        tInput.release(); c.Disposed = true;
        if (tInput.destroy) then tInput.destroy(); end
    end
    fConfigure(c, tInput, tOptions);
    oControl:Connect(wx.wxEVT_PAINT, function()
        if (c.Disposed) then return; end
        local nW, nH = oControl:GetClientSizeWH(); local oDC = wx.wxAutoBufferedPaintDC(oControl);
        c.draw(oDC, nW, nH); oDC:delete();
    end);
    for _, tBinding in ipairs({{wx.wxEVT_LEFT_DOWN,"down"},{wx.wxEVT_LEFT_DCLICK,"down"},{wx.wxEVT_LEFT_UP,"up"},{wx.wxEVT_MOTION,"move"},{wx.wxEVT_ENTER_WINDOW,"move"},{wx.wxEVT_LEAVE_WINDOW,"leave"}}) do
        local sEvent = tBinding[2];
        oControl:Connect(tBinding[1], function(oEvent) c.handlePointer(sEvent, oEvent:GetX(), oEvent:GetY()); end);
    end
    oControl:Connect(wx.wxEVT_MOUSE_CAPTURE_LOST, function() c.Pressed, c.Hover, tInput.Keyboard = false, false, false; tInput.refresh(); end);
    oControl:Connect(wx.wxEVT_KILL_FOCUS, function(oEvent) tInput.release(); c.Hover = false; tInput.refresh(); oEvent:Skip(); end);
    oControl:Connect(wx.wxEVT_SET_FOCUS, function(oEvent) tInput.refresh(); oEvent:Skip(); end);
    oControl:Connect(wx.wxEVT_KEY_DOWN, function(oEvent) if (not c.handleKey("down", oEvent:GetKeyCode())) then oEvent:Skip(); end end);
    oControl:Connect(wx.wxEVT_KEY_UP, function(oEvent) if (not c.handleKey("up", oEvent:GetKeyCode())) then oEvent:Skip(); end end);
    oControl:Connect(wx.wxEVT_SIZE, function(oEvent) tInput.refresh(); oEvent:Skip(); end);
    local nID = oControl:GetId();
    oControl:Connect(wx.wxEVT_DESTROY, function(oEvent) if (oEvent:GetId() == nID) then c.destroy(); end; oEvent:Skip(); end);
    c.setEnabled(tOptions.Enabled ~= false); return c;
end
return ControlInput;
