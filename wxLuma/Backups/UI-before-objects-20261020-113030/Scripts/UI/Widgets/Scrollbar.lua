local wx = require("wx");
local Scrollbar = {};
local surface = require("UI.Core.ControlSurface").create;
local frame = require("UI.Core.ControlDrawing").frame;
local finite = require("UI.Core.ControlNumeric").finite;

--[[!
@fqxn OpenWar.UI.Scrollbar.create
@param table tOptions Skin, Min, Max, Page, Value; optional Step (1), Vertical (true), Enabled, OnChange.
@desc Max is the last integer scroll offset; Page is the visible amount. Supports
      arrows, track paging, thumb dragging, wheel and Home/End/Page keys.
@ret table c Standard component plus setRange(Min,Max,Page) and getThumb.
!]]
function Scrollbar.create(oParent, tOptions)
    local c = surface(oParent, tOptions, "Scrollbar"); c.PointerRefresh = true; c.PointerStateRefresh = true; c.Vertical = tOptions.Vertical ~= false; c.Step = tOptions.Step or 1;
    assert(finite(c.Step) and c.Step > 0 and c.Step % 1 == 0, "Scrollbar Step must be a positive integer.");
    function c.setValue(nValue, bNotify)
        assert(finite(nValue), "Scrollbar value must be finite.");
        nValue = math.max(c.Min, math.min(c.Max, math.floor(nValue + 0.5)));
        local nOldAt, nOldSize; if (c.Value ~= nil) then nOldAt, nOldSize = c.getThumb(); end
        local bChanged = c.Value ~= nValue; c.Value = nValue;
        if (bChanged) then
            if (nOldAt) then
                local nAt, nSize = c.getThumb(); local nW, nH = c.Control:GetClientSizeWH();
                for _, tThumb in ipairs({{nOldAt, nOldSize}, {nAt, nSize}}) do
                    c.Control:RefreshRect(c.Vertical and wx.wxRect(1, tThumb[1] - 1, math.max(1, nW - 2), tThumb[2] + 2)
                        or wx.wxRect(tThumb[1] - 1, 1, tThumb[2] + 2, math.max(1, nH - 2)), false);
                end
            else c.refresh(); end
            if (bNotify and c.OnChange) then c.OnChange(nValue, c); end end; return c;
    end
    function c.setRange(nMin, nMax, nPage)
        assert(finite(nMin) and finite(nMax) and finite(nPage) and nMax >= nMin and nPage > 0
            and nMin % 1 == 0 and nMax % 1 == 0 and nPage % 1 == 0, "Invalid scrollbar range/page.");
        c.Min, c.Max, c.Page = nMin, nMax, nPage; c.setValue(c.Value or nMin); c.refresh(); return c;
    end
    function c.getThumb()
        local nW, nH = c.Control:GetClientSizeWH(); local nLength = c.Vertical and nH or nW;
        local nTrack = math.max(1, nLength - 36);
        local nThumb = math.min(nTrack, math.max(18, math.floor(nTrack * c.Page / (c.Max - c.Min + c.Page))));
        local nTravel = nTrack - nThumb;
        return 18 + (c.Max == c.Min and 0 or math.floor(nTravel * (c.Value - c.Min) / (c.Max - c.Min))), nThumb, nTravel;
    end
    local nDrag;
    c.pointer = function(sEvent, nX, nY)
        local nAt = c.Vertical and nY or nX;
        local nW, nH = c.Control:GetClientSizeWH(); local nLength = c.Vertical and nH or nW;
        local nStart, nThumb, nTravel = c.getThumb();
        if (sEvent == "down" and c.Hover) then
            nDrag = nil;
            if (nAt < 18) then c.setValue(c.Value - c.Step, true);
            elseif (nAt >= nLength - 18) then c.setValue(c.Value + c.Step, true);
            elseif (nAt >= nStart and nAt < nStart + nThumb) then nDrag = nAt - nStart;
            else c.setValue(c.Value + (nAt < nStart and -c.Page or c.Page), true); end
        elseif ((sEvent == "move" or sEvent == "up") and c.Pressed and nDrag and nTravel > 0) then
            c.setValue(c.Min + (nAt - 18 - nDrag) / nTravel * (c.Max - c.Min), true);
        end
        if (sEvent == "up" or sEvent == "cancel" or not c.Pressed) then nDrag = nil; end
    end;
    c.key = function(nKey)
        local tDelta = {[wx.WXK_LEFT] = -c.Step, [wx.WXK_UP] = -c.Step, [wx.WXK_RIGHT] = c.Step,
            [wx.WXK_DOWN] = c.Step, [wx.WXK_PAGEUP] = -c.Page, [wx.WXK_PAGEDOWN] = c.Page};
        if (tDelta[nKey]) then c.setValue(c.Value + tDelta[nKey], true);
        elseif (nKey == wx.WXK_HOME) then c.setValue(c.Min, true);
        elseif (nKey == wx.WXK_END) then c.setValue(c.Max, true); else return false; end; return true;
    end;
    c.wheel = function(nSteps) c.setValue(c.Value - nSteps * c.Step * 3, true); end;
    c.drawContent = function(oDC, nW, nH)
        local nAt, nThumb = c.getThumb(); local sState = c.getState();
        if (c.Vertical) then
            c.Skin.drawOpaque(oDC, "Spinner Up " .. sState, 0, 0, nW, 18);
            c.Skin.drawOpaque(oDC, "Spinner Down " .. sState, 0, nH - 18, nW, 18);
            frame(oDC, 2, nAt, nW - 4, nThumb, c.isEnabled(), c.Hover);
            c.Skin.text(oDC, "=", math.max(2, (nW - 10) / 2), nAt + (nThumb - 18) / 2, c.isEnabled());
        else
            frame(oDC, nAt, 2, nThumb, nH - 4, c.isEnabled(), c.Hover);
            c.Skin.text(oDC, "<", 3, 2, c.isEnabled()); c.Skin.text(oDC, ">", nW - 15, 2, c.isEnabled());
        end
    end;
    c.setRange(tOptions.Min, tOptions.Max, tOptions.Page); c.setValue(tOptions.Value); return c;
end

return Scrollbar;
