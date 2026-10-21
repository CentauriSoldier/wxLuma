local wx = require("wx");
local ControlInput = require("UI.Core.ControlInput");
local Radio = {};

--[[!
@fqxn OpenWar.UI.Radio.group
@desc Holds an independent group. Selecting one member clears all others; clicking
      the selected member does not clear it. Arrow keys skip disabled members.
@ret table tGroup Group supplied in each radio's Group option; getValue returns selected Value or nil.
!]]

function Radio.group()
    local tGroup = {Members = {}, Selected = nil};
    function tGroup.getValue() return tGroup.Selected and tGroup.Selected.Value or nil; end
    function tGroup.select(tMember, bNotify)
        local bChanged = tGroup.Selected ~= tMember;
        tGroup.Selected = tMember;
        for _, tOther in ipairs(tGroup.Members) do
            tOther.Selected = tOther == tMember; tOther.Control:Refresh(false);
        end
        if (bChanged and bNotify and tMember.OnChange) then tMember.OnChange(tMember.Value, tMember); end
    end
    return tGroup;
end


--[[!
@fqxn OpenWar.UI.Radio.create
@param wxWindow oParent Native parent.
@param table tOptions Checkbox options plus required Group and unique Value. OnChange receives selected group Value.
@ret table c Radio component; user activation never deselects itself.
!]]

function Radio.create(oParent, tOptions)
    return ControlInput.create(oParent, tOptions, "Radio", function(c, tInput)
        local tSkin, tGroup = tOptions.Skin, tOptions.Group; tInput.Toggle = true;
        function c.getValue() return c.Selected; end
        function c.setValue(bValue, bNotify)
            assert(type(bValue) == "boolean", "Radio selection must be boolean.");
            if (bValue) then tGroup.select(c, bNotify); return c; end
            if (tGroup.Selected == c) then tGroup.Selected = nil; end
            local bChanged = c.getValue() ~= bValue; c.Selected = bValue;
            tInput.refresh(); if (bChanged and bNotify) then tInput.notify(); end; return c;
        end
        tInput.activate = function() tGroup.select(c, true); end;
        tInput.key = function(nKey)
            if (nKey ~= wx.WXK_LEFT and nKey ~= wx.WXK_RIGHT and nKey ~= wx.WXK_UP and nKey ~= wx.WXK_DOWN) then return false; end
            local nCurrent;
            for nIndex, tMember in ipairs(tGroup.Members) do if (tMember == c) then nCurrent = nIndex; end end
            local nDirection = (nKey == wx.WXK_LEFT or nKey == wx.WXK_UP) and -1 or 1;
            for nOffset = 1, #tGroup.Members do
                local tNext = tGroup.Members[(nCurrent - 1 + nOffset * nDirection) % #tGroup.Members + 1];
                if (tNext.Control:IsEnabled()) then tGroup.select(tNext, true); tNext.Control:SetFocus(); break; end
            end
            return true;
        end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Radio" .. (c.Selected and " On " or " Off ") .. sState, 0, math.floor((nHeight - 32) / 2));
            tSkin.text(oDC, c.Text, 40, math.floor((nHeight - 18) / 2), tInput.enabled());

        end;
        tInput.destroy = function()
            if (tGroup.Selected == c) then tGroup.Selected = nil; end
            for nIndex, tMember in ipairs(tGroup.Members) do if (tMember == c) then table.remove(tGroup.Members, nIndex); break; end end
        end;
        assert(tGroup and tGroup.Members and type(tGroup.select) == "function", "Radio requires a Controls.radioGroup().");
        assert(c.Value ~= nil, "Radio requires its group Value.");
        for _, tMember in ipairs(tGroup.Members) do assert(tMember.Value ~= c.Value, "Radio values must be unique within a group."); end
        tGroup.Members[#tGroup.Members + 1] = c;
        if (c.Selected) then tGroup.select(c, false); end
    end);
end
return Radio;