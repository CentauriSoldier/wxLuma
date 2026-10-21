local _wx          = require("wx");
local _Surface     = require("UI.Core.ControlSurface");
local _Numeric     = require("UI.Core.ControlNumeric");
local _Scrollbar   = require("UI.Widgets.Scrollbar");
local _RowRenderer = require("UI.Core.ListRowRenderer");
local _Events      = require("UI.Core.ControlEvents");
local List         = {};

--[[!
@fqxn wxLuma.UI.List.create
@desc Creates a single-selection list backed by actual storage and a public
    decoy object. Only visible, invalidated rows draw; the shared surface owns
    input and native lifetime handling.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Items, optional Value, RowHeight, Enabled,
    OnChange, OnActivate and OnCancel. Columns optionally defines typed row
    fields using Key, Type (image/text/number/boolean), Width or flexible Weight,
    Align and Format. Column definitions are fixed; row/cell data is mutable.
@param string|nil sKind Internal shared-engine identity used by ListEx.
@ret table oList The list object. Value is a one-based index, or zero for none.
!]]
function List.create(oParent, tOptions, sKind)
    -- ListEx shares this engine and receives its own single proxy identity.
    assert(sKind == nil or sKind == "ListEx", "Invalid shared list identity.");
    local tRenderer = tOptions.Columns and _RowRenderer.create(tOptions.Columns, tOptions.Skin);
    local oList = _Surface.create(oParent, tOptions, sKind or "List");
    local nDown;
    local tEvents;

    -- Plain lists retain their string representation. Typed lists own shallow
    -- row copies and validate cells before changing any live component state.
    local function fCopyItem(vItem)
        if (tRenderer) then
            return tRenderer.copyItem(vItem);
        end

        assert(type(vItem) == "string", "Plain list items must be strings.");
        return vItem;
    end

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

            if (bNotify) then
                if (oList.OnChange) then
                    oList.OnChange(nValue, oList);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
                tEvents.emit("selectionChanged", {Value = nValue, OldValue = nOld});
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getText
    @desc Retrieves item text; typed rows use their first text column.
    @param number|nil nIndex The item index; omitted means the current selection.
    @ret string sText The selected text, or an empty string when unselected.
    !]]
    function oList.getText(nIndex)
        nIndex = nIndex or oList.Value;

        if (tRenderer) then
            return tRenderer.getText(oList.Items[nIndex], nIndex);
        end

        return oList.Items[nIndex] or "";
    end

    --[[!
    @fqxn wxLuma.UI.List.setItems
    @desc Validates/copies all items atomically, clamps selection and resets
        scrolling. Plain lists accept strings; configured lists accept records.
    @param table tItems The replacement item array.
    @param boolean|nil bNotify Whether item/selection changes notify; default silent.
    @ret table oList This list object.
    !]]
    function oList.setItems(tItems, bNotify)
        assert(type(tItems) == "table", "List Items must be an array.");
        local tCopy = {};

        for nIndex, vItem in ipairs(tItems) do
            tCopy[nIndex] = fCopyItem(vItem);
        end

        local nOldValue = oList.Value;

        oList.setHover(0);
        oList.Items = tCopy;
        oList.Value = math.min(oList.Value, #tCopy);
        oList.First = 1;

        if (tRenderer) then
            tRenderer.clear();
        end

        if (oList.onLayout) then
            oList.onLayout(oList.Control:GetClientSizeWH());
        end

        oList.refresh();

        if (bNotify) then
            if (nOldValue ~= oList.Value) then
                if (oList.OnChange) then
                    oList.OnChange(oList.Value, oList);
                end

                tEvents.emit("valueChanged", {Value = oList.Value, OldValue = nOldValue});
                tEvents.emit("selectionChanged", {Value = oList.Value, OldValue = nOldValue});
            end

            tEvents.emit("itemsChanged", {Count = #tCopy});
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getColumns
    @desc Returns column-definition snapshots, or nil for a plain string list.
        Definitions are fixed for this instance; mutate row/cell data instead.
    @ret table|nil tColumns Independent column definitions.
    !]]
    function oList.getColumns()
        return tRenderer and tRenderer.getColumns() or nil;
    end

    --[[!
    @fqxn wxLuma.UI.List.getItem
    @desc Returns one item snapshot, or nil when absent. Configured rows are
        shallow copies; application-owned nested metadata retains its identity.
    @param number nIndex The one-based item index.
    @ret string|table|nil vItem The string or row snapshot.
    !]]
    function oList.getItem(nIndex)
        local vItem = oList.Items[nIndex];
        return vItem ~= nil and fCopyItem(vItem) or nil;
    end

    --[[!
    @fqxn wxLuma.UI.List.setItem
    @desc Atomically replaces one item without changing selection or scroll.
        Equal values are no-ops; changed visible rows alone are invalidated.
    @param number nIndex The existing one-based row index.
    @param string|table vItem The replacement item.
    @param boolean|nil bNotify Whether to emit itemChanged; default silent.
    @ret table oList This list object.
    !]]
    function oList.setItem(nIndex, vItem, bNotify)
        assert(not oList.Disposed and _Numeric.finite(nIndex) and nIndex % 1 == 0
            and oList.Items[nIndex] ~= nil, "Invalid list item index.");
        local vCopy = fCopyItem(vItem);
        local vOld = oList.Items[nIndex];
        local bEqual = vOld == vCopy;

        if (type(vOld) == "table" and type(vCopy) == "table") then
            bEqual = true;

            for vKey, vValue in pairs(vOld) do
                if (vCopy[vKey] ~= vValue) then
                    bEqual = false;
                    break;
                end
            end

            if (bEqual) then
                for vKey, vValue in pairs(vCopy) do
                    if (vOld[vKey] ~= vValue) then
                        bEqual = false;
                        break;
                    end
                end
            end
        end

        if (not bEqual) then
            oList.Items[nIndex] = vCopy;
            fRefreshRow(nIndex);

            if (bNotify) then
                tEvents.emit("itemChanged", {Index = nIndex, Item = oList.getItem(nIndex)});
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.getCell
    @desc Reads typed cell data by one-based row/column index. A plain string
        list has one text column. Nil is a blank configured cell.
    @param number nIndex The existing row index.
    @param number nColumn The column index.
    @ret any vValue The cell's typed value.
    !]]
    function oList.getCell(nIndex, nColumn)
        assert(_Numeric.finite(nIndex) and nIndex % 1 == 0 and oList.Items[nIndex] ~= nil,
            "Invalid list item index.");

        if (tRenderer) then
            return oList.Items[nIndex][tRenderer.getColumnKey(nColumn)];
        end

        assert(nColumn == 1, "Plain lists have one column.");
        return oList.Items[nIndex];
    end

    --[[!
    @fqxn wxLuma.UI.List.setCell
    @desc Changes one cell independently while preserving the remaining row,
        selection and scroll. Validates the declared type before any mutation.
    @param number nIndex The existing one-based row index.
    @param number nColumn The one-based column index.
    @param any vValue The typed value, or nil for a blank configured cell.
    @param boolean|nil bNotify Whether to emit cellChanged/itemChanged.
    @ret table oList This list object.
    !]]
    function oList.setCell(nIndex, nColumn, vValue, bNotify)
        assert(not oList.Disposed, "Cannot change a disposed list.");
        local vOld = oList.getCell(nIndex, nColumn);

        if (vOld ~= vValue) then
            local vItem = oList.getItem(nIndex);

            if (tRenderer) then
                vItem[tRenderer.getColumnKey(nColumn)] = vValue;
            else
                vItem = vValue;
            end

            oList.setItem(nIndex, vItem, false);

            if (bNotify) then
                tEvents.emit("cellChanged", {
                    Index = nIndex, Column = nColumn, Value = vValue, OldValue = vOld
                });
                tEvents.emit("itemChanged", {Index = nIndex, Item = oList.getItem(nIndex)});
            end
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.addItem
    @desc Appends a validated item, preserving the selected index and scroll.
    @param string|table vItem The appended item.
    @param boolean|nil bNotify Whether to emit itemAdded.
    @ret table oList This list object.
    !]]
    function oList.addItem(vItem, bNotify)
        assert(not oList.Disposed, "Cannot append to a disposed list.");
        local vCopy = fCopyItem(vItem);
        oList.Items[#oList.Items + 1] = vCopy;
        oList.onLayout(oList.Control:GetClientSizeWH());
        fRefreshRow(#oList.Items);

        if (bNotify) then
            tEvents.emit("itemAdded", {Index = #oList.Items});
        end

        return oList;
    end

    --[[!
    @fqxn wxLuma.UI.List.removeItem
    @desc Removes one row. Selection follows the same logical remaining item by
        shifting its index; removing the selected row clears selection to zero.
    @param number nIndex The existing one-based index.
    @param boolean|nil bNotify Whether removal/selection changes notify.
    @ret table oList This list object.
    !]]
    function oList.removeItem(nIndex, bNotify)
        assert(not oList.Disposed and _Numeric.finite(nIndex) and nIndex % 1 == 0
            and oList.Items[nIndex] ~= nil, "Invalid list item index.");
        local nOld = oList.Value;
        table.remove(oList.Items, nIndex);

        if (nOld == nIndex) then
            oList.Value = 0;
        elseif (nOld > nIndex) then
            oList.Value = nOld - 1;
        end

        oList.onLayout(oList.Control:GetClientSizeWH());
        oList.refresh();

        if (bNotify) then
            if (nOld ~= oList.Value) then
                if (oList.OnChange) then
                    oList.OnChange(oList.Value, oList);
                end

                tEvents.emit("valueChanged", {Value = oList.Value, OldValue = nOld});
                tEvents.emit("selectionChanged", {Value = oList.Value, OldValue = nOld});
            end

            tEvents.emit("itemRemoved", {Index = nIndex});
        end

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

        if (tRenderer) then
            tRenderer.clear();
        end
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

            tEvents.emit("itemActivated", {Index = nIndex});
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
            if (oList.Value > 0) then
                if (tOptions.OnActivate) then
                    tOptions.OnActivate(oList.Value, oList);
                end

                tEvents.emit("itemActivated", {Index = oList.Value});
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

                if (oList.getText(nIndex):sub(1, 1):lower() == sChar) then
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

            if (tRenderer) then
                tRenderer.draw(oDC, oList.Items[nIndex], nIndex, 4, nY,
                    math.max(1, nWidth - 30), oList.RowHeight, oList.isEnabled());
            else
                oList.Skin.text(oDC, oList.Items[nIndex], 10,
                    nY + (oList.RowHeight - 18) / 2, oList.isEnabled());
            end
        end

        oDC:DestroyClippingRegion();
    end;

    tEvents = _Events.attach(oList, nil, {
        "selectionChanged", "itemsChanged", "itemAdded", "itemRemoved",
        "itemChanged", "cellChanged", "itemActivated"
    });
    oList.setItems(tOptions.Items);
    oList.setValue(tOptions.Value or 0);
    oList.setEnabled(tOptions.Enabled ~= false);
    return oList;
end

return List;
