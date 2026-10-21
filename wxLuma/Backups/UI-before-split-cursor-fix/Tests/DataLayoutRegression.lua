--[[!
@fqxn wxLuma.Tests.DataLayoutRegression
@desc Native regression checks for hierarchy/row identity, mutations, selection,
    sorting, splitter constraints/capture, semantic events and workbench examples.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path  = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.DataLayoutRegression.check
@desc Counts passing assertions and reports behavior on failure.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.DataLayoutRegression.mouse
@desc Dispatches a native event with fixture coordinates through actual handlers.
!]]
local function mouse(oTarget, nType, nX, nY)
    local jEvent = _wx.wxMouseEvent(nType);
    jEvent.GetX = function()
        return nX;
    end;
    jEvent.GetY = function()
        return nY;
    end;
    jEvent:SetEventObject(oTarget);
    jEvent:SetId(oTarget:GetId());
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.DataLayoutRegression.key
@desc Supplies the read-only key code at the wxLua callback boundary while using
    the native event handler chain. This is not hardware keyboard simulation.
!]]
local function key(oTarget, nCode)
    local jEvent = _wx.wxKeyEvent(_wx.wxEVT_KEY_DOWN);
    jEvent.GetKeyCode = function()
        return nCode;
    end;
    jEvent:SetEventObject(oTarget);
    jEvent:SetId(oTarget:GetId());
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.DataLayoutRegression.run
@desc Runs visible native controls and verifies ownership/disposal before testing
    the workbench's data and layout categories.
!]]
local function run()
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma data/layout checks",
        _wx.wxDefaultPosition, _wx.wxSize(1100, 800));
    local oSkin = _Controls.loadSkin();
    local nTreeChanges, nTableChanges, nSplitChanges = 0, 0, 0;
    local oTree = _Controls.tree(oFrame, {
        Skin = oSkin,
        Items = {{Id = "root", Text = "Same caption", Children = {
            {Id = "a", Text = "Same caption"}, {Id = "b", Text = "Same caption"}
        }}},
        OnChange = function()
            nTreeChanges = nTreeChanges + 1;
        end
    });
    local tInput = {
        {Id = "z", Cells = {"Zulu", "2"}},
        {Id = "a", Cells = {"Alpha", "1"}},
        {Id = "b", Cells = {"Alpha", "3"}}
    };
    local oTable = _Controls.table(oFrame, {
        Skin = oSkin, Columns = {{Text = "Name"}, {Text = "Count"}}, Items = tInput,
        OnChange = function()
            nTableChanges = nTableChanges + 1;
        end
    });
    local oSplit = _Controls.splitContainer(oFrame, {
        Skin = oSkin, Value = 0.5, MinFirst = 80, MinSecond = 100,
        OnChange = function()
            nSplitChanges = nSplitChanges + 1;
        end
    });
    local nChildActions = 0;
    local oChild = _Controls.button(oSplit.Second, {
        Skin = oSkin, Text = "Pane action", OnClick = function()
            nChildActions = nChildActions + 1;
        end
    });
    oTree.layout(10, 10, 320, 360);
    oTable.layout(350, 10, 700, 360);
    oSplit.layout(10, 390, 1000, 300);
    oChild.layout(10, 10, 160, 40);
    oFrame:Show(true);
    _wx.wxYield();

    for _, oComponent in ipairs({oTree, oTable, oSplit}) do
        check(next(oComponent) == nil and getmetatable(oComponent) == "wxLuma.UI."..oComponent.Kind,
            "Actual/decoy/metatable identity: "..oComponent.Kind);
        check(oComponent.on("rightClick", function() end) == oComponent, "Standard event API.");
    end

    check(#oTree.getChildren() == 1 and #oTree.getChildren("root") == 2, "Tree hierarchy order.");
    oTree.setValue("a");
    check(nTreeChanges == 0 and oTree.getValue() == "a", "Tree silent setter.");
    oTree.setValue("b", true);
    oTree.setValue("b", true);
    check(nTreeChanges == 1 and oTree.getValue() == "b", "Tree changed-only notification.");
    local tNode = oTree.getNode("b");
    tNode.Text = "external mutation";
    check(oTree.getNode("b").Text == "Same caption", "Tree snapshots are independent.");
    local nRenames = 0;
    oTree.on("itemChanged", function()
        nRenames = nRenames + 1;
    end);
    oTree.setNodeText("b", "Renamed", true);
    oTree.setNodeText("b", "Renamed", true);
    check(nRenames == 1 and oTree.getValue() == "b", "Rename preserves identity/selection.");
    oTree.setExpanded("root", false, true);
    local sCollapsedSelection = oTree.TreeControl:GetItemData(oTree.TreeControl:GetSelection()):GetData();
    check(oTree.getValue() == sCollapsedSelection, "Collapsing selected ancestors synchronizes native selection.");
    oTree.setValue("b");
    check(not pcall(oTree.addNode, nil, {Id = "b", Text = "Duplicate"}), "Reject duplicate tree IDs.");
    check(not pcall(oTree.addNode, "missing", {Id = "new", Text = "New"}), "Reject absent tree parent.");
    local nAdded, nRemoved, nExpanded, nCollapsed = 0, 0, 0, 0;
    oTree.on("itemAdded", function()
        nAdded = nAdded + 1;
    end).on("itemRemoved", function()
        nRemoved = nRemoved + 1;
    end).on("itemExpanded", function()
        nExpanded = nExpanded + 1;
    end).on("itemCollapsed", function()
        nCollapsed = nCollapsed + 1;
    end);
    oTree.addNode("a", {Id = "grandchild", Text = "Child"}, true);
    oTree.setExpanded("a", true, true);
    oTree.setExpanded("a", true, true);
    oTree.setExpanded("a", false, true);
    check(nAdded == 1 and nExpanded == 1 and nCollapsed == 1, "Tree expansion events once per transition.");
    local oNativeRoot = oTree.TreeControl:GetRootItem();
    local oNativeA = oTree.TreeControl:GetFirstChild(oTree.TreeControl:GetFirstChild(oNativeRoot));
    oTree.TreeControl:SelectItem(oNativeA);
    check(oTree.getValue() == "a", "Native tree selection resolves item data IDs.");
    oTree.TreeControl:Expand(oNativeA);
    oTree.TreeControl:Collapse(oNativeA);
    check(nExpanded == 2 and nCollapsed == 2, "Native expand/collapse emits semantic events.");
    local nTreeContext, nTreeActivated = 0, 0;
    oTree.on("itemRightClick", function(oSource, tEvent)
        if (tEvent.Id == "a") then
            nTreeContext = nTreeContext + 1;
        end
    end).on("itemActivated", function(oSource, tEvent)
        if (tEvent.Id == "a") then
            nTreeActivated = nTreeActivated + 1;
        end
    end);

    for _, nType in ipairs({_wx.wxEVT_COMMAND_TREE_ITEM_RIGHT_CLICK, _wx.wxEVT_COMMAND_TREE_ITEM_ACTIVATED}) do
        local jEvent = _wx.wxTreeEvent(nType, oTree.TreeControl:GetId());
        jEvent.GetItem = function()
            return oNativeA;
        end;
        jEvent:SetEventObject(oTree.TreeControl);
        oTree.TreeControl:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end

    check(nTreeContext == 1 and nTreeActivated == 1, "Tree context/activation events carry stable node IDs.");    oTree.setValue("grandchild");
    local nBeforeRemoval = nTreeChanges;
    oTree.removeNode("a", true);
    check(oTree.getNode("a") == nil and oTree.getNode("grandchild") == nil, "Subtree removal removes descendants.");
    check(oTree.getValue() == nil and nTreeChanges == nBeforeRemoval + 1 and nRemoved == 1,
        "Removing selected subtree clears once.");
    oTree.setValue("b");
    oTree.addNode(nil, {Id = "other", Text = "Other"});
    oTree.removeNode("other", true);
    check(oTree.getValue() == "b", "Unrelated removal preserves selected node.");
    check(not pcall(oTree.setValue, "missing"), "Reject unknown tree selection.");

    tInput[1].Cells[1] = "outside";
    check(oTable.getRow("z").Cells[1] == "Zulu", "Table owns copies of input rows.");
    oTable.setValue("z");
    check(nTableChanges == 0, "Table silent setter.");
    oTable.setValue("a", true);
    oTable.setValue("a", true);
    check(nTableChanges == 1, "Table changed-only notification.");
    local tRow = oTable.getRow("a");
    tRow.Cells[1] = "outside";
    check(oTable.getRow("a").Cells[1] == "Alpha", "Row snapshots cannot mutate cells.");
    oTable.sortBy(1, "ascending", true);
    local tSorted = oTable.getItems();
    check(tSorted[1].Id == "a" and tSorted[2].Id == "b" and tSorted[3].Id == "z", "Stable lexical sorting.");
    check(oTable.getValue() == "a" and nTableChanges == 1, "Sorting preserves selected ID without notifications.");
    local nSelected = oTable.TableControl:GetNextItem(-1, _wx.wxLIST_NEXT_ALL, _wx.wxLIST_STATE_SELECTED);
    check(nSelected == 0, "Native selected index follows sorting.");
    local nCells = 0;
    oTable.on("cellChanged", function()
        nCells = nCells + 1;
    end);
    oTable.setCell("a", 2, "42", true);
    oTable.setCell("a", 2, "42", true);
    check(nCells == 1 and oTable.getRow("a").Cells[2] == "42", "Cell update and changed-only notification.");
    local nBeforeInvalid = #oTable.getItems();
    check(not pcall(oTable.setItems, {{Id = "bad", Cells = {"short"}}}), "Reject malformed replacement rows.");
    check(#oTable.getItems() == nBeforeInvalid and oTable.getValue() == "a", "Invalid replacement is atomic.");
    check(not pcall(oTable.addRow, {Id = "a", Cells = {"Duplicate", "0"}}), "Reject duplicate row IDs.");
    oTable.addRow({Id = "new", Cells = {"New", "9"}}, true);
    check(oTable.getValue() == "a" and #oTable.getItems() == 4, "Append retains selection.");
    oTable.removeRow("z", true);
    check(oTable.getValue() == "a" and oTable.getRow("z") == nil, "Unrelated row removal preserves selection.");
    local nBeforeSelectedRemoval = nTableChanges;
    oTable.removeRow("a", true);
    check(oTable.getValue() == nil and nTableChanges == nBeforeSelectedRemoval + 1,
        "Selected row removal clears once.");
    oTable.setValue("b");
    oTable.setItems({{Id = "b", Cells = {"Kept", "7"}}, {Id = "x", Cells = {"Other", "8"}}}, true);
    check(oTable.getValue() == "b", "Replacement preserves surviving stable selection.");
    local nBeforeNativeSelection = nTableChanges;
    oTable.TableControl:SetItemState(1, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
    check(oTable.getValue() == "x", "Native Table selection updates the proxy.");
    check(nTableChanges == nBeforeNativeSelection + 1, "Native selection change notifies once.");
    local nBeforeClear = nTableChanges;
    oTable.TableControl:SetItemState(-1, 0, _wx.wxLIST_STATE_SELECTED);
    check(oTable.getValue() == nil, "Native clear is immediately readable.");
    local jIdle = _wx.wxIdleEvent();
    oTable.TableControl:GetEventHandler():ProcessEvent(jIdle);
    oTable.TableControl:GetEventHandler():ProcessEvent(jIdle);
    jIdle:delete();
    check(nTableChanges == nBeforeClear + 1, "Idle clear notification occurs once.");
    oTable.setValue("x");
    local nHeaders = 0;
    oTable.on("columnClicked", function()
        nHeaders = nHeaders + 1;
    end);
    local jColumn = _wx.wxListEvent(_wx.wxEVT_COMMAND_LIST_COL_CLICK, oTable.TableControl:GetId());
    jColumn.GetColumn = function()
        return 0;
    end;
    jColumn:SetEventObject(oTable.TableControl);
    oTable.TableControl:GetEventHandler():ProcessEvent(jColumn);
    jColumn:delete();
    check(nHeaders == 1 and oTable.getItems()[1].Id == "b", "Native header handler sorts cells.");

    local nItemContext, nColumnContext, nColumnResize = 0, 0, 0;
    oTable.on("itemRightClick", function(oSource, tEvent)
        if (tEvent.Id == "b") then
            nItemContext = nItemContext + 1;
        end
    end).on("columnRightClick", function(oSource, tEvent)
        if (tEvent.Column == 1) then
            nColumnContext = nColumnContext + 1;
        end
    end).on("columnResized", function(oSource, tEvent)
        if (tEvent.Column == 1 and tEvent.Width > 0) then
            nColumnResize = nColumnResize + 1;
        end
    end);

    for _, nType in ipairs({_wx.wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK,
        _wx.wxEVT_COMMAND_LIST_COL_RIGHT_CLICK, _wx.wxEVT_COMMAND_LIST_COL_END_DRAG}) do
        local jEvent = _wx.wxListEvent(nType, oTable.TableControl:GetId());
        jEvent.GetIndex = function()
            return 0;
        end;
        jEvent.GetColumn = function()
            return 0;
        end;
        jEvent:SetEventObject(oTable.TableControl);
        oTable.TableControl:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end

    check(nItemContext == 1 and nColumnContext == 1 and nColumnResize == 1,
        "Table context/column events include stable IDs, indices and widths.");
    -- Divider movement must change both native pane bounds coherently.
    check(oSplit.getSplitPosition() == 492, "Initial split uses available span.");
    oSplit.setValue(0.6);
    check(nSplitChanges == 0, "Split setter defaults silent.");
    oSplit.setValue(0.7, true);
    oSplit.setValue(0.7, true);
    check(nSplitChanges == 1, "Split changed-only notification.");
    key(oSplit.Control, _wx.WXK_HOME);
    check(oSplit.getSplitPosition() == 80, "Native Home respects first minimum.");
    key(oSplit.Control, _wx.WXK_END);
    check(oSplit.Second:GetSizeWH() == 100, "Native End respects second minimum.");
    oSplit.setValue(0.5);
    local nDividerX = oSplit.getSplitPosition() + 6;
    local nStartValue = oSplit.getValue();
    local nDragStart, nDragEnd, nCancelled = 0, 0, 0;
    oSplit.on("dragStarted", function()
        nDragStart = nDragStart + 1;
    end).on("dragEnded", function(oSource, tEvent)
        nDragEnd = nDragEnd + 1;

        if (tEvent.Cancelled) then
            nCancelled = nCancelled + 1;
        end
    end);
    mouse(oSplit.Control, _wx.wxEVT_LEFT_DOWN, nDividerX, 30);
    check(oSplit.Control:HasCapture() and oSplit.Control:HasFocus(), "Divider down captures/focuses input.");
    mouse(oSplit.Control, _wx.wxEVT_MOTION, nDividerX + 100, 30);
    check(oSplit.getValue() > nStartValue, "Native pointer motion moves divider.");
    mouse(oSplit.Control, _wx.wxEVT_LEFT_UP, nDividerX + 100, 30);
    check(not oSplit.Control:HasCapture() and nDragStart == 1 and nDragEnd == 1 and nCancelled == 0,
        "Completed drag releases capture and ends once.");
    nDividerX = oSplit.getSplitPosition() + 6;
    nStartValue = oSplit.getValue();
    mouse(oSplit.Control, _wx.wxEVT_LEFT_DOWN, nDividerX, 30);
    mouse(oSplit.Control, _wx.wxEVT_MOTION, nDividerX - 80, 30);
    key(oSplit.Control, _wx.WXK_ESCAPE);
    check(oSplit.getValue() == nStartValue and not oSplit.Control:HasCapture() and nCancelled == 1,
        "Escape restores pre-drag ratio and cancels capture.");
    oSplit.setOrientation("horizontal");
    key(oSplit.Control, _wx.WXK_HOME);
    local nFirstWidth, nFirstHeight = oSplit.First:GetSizeWH();
    check(nFirstWidth == 992 and nFirstHeight == 80, "Horizontal orientation uses pane heights.");
    oSplit.setOrientation("vertical");
    oSplit.setValue(0.5);
    oSplit.layout(10, 390, 120, 80);
    local nSmallFirst = oSplit.First:GetSizeWH();
    local nSmallSecond = oSplit.Second:GetSizeWH();
    check(nSmallFirst + nSmallSecond + 8 == 112, "Tiny layouts scale minima without negative panes.");
    oSplit.layout(10, 390, 1000, 300);
    oSplit.setValue(0.5);
    mouse(oChild.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    mouse(oChild.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(nChildActions == 1, "Split child controls remain interactive.");
    oSplit.setEnabled(false);
    check(not oChild.Control:IsEnabled(), "Disabled split disables child panes.");
    local nDisabledValue = oSplit.getValue();
    key(oSplit.Control, _wx.WXK_END);
    check(oSplit.getValue() == nDisabledValue, "Disabled split ignores native navigation.");
    oSplit.setEnabled(true);
    check(oChild.Control:IsEnabled(), "Re-enabled split restores child input.");
    check(not pcall(oSplit.setValue, 0 / 0), "Reject nonfinite ratios.");
    check(not pcall(oSplit.setOrientation, "diagonal"), "Reject invalid orientation.");

    -- Build enough real rows to exercise incremental append and native selection
    -- beyond the initial page; no timing thresholds depend on this workstation.
    local nExisting = #oTable.getItems();

    for nIndex = 1, 1000 do
        oTable.addRow({Id = "stress-"..nIndex, Cells = {string.format("Row %04d", nIndex), tostring(nIndex)}});
    end

    check(#oTable.getItems() == nExisting + 1000 and oTable.TableControl:GetItemCount() == nExisting + 1000,
        "Incremental native append handles 1,000 additional rows.");
    oTable.setValue("stress-1000", true);
    check(oTable.getValue() == "stress-1000", "Select/reveal a row beyond the first page.");
    oTable.sortBy(1, "descending");
    check(oTable.getValue() == "stress-1000", "Large sort preserves selection.");
    oTree.setEnabled(false);
    oTable.setEnabled(false);
    check(not oTree.TreeControl:IsEnabled() and not oTable.TableControl:IsEnabled(), "Native enabled state propagation.");
    oTree.setEnabled(true);
    oTable.setEnabled(true);
    local nDisposed = 0;

    for _, oComponent in ipairs({oTree, oTable, oSplit}) do
        oComponent.on("destroyed", function()
            nDisposed = nDisposed + 1;
        end);
        oComponent.destroy();
        oComponent.destroy();
    end

    check(nDisposed == 3, "All objects dispose exactly once.");
    oChild.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(6);
    tWorkbench.Layout();
    _wx.wxYield();
    check(tWorkbench.Widgets.Tree.Control:IsShownOnScreen() and tWorkbench.Widgets.Table.Control:IsShownOnScreen(),
        "Data category contains Tree and Table examples.");
    check(#tWorkbench.Widgets.Table.getItems() == 1000, "Workbench table contains 1,000 rows.");
    tWorkbench.Widgets.Tabs.setValue(5);
    _wx.wxYield();
    check(tWorkbench.Widgets.SplitContainer.Control:IsShownOnScreen(), "Containers category includes SplitContainer.");
    local oWorkbenchSplit = tWorkbench.Widgets.SplitContainer;
    mouse(oWorkbenchSplit.Control, _wx.wxEVT_LEFT_DOWN, oWorkbenchSplit.getSplitPosition() + 6, 30);
    mouse(oWorkbenchSplit.Control, _wx.wxEVT_MOTION, oWorkbenchSplit.getSplitPosition() + 40, 30);
    mouse(oWorkbenchSplit.Control, _wx.wxEVT_LEFT_UP, oWorkbenchSplit.getSplitPosition() + 6, 30);
    check(not oWorkbenchSplit.Control:HasCapture(), "Workbench drag releases capture.");
    local nBeforeEscape = oWorkbenchSplit.getValue();
    local nBeforeEscapePosition = oWorkbenchSplit.getSplitPosition();
    mouse(oWorkbenchSplit.Control, _wx.wxEVT_LEFT_DOWN, nBeforeEscapePosition + 6, 30);
    mouse(oWorkbenchSplit.Control, _wx.wxEVT_MOTION, nBeforeEscapePosition + 60, 30);
    local jEscape = _wx.wxKeyEvent(_wx.wxEVT_CHAR_HOOK);
    jEscape.GetKeyCode = function()
        return _wx.WXK_ESCAPE;
    end;
    jEscape:SetEventObject(oWorkbenchSplit.Control);
    jEscape:SetId(oWorkbenchSplit.Control:GetId());
    tWorkbench.Frame:GetEventHandler():ProcessEvent(jEscape);
    jEscape:delete();
    check(tWorkbench.Frame:IsShown() and not oWorkbenchSplit.Control:HasCapture()
        and oWorkbenchSplit.getValue() == nBeforeEscape,
        "Workbench Escape cancels drag without closing the frame.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Data/layout regression passed: ".._nChecks.." checks.");