local _wx        = require("wx");
local _Surface   = require("UI.Core.ControlSurface");
local _Numeric   = require("UI.Core.ControlNumeric");
local _Scrollbar = require("UI.Widgets.Scrollbar");
local List       = {};

--[[!
@fqxn wxLuma.UI.List.create
@desc Creates a single-selection list backed by actual storage and a public
    decoy object. Only visible, invalidated rows draw; the shared surface owns
    input and native lifetime handling.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Items, optional Value, RowHeight, Enabled,
    OnChange, OnActivate and OnCancel.
@ret table oList The list object. Value is a one-based index, or zero for none.
!]]
function List.create(oParent, tOptions)
    local oList = _Surface.create(oParent, tOptions, "List");
    local nDown;

    -- The shared surface creates the single public proxy for this instance.
    oList.RowHeight        = tOptions.RowHeight or 28;
    oList.First            = 1;
    oList.Value            = 0;
    oList.HoverRow         = 0;
    oList.PointerRefresh   = true;
    oList.TrackPaintBounds = true;

    assert(_Numeric.finite(oList.RowHeight) and oList.RowHeight >= 20 and
        oList.RowHeight % 1 == 0, "Invalid list RowHeight.");

    --[[!
    @fqxn wxLuma.UI.List.getVisibleCount
    @desc Returns the number of complete rows available inside the frame.
    @ret number nCount At least one row, matching the original list policy.
    !]]
    function oList.getVisibleCount()
        local _, nHeight = oList.Control:GetClientSizeWH();
        return math.max(1, math.floor((nHeight - 8) / oList.RowHeight));
    end

    -- Invalidate only the affected visible row, preserving partial-paint behavior.

    --[[!
    @fqxn wxLuma.UI.List.fRefreshRow
    @desc Invalidates one visible row instead of requesting a full-list redraw.
    @param number nIndex The row index.
    !]]
    local function fRefreshRow(nIndex)
        if (oList.Disposed or nIndex < oList.First or
            nIndex >= oList.First + oList.getVisibleCount()) then
            return;
        end

        local nWidth = oList.Control:GetClientSizeWH();
        oList.Control:RefreshRect(_wx.wxRect(
            4,
            4 + (nIndex - oList.First) * oList.RowHeight,
            math.max(1, nWidth - 30),
            oList.RowHeight
        ), false);
    end

    --[[!
    @fqxn wxLuma.UI.List.setHover
    @desc Updates row hover and invalidates the old and new row rectangles.
    @param number nIndex The item index; zero clears hover.
    !]]
    function oList.setHover(nIndex)
        if (not oList.isEnabled() or nIndex < oList.First or
            nIndex >= oList.First + oList.getVisibleCount() or
            nIndex > #oList.Items) then
            nIndex = 0;
        end

        if (nIndex ~= oList.HoverRow) then
            local nOld = oList.HoverRow;
            oList.HoverRow = nIndex;
            fRefreshRow(nOld);
            fRefreshRow(nIndex);
        end
    end

    --[[!
    @fqxn wxLuma.UI.List.scrollTo
    @desc Clamps the first visible row and synchronizes the child scrollbar.
        Small visible scrolls reuse existing pixels; other scrolls repaint.
    @param number nFirst The requested first visible item.
    @ret table oList This list object.
    !]]
    function oList.scrollTo(nFirst)
        nFirst = math.max(1, math.min(
            math.max(1, #oList.Items - oList.getVisibleCount() + 1),
            math.floor(nFirst)
        ));

        if (nFirst == oList.First) then
            return oList;
        end

        oList.setHover(0);
        local nDelta = oList.First - nFirst;
        oList.First = nFirst;

        if (oList.Scrollbar) then
            oList.Scrollbar.setValue(oList.First - 1);
        end

        local nWidth = oList.Control:GetClientSizeWH();

        if (math.abs(nDelta) < oList.getVisibleCount() and
            oList.Control:IsShownOnScreen()) then
            oList.Control:ScrollWindow(0, nDelta * oList.RowHeight, _wx.wxRect(
                4, 4, math.max(1, nWidth - 30),
                oList.getVisibleCount() * oList.RowHeight
            ));
        else
            oList.refresh();
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.setValue
    @desc Changes selection, reveals the selected row, and optionally notifies.
    @param number nValue A valid one-based item index, or zero to clear selection.
    @param boolean bNotify Whether to invoke OnChange when selection changes.
    @ret table oList This list object.
    !]]
    function oList.setValue(nValue, bNotify)
        assert(_Numeric.finite(nValue) and nValue % 1 == 0 and
            nValue >= 0 and nValue <= #oList.Items, "Invalid list selection.");

        local nOld     = oList.Value;
        local bChanged = nOld ~= nValue;
        oList.Value = nValue;

        if (nValue > 0) then
            if (nValue < oList.First) then
                oList.scrollTo(nValue);
            elseif (nValue >= oList.First + oList.getVisibleCount()) then
                oList.scrollTo(nValue - oList.getVisibleCount() + 1);
            end
        end

        if (bChanged) then
            fRefreshRow(nOld);
            fRefreshRow(nValue);

            if (bNotify and oList.OnChange) then
                oList.OnChange(nValue, oList);
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getText
    @desc Retrieves the selected item's text.
    @ret string sText The selected text, or an empty string when unselected.
    !]]
    function oList.getText()
        return oList.Items[oList.Value] or "";
    end

    --[[!
    @fqxn wxLuma.UI.List.setItems
    @desc Copies the supplied strings, clamps selection and resets scrolling.
        Item replacement retains the original silent-notification behavior.
    @param table tItems An array of item strings.
    @ret table oList This list object.
    !]]
    function oList.setItems(tItems)
        assert(type(tItems) == "table", "List Items must be an array of strings.");
        local tCopy = {};

        for nIndex, sText in ipairs(tItems) do
            assert(type(sText) == "string", "List items must be strings.");
            tCopy[nIndex] = sText;
        end

        oList.setHover(0);
        oList.Items = tCopy;
        oList.Value = math.min(oList.Value, #tCopy);
        oList.First = 1;

        if (oList.onLayout) then
            oList.onLayout(oList.Control:GetClientSizeWH());
        end

        oList.refresh();
        return oList;
    end

    oList.Items     = {};
    oList.Scrollbar = _Scrollbar.create(oList.Control, {
        Skin     = oList.Skin,
        Min      = 0,
        Max      = 0,
        Page     = 1,
        Value    = 0,
        OnChange = function(nValue)
            oList.scrollTo(nValue + 1);
        end,
    });

    -- Keep the scrollbar range tied to the number of complete visible rows.
    oList.onLayout = function(nWidth, nHeight)
        oList.setHover(0);
        oList.Scrollbar.layout(math.max(1, nWidth - 23), 4, 20, math.max(40, nHeight - 8));
        oList.Scrollbar.setRange(
            0, math.max(0, #oList.Items - oList.getVisibleCount()),
            oList.getVisibleCount()
        );
        oList.scrollTo(oList.First);
        oList.Scrollbar.Control:Show(#oList.Items > oList.getVisibleCount());
    end;

    -- Propagate enabled state and clear transient interaction.
    oList.onEnable = function(bEnabled)
        oList.setHover(0);
        oList.Scrollbar.setEnabled(bEnabled);
    end;

    -- Dispose resources owned by this widget.
    oList.onDestroy = function()
        oList.Scrollbar.destroy();
    end;

    -- Preserve the original single-click activation policy for dropdown users.
    oList.pointer = function(sEvent, nX, nY)
        local nWidth   = oList.Control:GetClientSizeWH();
        local nIndex   = oList.First + math.floor((nY - 4) / oList.RowHeight);
        local bOverRow = sEvent ~= "leave" and sEvent ~= "cancel" and
        oList.Hover and nX >= 4 and nX < nWidth - 26 and nY >= 4;

        oList.setHover(bOverRow and nIndex or 0);

        if (sEvent == "down") then
            nDown = nIndex;
        elseif (sEvent == "up" and oList.Pressed and oList.Hover and
            nY >= 4 and nX < nWidth - 24 and nIndex == nDown and
            nIndex <= #oList.Items) then
            oList.setValue(nIndex, true);
            oList.cancel();

            if (tOptions.OnActivate) then
                tOptions.OnActivate(nIndex, oList);
            end
        end
    end;

    -- Keyboard selection uses the same setter and notification path as clicks.
    oList.key = function(nKey)
        oList.setHover(0);
        local nValue = oList.Value;

        if (nKey == _wx.WXK_UP) then
            nValue = math.max(1, nValue - 1);
        elseif (nKey == _wx.WXK_DOWN) then
            nValue = math.min(#oList.Items, nValue + 1);
        elseif (nKey == _wx.WXK_HOME) then
            nValue = 1;
        elseif (nKey == _wx.WXK_END) then
            nValue = #oList.Items;
        elseif (nKey == _wx.WXK_PAGEUP) then
            nValue = math.max(1, nValue - oList.getVisibleCount());
        elseif (nKey == _wx.WXK_PAGEDOWN) then
            nValue = math.min(#oList.Items, nValue + oList.getVisibleCount());
        elseif (nKey == _wx.WXK_RETURN or nKey == _wx.WXK_NUMPAD_ENTER) then
            if (oList.Value > 0 and tOptions.OnActivate) then
                tOptions.OnActivate(oList.Value, oList);
            end

            return true;
        elseif (nKey == _wx.WXK_ESCAPE and tOptions.OnCancel) then
            tOptions.OnCancel(oList);
            return true;
        else
            return false;
        end

        oList.setValue(#oList.Items == 0 and 0 or nValue, true);
        return true;
    end;

    -- Apply wheel movement to the value or scroll offset.
    oList.wheel = function(nSteps)
        oList.scrollTo(oList.First - nSteps * 3);
    end;

    -- Character search wraps after the selected item and matches its first byte.
    oList.Control:Connect(_wx.wxEVT_CHAR, function(jEvent)
        local nKey = jEvent:GetKeyCode();

        if (oList.isEnabled() and nKey >= 32 and nKey <= 126 and #oList.Items > 0) then
            local sChar = string.char(nKey):lower();

            for nOffset = 1, #oList.Items do
                local nIndex = (oList.Value + nOffset - 1) % #oList.Items + 1;

                if (oList.Items[nIndex]:sub(1, 1):lower() == sChar) then
                    oList.setValue(nIndex, true);
                    break;
                end
            end
        else
            jEvent:Skip();
        end
    end);

    -- Native paint bounds limit the Lua row loop as well as the DC clipping.
    oList.drawContent = function(oDC, nWidth, nHeight)
        oDC:SetClippingRegion(4, 4, math.max(1, nWidth - 30), math.max(1, nHeight - 8));

        local nFirst = oList.PaintTop and math.max(
            oList.First, oList.First + math.floor((oList.PaintTop - 4) / oList.RowHeight)
        ) or oList.First;
        local nLast = math.min(#oList.Items, oList.First + oList.getVisibleCount() - 1);

        if (oList.PaintBottom) then
            nLast = math.min(nLast, oList.First + math.floor((oList.PaintBottom - 5) / oList.RowHeight));
        end

        for nIndex = nFirst, nLast do
            local nY = 4 + (nIndex - oList.First) * oList.RowHeight;

            if (nIndex == oList.Value) then
                oDC:GradientFillLinear(_wx.wxRect(4, nY, nWidth - 30, oList.RowHeight),
                    oList.isEnabled() and _wx.wxColour(65, 82, 99) or _wx.wxColour(41, 46, 53),
                    _wx.wxColour(28, 36, 45), _wx.wxSOUTH);
            end

            if (nIndex == oList.HoverRow) then
                if (nIndex ~= oList.Value) then
                    oDC:GradientFillLinear(_wx.wxRect(4, nY, nWidth - 30, oList.RowHeight),
                        _wx.wxColour(43, 55, 67), _wx.wxColour(29, 38, 48), _wx.wxSOUTH);
                end

                local oPen = _wx.wxPen(_wx.wxColour(117, 145, 166), 1, _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen);
                oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
                oDC:DrawRectangle(4, nY, nWidth - 30, oList.RowHeight);
                oPen:delete();
            end

            if (nIndex == oList.CommittedValue) then
                local oPen = _wx.wxPen(_wx.wxColour(145, 175, 198), 2, _wx.wxPENSTYLE_SOLID);
                oDC:SetPen(oPen);
                oDC:DrawLine(6, nY + 5, 6, nY + oList.RowHeight - 5);
                oPen:delete();
            end

            oList.Skin.text(oDC, oList.Items[nIndex], 10,
                nY + (oList.RowHeight - 18) / 2, oList.isEnabled());
        end

        oDC:DestroyClippingRegion();
    end;

    oList.setItems(tOptions.Items);
    oList.setValue(tOptions.Value or 0);
    oList.setEnabled(tOptions.Enabled ~= false);
    return oList;
end

return List;
