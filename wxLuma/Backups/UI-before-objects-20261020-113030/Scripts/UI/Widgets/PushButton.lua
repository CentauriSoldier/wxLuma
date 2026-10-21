local ControlInput = require("UI.Core.ControlInput");
local PushButton = {};

--[[!
@fqxn OpenWar.UI.PushButton.create
@param wxWindow oParent Native parent.
@param table tOptions Skin, Text, optional Enabled/OnClick. Enter/Space activate on key release.
@ret table c Three-part skinned pushbutton with fixed caps and stretchable middle.
!]]

function PushButton.create(oParent, tOptions)
    return ControlInput.create(oParent, tOptions, "Button", function(c, tInput)
        local tSkin = tOptions.Skin; tInput.Toggle, tInput.Enter = true, true;
        tInput.activate = function() if (tOptions.OnClick) then tOptions.OnClick(c); end end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Button Left " .. sState, 0, (nHeight - 36) / 2);
            tInput.drawPart(oDC, "Button Middle " .. sState, 12, (nHeight - 36) / 2, nWidth - 24, 36);
            tInput.drawPart(oDC, "Button Right " .. sState, nWidth - 12, (nHeight - 36) / 2);
            oDC:SetFont(tSkin.Font); local nTextW, nTextH = oDC:GetTextExtent(c.Text);
            tSkin.text(oDC, c.Text, (nWidth - nTextW) / 2, (nHeight - nTextH) / 2 + (sState == "Pressed" and 1 or 0), tInput.enabled());

        end;
    end);
end
return PushButton;