local wx = require("wx");
local TextField = {};
local surface = require("UI.Core.ControlSurface").create;

--[[!
@fqxn OpenWar.UI.TextField.create
@param table tOptions Skin; optional Value (string), Hint, MaxLength, ReadOnly, Enabled, OnChange, OnEnter.
@desc Native single-line editing, selection and clipboard inside a skinned frame.
      setValue does not notify by default; TextControl exposes native editing API.
!]]
function TextField.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Textfield");
    c.TextControl = wx.wxTextCtrl(c.Control, wx.wxID_ANY, tOptions.Value or "", wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxBORDER_NONE + wx.wxTE_PROCESS_ENTER);
    local oText = c.TextControl; oText:SetFont(c.Skin.Font);
    oText:SetBackgroundColour(wx.wxColour(24, 29, 36)); oText:SetForegroundColour(wx.wxColour(208, 218, 230));
    if (tOptions.Hint) then oText:SetHint(tOptions.Hint); end
    if (tOptions.MaxLength) then oText:SetMaxLength(tOptions.MaxLength); end; oText:SetEditable(tOptions.ReadOnly ~= true);
    function c.getValue() return oText:GetValue(); end
    function c.setValue(sValue, bNotify)
        assert(type(sValue) == "string", "Textfield value must be a string.");
        local bChanged = c.getValue() ~= sValue; oText:ChangeValue(sValue);
        if (bChanged and bNotify and c.OnChange) then c.OnChange(sValue, c); end; return c;
    end
    c.onLayout = function(nW, nH) oText:SetSize(9, math.max(5, math.floor((nH - 23) / 2)), math.max(1, nW - 18), 23); end;
    c.onEnable = function(bEnabled) oText:Enable(bEnabled); oText:Show(bEnabled); end;
    c.drawContent = function(oDC, nW, nH)
        if (not c.isEnabled()) then
            oDC:SetClippingRegion(9, 5, math.max(1, nW - 18), math.max(1, nH - 10));
            c.Skin.text(oDC, c.getValue(), 9, (nH - 18) / 2, false); oDC:DestroyClippingRegion();
        end
    end;
    oText:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, function() if (c.isEnabled() and c.OnChange) then c.OnChange(c.getValue(), c); end end);
    oText:Connect(wx.wxEVT_COMMAND_TEXT_ENTER, function() if (c.isEnabled() and tOptions.OnEnter) then tOptions.OnEnter(c.getValue(), c); end end);
    c.pointer = function(sEvent) if (sEvent == "down") then c.cancel(); oText:SetFocus(); end end;
    c.setEnabled(tOptions.Enabled ~= false); return c;
end

return TextField;
