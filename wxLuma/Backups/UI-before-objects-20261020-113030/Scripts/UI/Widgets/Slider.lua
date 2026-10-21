local ControlInput = require("UI.Core.ControlInput");
local ControlNumeric = require("UI.Core.ControlNumeric");
local Slider = {};

--[[!
@fqxn OpenWar.UI.Slider.create
@param wxWindow oParent Native parent.
@param table tOptions Skin, Min, Max, Step, Value; optional Vertical/Enabled/OnChange. Max must exceed Min.
@ret table c Slider. Values clamp/snap to nearest step from Min; vertical maximum is at the top. Arrows/Page/Home/End supported.
!]]

function Slider.create(oParent, tOptions)
    return ControlInput.create(oParent, tOptions, "Slider", function(c, tInput)
        local tSkin = tOptions.Skin;
        ControlNumeric.configure(c, tInput, tOptions, false);
        tInput.drag = function(nX, nY)
            local nW, nH = c.Control:GetClientSizeWH();
            local nFraction = c.Vertical and 1 - (nY - 16) / math.max(1, nH - 32)
                or (nX - 16) / math.max(1, nW - 32);
            c.setValue(c.Min + nFraction * (c.Max - c.Min), true);
        end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            local nFraction = (c.Value - c.Min) / (c.Max - c.Min);
            if (c.Vertical) then
                tInput.drawPart(oDC, "Slider Track " .. sState, (nWidth - 12) / 2, 16, 12, nHeight - 32, true);
                tInput.drawPart(oDC, "Slider Thumb " .. sState, (nWidth - 40) / 2,
                    16 + (1 - nFraction) * (nHeight - 32) - 14, 40, 28, true);
            else
                tInput.drawPart(oDC, "Slider Track " .. sState, 16, (nHeight - 12) / 2, nWidth - 32, 12);
                tInput.drawPart(oDC, "Slider Thumb " .. sState,
                    16 + nFraction * (nWidth - 32) - 14, (nHeight - 40) / 2);
            end

        end;
        c.setValue(tOptions.Value);
    end);
end
return Slider;