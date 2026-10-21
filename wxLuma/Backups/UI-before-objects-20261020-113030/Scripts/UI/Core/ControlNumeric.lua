local wx = require("wx");
local ControlNumeric = {};

function ControlNumeric.finite(nValue)
    return type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge;
end

function ControlNumeric.configure(c, tInput, tOptions, bWhole)
    local finite = ControlNumeric.finite;
    assert(finite(tOptions.Min) and finite(tOptions.Max) and finite(tOptions.Step), "Numeric controls require finite Min, Max, Step.");
    assert(tOptions.Max > tOptions.Min and tOptions.Step > 0, "Invalid control range/step.");
    c.Min, c.Max, c.Step = tOptions.Min, tOptions.Max, tOptions.Step;
    assert(finite(tOptions.Value), "Numeric controls require Value.");
    if (bWhole) then assert(c.Min % 1 == 0 and c.Max % 1 == 0 and c.Step % 1 == 0 and tOptions.Value % 1 == 0, "Spinner requires whole-number values."); end
    function c.setValue(nValue, bNotify)
        if (bWhole) then assert(finite(nValue) and nValue % 1 == 0, "Spinner value must be a whole number."); end
        assert(finite(nValue), "Control value must be finite.");
        local nClamped = math.max(c.Min, math.min(c.Max, nValue));
        local nStep = math.floor((nClamped - c.Min) / c.Step + 0.5);
        nValue = math.max(c.Min, math.min(c.Max, c.Min + nStep * c.Step));
        local bChanged = c.getValue() ~= nValue; c.Value = nValue;
        if (tInput.TextControl) then tInput.TextControl:ChangeValue(tostring(c.Value)); end
        tInput.refresh(); if (bChanged and bNotify) then tInput.notify(); end; return c;
    end
    tInput.key = function(nKey)
        local nValue;
        if (nKey == wx.WXK_LEFT or nKey == wx.WXK_DOWN) then nValue = c.Value - c.Step;
        elseif (nKey == wx.WXK_RIGHT or nKey == wx.WXK_UP) then nValue = c.Value + c.Step;
        elseif (nKey == wx.WXK_HOME) then nValue = c.Min;
        elseif (nKey == wx.WXK_END) then nValue = c.Max;
        elseif (nKey == wx.WXK_PAGEUP) then nValue = c.Value + c.Step * 10;
        elseif (nKey == wx.WXK_PAGEDOWN) then nValue = c.Value - c.Step * 10; end
        if (nValue) then c.setValue(nValue, true); return true; end
        return false;
    end;
end
return ControlNumeric;
