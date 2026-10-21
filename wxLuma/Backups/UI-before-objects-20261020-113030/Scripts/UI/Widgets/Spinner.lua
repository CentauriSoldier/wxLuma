local wx = require("wx");
local ControlInput = require("UI.Core.ControlInput");
local ControlNumeric = require("UI.Core.ControlNumeric");
local Spinner = {};

--[[!
@fqxn OpenWar.UI.Spinner.create
@param wxWindow oParent Native parent.
@param table tOptions Skin, integer Min/Max/Step/Value, optional Enabled/OnChange. Min must be below Max, Step positive.
@ret table c Integer editor and single-click stepper. Enter/focus loss validates text; invalid text restores previous value. No hold-repeat.
!]]

function Spinner.create(oParent, tOptions)
    return ControlInput.create(oParent, tOptions, "Spinner", function(c, tInput)
        local tSkin = tOptions.Skin; local finite = ControlNumeric.finite;
        ControlNumeric.configure(c, tInput, tOptions, true);
        local oText = wx.wxTextCtrl(c.Control, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize,
            wx.wxTE_PROCESS_ENTER + wx.wxTE_RIGHT + wx.wxBORDER_NONE);
        c.TextControl, tInput.TextControl = oText, oText; oText:SetFont(tSkin.Font);
        oText:SetBackgroundColour(wx.wxColour(24, 29, 36)); oText:SetForegroundColour(wx.wxColour(208, 218, 230));
        function c.commitText()
            if (not tInput.enabled()) then return false; end
            local nValue = tonumber(oText:GetValue());
            if (not finite(nValue) or nValue % 1 ~= 0 or nValue < c.Min or nValue > c.Max) then
                oText:ChangeValue(tostring(c.Value)); return false;
            end
            c.setValue(nValue, true); return true;
        end
        tInput.part = function(nX, nY)
            local nW = c.Control:GetClientSizeWH();
            if (nX >= nW - 26 and nX < nW - 2 and nY >= 2 and nY < 38) then return nY < 20 and 1 or 2; end
            return 0;
        end;
        tInput.layout = function(nWidth) oText:SetSize(10, 8, math.max(20, nWidth - 44), 23); end;
        tInput.activate = function(nPart)
            if (nPart and nPart > 0) then c.commitText(); c.setValue(c.Value + (nPart == 1 and c.Step or -c.Step), true); end
        end;
        tInput.draw = function(oDC, nWidth, nHeight, sState, oBrush)

            local oPen = wx.wxPen(wx.wxColour(68, 78, 89), 1, wx.wxPENSTYLE_SOLID);
            oDC:SetPen(oPen); oDC:SetBrush(oBrush); oDC:DrawRectangle(1, 1, nWidth - 2, nHeight - 2); oPen:delete();
            for nPart, sDirection in ipairs({"Up", "Down"}) do
                local sPartState = not tInput.enabled() and "Disabled" or c.Pressed and tInput.PressedPart == nPart and tInput.HoverPart == nPart and "Pressed"
                    or c.Hover and tInput.HoverPart == nPart and "Hover" or "Normal";
                tInput.drawPart(oDC, "Spinner " .. sDirection .. " " .. sPartState, nWidth - 26, nPart == 1 and 2 or 20);
            end

        end;
        oText:Connect(wx.wxEVT_COMMAND_TEXT_ENTER, function() c.commitText(); end);
        oText:Connect(wx.wxEVT_KILL_FOCUS, function(oEvent) c.commitText(); oEvent:Skip(); end);
        oText:Connect(wx.wxEVT_KEY_DOWN, function(oEvent) if (not c.handleKey("down", oEvent:GetKeyCode())) then oEvent:Skip(); end end);
        c.setValue(tOptions.Value);
    end);
end
return Spinner;