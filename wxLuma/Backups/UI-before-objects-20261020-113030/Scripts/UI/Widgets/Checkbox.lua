local ControlInput = require("UI.Core.ControlInput");
local Checkbox = {};

--[[!
@fqxn OpenWar.UI.Checkbox.create
@param wxWindow oParent Native parent.
@param table tOptions Skin, Text, optional Selected/Enabled/OnChange(value,component).
@ret table c Component with Control, getValue/setValue, setEnabled, layout, draw, getState, input adapters and destroy.
!]]

function Checkbox.create(oParent, tOptions)
    return ControlInput.create(oParent, tOptions, "Checkbox", function(c, tInput)
        local tSkin = tOptions.Skin; tInput.Toggle = true;
        function c.getValue() return c.Selected; end
        function c.setValue(bValue, bNotify)
            assert(type(bValue) == "boolean", "Checkbox selection must be boolean.");
            local bChanged = c.getValue() ~= bValue; c.Selected = bValue;
            tInput.refresh(); if (bChanged and bNotify) then tInput.notify(); end; return c;
        end
        tInput.activate = function() c.setValue(not c.Selected, true); end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Checkbox" .. (c.Selected and " On " or " Off ") .. sState, 0, math.floor((nHeight - 32) / 2));
            tSkin.text(oDC, c.Text, 40, math.floor((nHeight - 18) / 2), tInput.enabled());

        end;
    end);
end
return Checkbox;