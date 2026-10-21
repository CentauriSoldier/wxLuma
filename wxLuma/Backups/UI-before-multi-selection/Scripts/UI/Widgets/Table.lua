local _wx             = require("wx");
local _ControlSurface = require("UI.Core.ControlSurface");
local _ControlEvents  = require("UI.Core.ControlEvents");
local Table           = {};

--[[!
@fqxn wxLuma.UI.Table.create
@desc Creates a single-selection report table with native column headers and
    keyboard/accessibility behavior inside the shared frame. Stable string IDs
    survive sorting and replacement. Cells are strings; sorting is lexical.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Columns (Text/Width records), Items (Id/Cells/Value
    records), Value (selected ID or nil), Enabled and OnChange.
@ret table oComponent Public proxy with TableControl and standard surface/events API.
!]]
function Table.create(oParent, tOptions)
    assert(type(tOptions.Columns) == "table" and #tOptions.Columns > 0, "Table requires Columns.");
    local tColumns = {};

    for nIndex, tColumn in ipairs(tOptions.Columns) do
        assert(type(tColumn) == "table" and type(tColumn.Text) == "string", "Invalid table column.");
        local nWidth = tColumn.Width or 160;
        assert(type(nWidth) == "number" and nWidth > 0 and nWidth < math.huge and nWidth % 1 == 0,
            "Column Width must be a positive integer.");
        tColumns[nIndex] = {Text = tColumn.Text, Width = nWidth};
    end

    -- Own structural copies so caller edits cannot desynchronize native rows.
    local function fRows(tItems)
        assert(type(tItems) == "table", "Table Items must be an array.");
        local tRows, tIds = {}, {};

        for nIndex, tRow in ipairs(tItems) do
            assert(type(tRow) == "table" and type(tRow.Id) == "string" and tRow.Id ~= ""
                and not tIds[tRow.Id] and type(tRow.Cells) == "table", "Invalid/duplicate table row.");
            assert(#tRow.Cells == #tColumns, "Row cell count must match Columns.");
            local tCells = {};

            for nColumn = 1, #tColumns do
                assert(type(tRow.Cells[nColumn]) == "string", "Table cells must be strings.");
                tCells[nColumn] = tRow.Cells[nColumn];
            end

            tRows[nIndex] = {Id = tRow.Id, Cells = tCells, Value = tRow.Value};
            tIds[tRow.Id] = nIndex;
        end

        return tRows, tIds;
    end

    local tRows, tIndices = fRows(tOptions.Items or {});
    assert(tOptions.Value == nil or tIndices[tOptions.Value], "Unknown initial table selection.");
    local oComponent = _ControlSurface.create(oParent, tOptions, "Table");
    local oTable = _wx.wxListCtrl(oComponent.Control, _wx.wxID_ANY,
        _wx.wxDefaultPosition, _wx.wxDefaultSize,
        _wx.wxBORDER_NONE + _wx.wxLC_REPORT + _wx.wxLC_SINGLE_SEL);
    oComponent.TableControl = oTable;
    oTable:SetFont(oComponent.Skin.Font);
    oTable:SetBackgroundColour(_wx.wxColour(24, 29, 36));
    oTable:SetTextColour(_wx.wxColour(208, 218, 230));
    local bInternal = false;
    local bPendingDeselection = false;
    local nSortColumn, sSortDirection;
    local tEvents;

    for nIndex, tColumn in ipairs(tColumns) do
        oTable:InsertColumn(nIndex - 1, tColumn.Text, _wx.wxLIST_FORMAT_LEFT, tColumn.Width);
    end

    -- Keep one notification per stable selection change, including native input.
    local function fSelection(sId, bNotify)
        if (oComponent.Value ~= sId) then
            local sOldValue = oComponent.Value;
            oComponent.Value = sId;

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(sId, oComponent);
                end

                tEvents.emit("valueChanged", {Value = sId, OldValue = sOldValue});
                tEvents.emit("selectionChanged", {Value = sId, OldValue = sOldValue});
            end
        end
    end

    -- Rebuild native rows under event suppression. Preserve the selected stable
    -- ID and keep native focus/selection states synchronized after reordering.
    local function fRender()
        bPendingDeselection = false;
        bInternal = true;
        oTable:Freeze();
        oTable:DeleteAllItems();
        tIndices = {};

        for nIndex, tRow in ipairs(tRows) do
            tIndices[tRow.Id] = nIndex;
            oTable:InsertItem(nIndex - 1, tRow.Cells[1]);

            for nColumn = 2, #tColumns do
                oTable:SetItem(nIndex - 1, nColumn - 1, tRow.Cells[nColumn]);
            end
        end

        local nSelected = tIndices[oComponent.Value];

        if (nSelected) then
            oTable:SetItemState(nSelected - 1, _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED,
                _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED);
        end

        oTable:Thaw();
        bInternal = false;
    end

    --[[!
    @fqxn wxLuma.UI.Table.getRow
    @desc Returns a row snapshot with copied Cells. Application Value is not cloned.
    @param string sId The stable row ID.
    @ret table|nil tRow Id, Cells and Value, or nil for an absent row.
    !]]
    function oComponent.getRow(sId)
        local nIndex = tIndices[sId];

        if (nIndex) then
            local tRow = tRows[nIndex];
            local tCells = {};

            for nColumn, sText in ipairs(tRow.Cells) do
                tCells[nColumn] = sText;
            end

            return {Id = sId, Cells = tCells, Value = tRow.Value};
        end
    end

    --[[!
    @fqxn wxLuma.UI.Table.getItems
    @desc Returns ordered row snapshots; editing the result does not change rows.
    @ret table tItems Independent structural snapshots in display order.
    !]]
    function oComponent.getItems()
        local tItems = {};

        for nIndex, tRow in ipairs(tRows) do
            tItems[nIndex] = oComponent.getRow(tRow.Id);
        end

        return tItems;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setValue
    @desc Selects/reveals a stable row ID or clears with nil. Repeated values are
        no-ops and do not disturb native focus, scroll position or selection.
    @param string|nil sId The row ID or nil.
    @param boolean|nil bNotify Whether changed selection notifies; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(sId, bNotify)
        assert(sId == nil or tIndices[sId], "Unknown table selection.");

        if (oComponent.Disposed) then
            return oComponent;
        end

        bPendingDeselection = false;
        local nNativeSelected = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);
        local tNativeSelected = tRows[nNativeSelected + 1];
        local sNativeSelected = tNativeSelected and tNativeSelected.Id or nil;

        if (sId == oComponent.Value and sId == sNativeSelected) then
            return oComponent;
        end

        bInternal = true;
        oTable:SetItemState(-1, 0, _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED);

        if (sId) then
            oTable:SetItemState(tIndices[sId] - 1, _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED,
                _wx.wxLIST_STATE_SELECTED + _wx.wxLIST_STATE_FOCUSED);
            oTable:EnsureVisible(tIndices[sId] - 1);
        end

        bInternal = false;
        fSelection(sId, bNotify);
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setItems
    @desc Atomically validates/replaces rows. Keeps selection if its ID survives,
        clears it otherwise, and resets sort metadata to the supplied row order.
    @param table tItems The replacement Id/Cells/Value records.
    @param boolean|nil bNotify Whether rows/selection changes notify.
    @ret table oComponent This component.
    !]]
    function oComponent.setItems(tItems, bNotify)
        assert(not oComponent.Disposed, "Cannot replace rows on a disposed table.");
        local tReplacement, tReplacementIndices = fRows(tItems);
        local sSelected = oComponent.Value;
        tRows, tIndices = tReplacement, tReplacementIndices;
        nSortColumn, sSortDirection = nil, nil;
        fRender();

        if (sSelected and not tIndices[sSelected]) then
            fSelection(nil, bNotify);
        end

        if (bNotify) then
            tEvents.emit("itemsChanged", {Count = #tRows});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.addRow
    @desc Appends one validated row while retaining selection. Resets sort metadata.
    @param table tRow A unique Id, Cells and optional Value.
    @param boolean|nil bNotify Whether to emit itemAdded.
    @ret table oComponent This component.
    !]]
    function oComponent.addRow(tRow, bNotify)
        assert(not oComponent.Disposed, "Cannot add rows to a disposed table.");
        local tNew = fRows({tRow});
        assert(not tIndices[tNew[1].Id], "Duplicate table row ID.");
        local tAdded = tNew[1];
        tRows[#tRows + 1] = tAdded;
        tIndices[tAdded.Id] = #tRows;
        nSortColumn, sSortDirection = nil, nil;

        -- Append only the new native row; adding repeatedly must not rebuild
        -- every existing row or disturb the user's scroll/focus position.
        local nIndex = oTable:InsertItem(#tRows - 1, tAdded.Cells[1]);

        for nColumn = 2, #tColumns do
            oTable:SetItem(nIndex, nColumn - 1, tAdded.Cells[nColumn]);
        end

        if (bNotify) then
            tEvents.emit("itemAdded", {Id = tNew[1].Id});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.removeRow
    @desc Removes one row, clearing selection only if that row was selected.
    @param string sId The stable row ID.
    @param boolean|nil bNotify Whether removal/selection changes notify.
    @ret table oComponent This component.
    !]]
    function oComponent.removeRow(sId, bNotify)
        assert(not oComponent.Disposed and tIndices[sId], "Unknown/disposed table row.");
        local nIndex = tIndices[sId];
        bPendingDeselection = false;
        bInternal = true;
        oTable:DeleteItem(nIndex - 1);
        bInternal = false;
        table.remove(tRows, nIndex);
        tIndices[sId] = nil;

        for nRow = nIndex, #tRows do
            tIndices[tRows[nRow].Id] = nRow;
        end

        if (oComponent.Value == sId) then
            fSelection(nil, bNotify);
        end

        if (bNotify) then
            tEvents.emit("itemRemoved", {Id = sId});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.sortBy
    @desc Sorts cell text lexically, retaining selection by stable ID. Equal cells
        retain their previous display order. Header clicks toggle ascending/descending.
    @param number nColumn The one-based column index.
    @param string sDirection ascending or descending.
    @param boolean|nil bNotify Whether to emit sorted.
    @ret table oComponent This component.
    !]]
    function oComponent.sortBy(nColumn, sDirection, bNotify)
        assert(type(nColumn) == "number" and nColumn % 1 == 0 and tColumns[nColumn], "Invalid sort column.");
        assert(sDirection == "ascending" or sDirection == "descending", "Invalid sort direction.");

        if (oComponent.Disposed or (nSortColumn == nColumn and sSortDirection == sDirection)) then
            return oComponent;
        end

        local tOrder = {};

        for nIndex, tRow in ipairs(tRows) do
            tOrder[tRow.Id] = nIndex;
        end

        table.sort(tRows, function(tLeft, tRight)
            local sLeft, sRight = tLeft.Cells[nColumn], tRight.Cells[nColumn];

            if (sLeft == sRight) then
                return tOrder[tLeft.Id] < tOrder[tRight.Id];
            end

            if (sDirection == "ascending") then
                return sLeft < sRight;
            end

            return sLeft > sRight;
        end);
        nSortColumn, sSortDirection = nColumn, sDirection;
        fRender();

        if (bNotify) then
            tEvents.emit("sorted", {Column = nColumn, Direction = sDirection});
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Table.setCell
    @desc Changes one cell without rebuilding rows or changing selection. Clears
        sort metadata because edited cells may no longer match the prior order.
    @param string sId The stable row ID.
    @param number nColumn The one-based column index.
    @param string sText The replacement cell text.
    @param boolean|nil bNotify Whether to emit cellChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setCell(sId, nColumn, sText, bNotify)
        assert(not oComponent.Disposed and tIndices[sId], "Unknown/disposed table row.");
        assert(type(nColumn) == "number" and nColumn % 1 == 0 and tColumns[nColumn]
            and type(sText) == "string", "Invalid table cell.");
        local tRow = tRows[tIndices[sId]];

        if (tRow.Cells[nColumn] ~= sText) then
            local sOldValue = tRow.Cells[nColumn];
            tRow.Cells[nColumn] = sText;
            nSortColumn, sSortDirection = nil, nil;
            oTable:SetItem(tIndices[sId] - 1, nColumn - 1, sText);

            if (bNotify) then
                tEvents.emit("cellChanged", {Id = sId, Column = nColumn, Value = sText, OldValue = sOldValue});
            end
        end

        return oComponent;
    end
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_SELECTED, function(jEvent)
        if (not bInternal and not oComponent.Disposed) then
            bPendingDeselection = false;
            local tRow = tRows[jEvent:GetIndex() + 1];
            fSelection(tRow and tRow.Id or nil, true);
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_DESELECTED, function(jEvent)
        if (not bInternal and not oComponent.Disposed) then
            -- A row-to-row transition deselects first, then selects. Wait until
            -- idle before reporting a clear; the selected event cancels it.
            -- This uses core idle events rather than optional scheduling APIs.
            bPendingDeselection = true;
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_ACTIVATED, function(jEvent)
        if (not oComponent.Disposed) then
            local tRow = tRows[jEvent:GetIndex() + 1];
            tEvents.emit("itemActivated", {Id = tRow and tRow.Id or nil});
        end

        jEvent:Skip();
    end);
    oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_CLICK, function(jEvent)
        if (oComponent.isEnabled()) then
            local nColumn = jEvent:GetColumn() + 1;
            local sDirection = nSortColumn == nColumn and sSortDirection == "ascending"
                and "descending" or "ascending";
            oComponent.sortBy(nColumn, sDirection, true);
            tEvents.emit("columnClicked", {Column = nColumn});
        end

        jEvent:Skip();
    end);
    -- Item and header context gestures carry stable row IDs/column indices so
    -- applications do not need to infer an item from pointer coordinates.
    if (_wx.wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK, function(jEvent)
            if (not oComponent.Disposed) then
                local tRow = tRows[jEvent:GetIndex() + 1];
                tEvents.emit("itemRightClick", {Id = tRow and tRow.Id or nil});
            end

            jEvent:Skip();
        end);
    end

    if (_wx.wxEVT_COMMAND_LIST_COL_RIGHT_CLICK) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_RIGHT_CLICK, function(jEvent)
            if (not oComponent.Disposed) then
                tEvents.emit("columnRightClick", {Column = jEvent:GetColumn() + 1});
            end

            jEvent:Skip();
        end);
    end

    if (_wx.wxEVT_COMMAND_LIST_COL_END_DRAG) then
        oTable:Connect(_wx.wxEVT_COMMAND_LIST_COL_END_DRAG, function(jEvent)
            local nColumn = jEvent:GetColumn() + 1;

            if (not oComponent.Disposed and tColumns[nColumn]) then
                local nWidth = oTable:GetColumnWidth(nColumn - 1);
                tColumns[nColumn].Width = nWidth;
                tEvents.emit("columnResized", {Column = nColumn, Width = nWidth});
            end

            jEvent:Skip();
        end);
    end
    oTable:Connect(_wx.wxEVT_IDLE, function(jEvent)
        if (bPendingDeselection and not bInternal and not oComponent.Disposed) then
            bPendingDeselection = false;
            local nIndex = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);
            local tRow = tRows[nIndex + 1];
            fSelection(tRow and tRow.Id or nil, true);
        end

        jEvent:Skip();
    end);

    --[[!
    @fqxn wxLuma.UI.Table.getValue
    @desc Reads native selection immediately, including a clear awaiting its
        coalesced idle notification. A disposed table retains its last value.
    @ret string|nil sId The selected stable row ID or nil.
    !]]
    function oComponent.getValue()
        if (oComponent.Disposed) then
            return oComponent.Value;
        end

        local nIndex = oTable:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);
        local tRow = tRows[nIndex + 1];
        return tRow and tRow.Id or nil;
    end
    oComponent.onLayout = function(nWidth, nHeight)
        oTable:SetSize(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
    end;
    oComponent.onEnable = function(bEnabled)
        oTable:Enable(bEnabled);
    end;
    oComponent.pointer = function(sEvent)
        if (sEvent == "down") then
            oComponent.cancel();
            oTable:SetFocus();
        end
    end;
    oComponent.onDestroy = function()
        bPendingDeselection = false;
        tRows, tIndices = {}, {};
    end;
    tEvents = _ControlEvents.attach(oComponent, {oTable}, {
        "selectionChanged", "itemsChanged", "itemAdded", "itemRemoved", "cellChanged", "sorted", "columnClicked", "itemActivated",
        "itemRightClick", "columnRightClick", "columnResized"
    });
    fRender();
    oComponent.setValue(tOptions.Value);
    oComponent.onEnable(tOptions.Enabled ~= false);
    return oComponent;
end

return Table;