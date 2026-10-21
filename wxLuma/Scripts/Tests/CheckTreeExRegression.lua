--[[!
@fqxn wxLuma.Tests.CheckTreeExRegression
@desc Verifies default-off checkboxes, independent selection, downward tree
    propagation, collapsed state retention, typed columns and native event paths.
!]]
APP_PATH = assert(arg[1], "Pass export root.");
package.path = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.CheckTreeExRegression.check
@desc Counts behavior assertions and identifies failed contracts.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.CheckTreeExRegression.click
@desc Routes native mouse callbacks using explicit coordinates, not OS automation.
!]]
local function click(oTarget, nX, nY)
    for _, nType in ipairs({_wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP}) do
        local jEvent = _wx.wxMouseEvent(nType);
        jEvent.GetX = function()
            return nX;
        end;
        jEvent.GetY = function()
            return nY;
        end;
        jEvent:SetId(oTarget:GetId());
        jEvent:SetEventObject(oTarget);
        oTarget:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end
end

--[[!
@fqxn wxLuma.Tests.CheckTreeExRegression.key
@desc Dispatches real key bindings with event-local key codes.
!]]
local function key(oTarget, nCode, bUp)
    local jEvent = _wx.wxKeyEvent(bUp and _wx.wxEVT_KEY_UP or _wx.wxEVT_KEY_DOWN);
    jEvent.GetKeyCode = function()
        return nCode;
    end;
    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.CheckTreeExRegression.run
@desc Exercises row/node mutation, events, input, skin rendering and workbench demos.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Checkbox/TreeEx regression",
        _wx.wxDefaultPosition, _wx.wxSize(900, 700));
    local oPanel = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local tColumns = {{Key = "Picture", Type = "image", Width = 48, Title = "Icon"},
        {Key = "Name", Type = "text", Weight = 2, Title = "Name"},
        {Key = "Class", Type = "text", Width = 100, Title = "Class"}};
    local nSelection, nCheck, nActivate = 0, 0, 0;
    local oList = _Controls.listEx(oPanel, {Skin = oSkin, Columns = tColumns, RowHeight = 32,
        Items = {{Id = "one", Name = "First", Class = "Ranger"},
            {Id = "two", Name = "Second", Class = "Captain"}, {Id = "three", Name = "Third", Class = "Wizard"}},
        Value = 2, OnChange = function()
            nSelection = nSelection + 1;
        end, OnActivate = function()
            nActivate = nActivate + 1;
        end});
    oList.layout(12, 12, 420, 180);
    oList.on("checkChanged", function(oSource, tEvent)
        check(oSource == oList and tEvent.Index >= 1 and tEvent.Checked ~= tEvent.OldChecked,
            "List check event identity and old/new states.");
        check(tEvent.Id == oList.getItem(tEvent.Index).Id, "Optional row Id included in check event.");
        nCheck = nCheck + 1;
    end);
    local oTree = _Controls.treeEx(oPanel, {Skin = oSkin, Columns = tColumns, HierarchyColumn = 2,
        Items = {{Id = "a", Name = "Army", Class = "Group", Children = {
            {Id = "b", Name = "Squad", Class = "Group", Children = {
                {Id = "c", Name = "Faramir", Class = "Ranger", Picture = APP_PATH.."/Images/UI/Menu/Command Sword.png"},
            }},
        }}, {Id = "d", Name = "Gandalf", Class = "Wizard"}}});
    oTree.layout(12, 220, 740, 370);
    oFrame:Show(true);
    _wx.wxYield();
    check(not oList.isCheckboxesEnabled() and not oTree.isCheckboxesEnabled(), "Checkboxes default off on both objects.");
    check(oTree.isCheckPropagationEnabled(), "Tree downward propagation defaults on.");
    check(not oTree.isMultiSelectEnabled() and type(oTree.getSelected()) == "table", "Tree selection defaults to single, always returns an array.");
    check(next(oTree) == nil and getmetatable(oTree) == "wxLuma.UI.TreeEx", "TreeEx actual/decoy identity.");
    oList.setCheckboxesEnabled(true, true);
    click(oList.Control, 18, 20);
    check(oList.isChecked(1) and oList.getValue() == 2 and nSelection == 0 and nActivate == 0,
        "Checkbox click changes only check membership, never selection or activation.");
    check(nCheck == 1, "One check event per effective click.");
    oList.setChecked(1, true, true);
    check(nCheck == 1, "Identical checks do not notify.");
    key(oList.Control, _wx.WXK_SPACE);
    key(oList.Control, _wx.WXK_SPACE);
    check(not oList.isChecked(1) and nCheck == 2, "Space toggles focused checkbox once despite key repeat.");
    key(oList.Control, _wx.WXK_SPACE, true);
    key(oList.Control, _wx.WXK_SPACE);
    key(oList.Control, _wx.WXK_SPACE, true);
    check(oList.isChecked(1) and oList.getValue() == 2, "Keyboard checkbox focus remains independent of selection.");
    oList.setMultiSelectEnabled(true);
    oList.handleKey("down", _wx.WXK_SPACE, {Command = true});
    check(oList.isChecked(1) and #oList.getSelected() == 2, "Ctrl/Cmd+Space still edits selection membership.");
    oList.setCheckedItems({1, 3});
    oList.removeItem(2);
    check(#oList.getChecked() == 2 and oList.isChecked(2) and oList.getItem(2).Id == "three",
        "Checked rows shift with their data after deletion.");
    oList.setItem(2, {Id = "three", Name = "Renamed", Class = "Wizard"});
    check(oList.isChecked(2), "Cell/row replacement preserves check state at that row.");
    oList.setCheckboxesEnabled(false);
    check(#oList.getChecked() == 2, "Hiding checkboxes preserves membership.");
    oList.setCheckboxesEnabled(true);
    check(not pcall(oList.setCheckedItems, {1, 99}), "Invalid bulk checks rejected atomically.");
    check(#oList.getChecked() == 2, "Failed bulk checks preserve state.");
    oList.setEnabled(false);
    click(oList.Control, 18, 20);
    check(oList.isChecked(1), "Disabled checkbox ignores native input.");
    oList.setEnabled(true);
    oList.setChecked(1, false);
    oList.handlePointer("down", 18, 20);
    oList.handlePointer("cancel", 18, 20);
    oList.handlePointer("up", 18, 20);
    check(not oList.isChecked(1), "Cancelled checkbox gesture cannot toggle.");

    local tEvents = {};
    oTree.on("checkChanged", function(oSource, tEvent)
        check(oSource == oTree and type(tEvent.Id) == "string" and tEvent.Checked ~= tEvent.OldChecked,
            "Tree check events use stable IDs and changed states.");
        if (tEvent.Id == "a" and oTree.isCheckPropagationEnabled() and oTree.getNode("c")) then
            check(oTree.isChecked("b") == tEvent.Checked and oTree.isChecked("c") == tEvent.Checked,
                "All cascade states are installed before the first parent notification.");
        end
        tEvents[#tEvents + 1] = tEvent.Id;
    end);
    oTree.setValue("d");
    local nRebuilt = 0;
    local fSetRows = oTree.Rows.setItems;
    oTree.Rows.setItems = function(...)
        nRebuilt = nRebuilt + 1;
        return fSetRows(...);
    end;
    oTree.setValue("d");
    check(nRebuilt == 0, "Repeated visible selection does not rebuild hierarchy or clear thumbnail caches.");
    oTree.setCheckboxesEnabled(true);
    click(oTree.Rows.Control, 80, 20);
    check(oTree.isChecked("a") and oTree.isChecked("b") and oTree.isChecked("c") and not oTree.isChecked("d"),
        "Clicking a collapsed parent checks every descendant by default.");
    check(#tEvents == 3 and table.concat(tEvents, ",") == "a,b,c", "Each cascaded effective change emits in tree order.");
    check(oTree.getValue() == "d" and #oTree.getVisible() == 2, "Cascade preserves selection and expansion.");
    oTree.setChecked("a", true, true);
    check(#tEvents == 3, "Unchanged cascade emits nothing.");
    key(oTree.Rows.Control, _wx.WXK_SPACE);
    key(oTree.Rows.Control, _wx.WXK_SPACE);
    check(#oTree.getChecked() == 0 and #tEvents == 6 and oTree.getValue() == "d",
        "Native TreeEx Space cascades once under repeat and preserves selection.");
    key(oTree.Rows.Control, _wx.WXK_SPACE, true);
    key(oTree.Rows.Control, _wx.WXK_SPACE);
    key(oTree.Rows.Control, _wx.WXK_SPACE, true);
    check(#oTree.getChecked() == 3 and #tEvents == 9, "Released TreeEx Space can cascade again.");

    oTree.setExpanded("a", true, true);
    oTree.setExpanded("b", true, true);
    check(#oTree.getVisible() == 4 and #oTree.getChecked() == 3, "Expanded descendants retain check states.");
    oTree.setChecked("a", false, true);
    check(#oTree.getChecked() == 0 and #tEvents == 12, "Unchecking parent unchecks the whole subtree.");
    oTree.setCheckPropagationEnabled(false, true);
    oTree.setChecked("a", true, true);
    check(oTree.isChecked("a") and not oTree.isChecked("b") and not oTree.isChecked("c"), "Runtime propagation opt-out changes only the addressed node.");
    oTree.setChecked("c", true);
    oTree.setExpanded("a", false);
    check(oTree.isChecked("c"), "Collapsed hidden node remains queryable and checked.");
    oTree.setCheckPropagationEnabled(true);
    check(not oTree.isChecked("b"), "Changing propagation policy does not retroactively change state.");
    oTree.setChecked("a", true, true);
    check(oTree.isChecked("b") and oTree.isChecked("c"), "Cascade repairs unchecked descendants even if parent was already checked.");
    oTree.setCheckedItems({"a"});
    check(#oTree.getChecked() == 3, "Bulk requested branch includes descendants by default.");
    oTree.setValue("c");
    check(#oTree.getVisible() == 4 and oTree.getValue() == "c", "Selecting a hidden node reveals ancestors.");
    oTree.setExpanded("a", false, true);
    check(oTree.getValue() == "a", "Collapsing selected descendant chooses its visible parent.");
    oTree.setMultiSelectEnabled(true);
    oTree.setSelected({"b", "d"}, true);
    check(#oTree.getSelected() == 2, "Tree supports multiple stable-ID selections.");
    oTree.setMultiSelectEnabled(false);
    check(#oTree.getSelected() == 1 and oTree.getValue() == "d", "Disabling multi-selection retains primary ID.");
    oTree.setCell("c", 3, "Captain", true);
    check(oTree.getCell("c", 3) == "Captain" and oTree.isChecked("c"), "Runtime typed cell edits retain check state.");
    check(not pcall(oTree.setCell, "c", 3, 100), "Typed cell mismatch rejected.");
    check(oTree.getCell("c", 3) == "Captain", "Invalid cell edit is atomic.");
    oTree.addNode("b", {Id = "e", Name = "New unit", Class = "Scout"}, true);
    check(oTree.getNode("e").Parent == "b" and not oTree.isChecked("e"), "New nodes start unchecked, regardless of existing parent checks.");
    oTree.setChecked("a", true);
    check(oTree.isChecked("e"), "Future parent toggle includes newly added descendants.");
    oTree.removeNode("b", true);
    check(oTree.getNode("b") == nil and oTree.getNode("c") == nil and oTree.getNode("e") == nil,
        "Subtree removal deletes descendants.");
    check(#oTree.getChecked() == 1 and oTree.getChecked()[1] == "a", "Removed subtree check identities are pruned.");
    local tCopy = oTree.getItems();
    tCopy[1].Name = "Outside change";
    check(oTree.getNode("a").Name == "Army", "Tree getters return independent descriptor structure.");
    check(not pcall(oTree.setItems, {{Id = "dup"}, {Id = "dup"}}), "Duplicate tree IDs rejected.");
    local tCycle = {};
    tCycle[1] = {Id = "cycle", Children = tCycle};
    check(not pcall(oTree.setItems, tCycle), "Cyclic tree rejected.");
    check(oTree.getNode("a") ~= nil, "Rejected tree data leaves live hierarchy intact.");
    local oIndependent = _Controls.treeEx(oPanel, {Skin = oSkin, CheckPropagation = false,
        Items = {{Id = "root", Children = {{Id = "child"}}}}, Checked = {"root"}});
    check(not oIndependent.isCheckPropagationEnabled() and oIndependent.isChecked("root")
        and not oIndependent.isChecked("child"), "Creation-time propagation opt-out works with initial checks.");
    oIndependent.destroy();

    -- A large expanded branch keeps one shared row surface and paints only the
    -- viewport. Cascades install all states with one repaint request.
    local tLargeChildren = {};
    for nIndex = 1, 10000 do
        tLargeChildren[nIndex] = {Id = "large"..nIndex, Name = "Unit "..nIndex};
    end
    local nFormatted = 0;
    local oLarge = _Controls.treeEx(oPanel, {Skin = oSkin, Checkboxes = true,
        Columns = {{Key = "Name", Type = "text", Format = function(sValue)
            nFormatted = nFormatted + 1;
            return sValue;
        end}}, Items = {{Id = "large-root", Name = "Large branch", Expanded = true, Children = tLargeChildren}}});
    oLarge.layout(12, 220, 500, 200);
    check(#oLarge.getVisible() == 10001, "Large expanded tree projects every node.");
    local nRefresh = 0;
    local fRefresh = oLarge.Rows.refresh;
    oLarge.Rows.refresh = function()
        nRefresh = nRefresh + 1;
        fRefresh();
    end;
    oLarge.setChecked("large-root", true);
    check(#oLarge.getChecked() == 10001 and nRefresh == 1, "Ten-thousand-descendant cascade batches repaint into one request.");
    local oLargeBitmap = _wx.wxBitmap(492, 164);
    local oLargeDC = _wx.wxMemoryDC();
    oLargeDC:SelectObject(oLargeBitmap);
    nFormatted = 0;
    oLarge.Rows.draw(oLargeDC, 492, 164);
    check(nFormatted <= oLarge.Rows.getVisibleCount(), "Only visible tree cells are formatted and painted.");
    oLargeDC:SelectObject(_wx.wxNullBitmap);
    oLargeDC:delete();
    oLargeBitmap:delete();
    oLarge.destroy();

    local oMarker = _wx.wxColour(210, 40, 170);
    local oMarkerBrush = _wx.wxBrush(oMarker);
    local oToken = _wx.wxBitmap(1, 1);
    local oTokenDC = _wx.wxMemoryDC();
    oTokenDC:SelectObject(oToken);
    oTokenDC:SetBackground(oMarkerBrush);
    oTokenDC:Clear();
    oTokenDC:SelectObject(_wx.wxNullBitmap);
    oTokenDC:delete();
    local tCustomSkin = {Font = oSkin.Font, getBitmap = function()
        return oToken;
    end, draw = function(oDC, sName, nX, nY, nWidth, nHeight)
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:SetBrush(oMarkerBrush);
        oDC:DrawRectangle(nX, nY, nWidth, nHeight);
    end};
    tCustomSkin.drawOpaque = tCustomSkin.draw;
    for _, fFactory in ipairs({_Controls.listEx, _Controls.treeEx}) do
        local oCustom = fFactory(oPanel, {Skin = tCustomSkin, Checkboxes = true,
            Columns = {{Key = "Name", Type = "text"}}, Items = {{Id = "custom", Name = "Custom"}}});
        oCustom.layout(12, 600, 300, 80);
        local oSample = _wx.wxBitmap(300, 80);
        local oSampleDC = _wx.wxMemoryDC();
        oSampleDC:SelectObject(oSample);
        oCustom.draw(oSampleDC, 300, 80);
        oSampleDC:SelectObject(_wx.wxNullBitmap);
        local oSampleImage = oSample:ConvertToImage();
        check(oCustom.Skin == tCustomSkin and oSampleImage:GetRed(1, 1) == 210
            and oSampleImage:GetGreen(1, 1) == 40 and oSampleImage:GetBlue(1, 1) == 170,
            "Per-object skin supplies list/tree surface and palette colors.");
        oSampleImage:delete();
        oSampleDC:delete();
        oSample:delete();
        oCustom.destroy();
    end
    oMarkerBrush:delete();
    oMarker:delete();
    oToken:delete();

    -- The hierarchy prefix indents only its configured column, preserving the
    -- image and class column starts across all depths.
    oTree.setItems({{Id = "p", Name = "Parent", Class = "Group", Expanded = true, Children = {
        {Id = "q", Name = "Child", Class = "Unit", Expanded = true,
            Picture = APP_PATH.."/Images/UI/Menu/Command Sword.png", Children = {
                {Id = "r", Name = "Grandchild", Class = "Ranger",
                    Picture = APP_PATH.."/Images/UI/Menu/Command Shield.png"},
            }},
    }}});
    oTree.setChecked("p", true);
    local tRootInsets = oTree.Rows.getRowInsets(1);
    local tChildInsets = oTree.Rows.getRowInsets(2);
    check(tChildInsets[2] > tRootInsets[2] and tChildInsets[1] == nil and tChildInsets[3] == nil,
        "Only hierarchy column content is indented.");
    -- Node images follow hierarchy indentation independently of image columns.
    local pNodeFixture = APP_PATH.."/Scripts/Tests/TreeExNodeImageFixture.png";
    local oSolid = _wx.wxImage(20, 20);
    oSolid:SetRGB(_wx.wxRect(0, 0, 20, 20), 239, 23, 61);
    check(oSolid:SaveFile(pNodeFixture, _wx.wxBITMAP_TYPE_PNG), "Save inline node-image fixture.");
    oSolid:delete();
    local nImageLoaded, nImageChanged = 0, 0;
    oTree.on("imageLoaded", function(oSource, tEvent)
        check(oSource == oTree and tEvent.Path == pNodeFixture, "Node image event identity/path.");
        nImageLoaded = nImageLoaded + 1;
    end);
    oTree.on("itemChanged", function()
        nImageChanged = nImageChanged + 1;
    end);
    local nBeforeIcon = oTree.Rows.getRowInsets(1)[2];
    oTree.setNodeImage("p", pNodeFixture, true);
    oTree.setNodeImage("q", pNodeFixture, true);
    check(oTree.Rows.getRowInsets(1)[2] == nBeforeIcon + 24, "Node icon reserves space immediately before its label.");
    check(oTree.getNode("q").Image == pNodeFixture and oTree.getCell("q", 1) ~= pNodeFixture,
        "Inline node image remains independent of ordinary image-column data.");
    oTree.setNodeImage("q", pNodeFixture, true);
    check(nImageLoaded == 2 and nImageChanged == 2, "Identical node image is a silent no-op.");
    local oIconBitmap = _wx.wxBitmap(732, 194);
    local oIconDC = _wx.wxMemoryDC();
    oIconDC:SelectObject(oIconBitmap);
    oTree.Rows.draw(oIconDC, 732, 194);
    oIconDC:SelectObject(_wx.wxNullBitmap);
    local oIconImage = oIconBitmap:ConvertToImage();
    local nRootImageX = 4 + 48 + 26 + 28;
    local nChildImageX = nRootImageX + 18;
    check(oIconImage:GetRed(nRootImageX + 10, 20) == 239
        and oIconImage:GetGreen(nRootImageX + 10, 20) == 23, "Root node icon paints beside the hierarchy label.");
    check(oIconImage:GetRed(nChildImageX + 10, 52) == 239
        and oIconImage:GetBlue(nChildImageX + 10, 52) == 61, "Child icon follows the node's indentation.");
    check(oIconImage:GetRed(24, 20) ~= 239, "Node icon does not jump into the far-left image column.");
    oIconImage:delete();
    oIconDC:delete();
    oIconBitmap:delete();
    local nCheckedBefore = #oTree.getChecked();
    click(oTree.Rows.Control, nRootImageX + 10, 20);
    check(oTree.getValue() == "p" and #oTree.getChecked() == nCheckedBefore,
        "Clicking the node image selects the row without toggling its checkbox.");
    oTree.setCheckboxesEnabled(false);
    check(oTree.Rows.getRowInsets(1)[2] == nBeforeIcon - 28 + 24,
        "Disabling checkboxes moves the image/label together without an empty checkbox slot.");
    oTree.setCheckboxesEnabled(true);
    oTree.setNodeImage("p", nil, true);
    check(oTree.getNode("p").Image == nil and oTree.Rows.getRowInsets(1)[2] == nBeforeIcon,
        "Clearing a node icon removes only its reserved space.");
    check(oTree.getValue() == "p" and #oTree.getChecked() == nCheckedBefore,
        "Node image updates preserve selection and check membership.");
    check(not pcall(oTree.setNodeImage, "q", APP_PATH.."/missing-node-icon.png", true), "Invalid node icon rejected.");
    check(oTree.getNode("q").Image == pNodeFixture, "Failed image replacement preserves the live node image.");
    oTree.off("imageLoaded");
    oTree.off("itemChanged");
    oTree.setNodeImage("q", nil);
    check(os.remove(pNodeFixture), "Remove temporary node-image fixture after releasing its cache.");
    oTree.setNodeImage("q", APP_PATH.."/Images/UI/Menu/Command Sword.png");
    oTree.setNodeImage("r", APP_PATH.."/Images/UI/Menu/Command Shield.png");
    local oBitmap = _wx.wxBitmap(840, 480);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oDC:SetBackground(oBrush);
    oDC:Clear();
    oDC:SetDeviceOrigin(12, 12);
    oList.draw(oDC, 420, 180);
    oDC:SetDeviceOrigin(12, 220);
    oTree.draw(oDC, 740, 230);
    oDC:SetDeviceOrigin(16, 252);
    oTree.Rows.draw(oDC, 732, 194);
    oDC:SetDeviceOrigin(0, 0);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    check(oImage:SaveFile(APP_PATH.."/Scripts/Tests/CheckTreeExPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save production check/tree preview.");
    oImage:delete();
    oDC:delete();
    oBitmap:delete();
    oBrush:delete();
    oList.destroy();
    oTree.destroy();
    oTree.destroy();
    check(oTree.Disposed, "Tree disposal idempotent.");
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(12);
    tWorkbench.Layout();
    _wx.wxYield();
    check(not tWorkbench.Widgets.CheckListEx.isCheckboxesEnabled() and not tWorkbench.Widgets.TreeEx.isCheckboxesEnabled(),
        "Workbench defaults checkbox presentation off.");
    click(tWorkbench.Widgets.CheckTreeToggle.Control, 10, 16);
    check(tWorkbench.Widgets.TreeEx.isCheckboxesEnabled(), "Workbench toggles checkbox presentation.");
    check(tWorkbench.Widgets.TreeEx.isCheckPropagationEnabled(), "Workbench cascade defaults on.");
    check(#tWorkbench.Widgets.TreeEx.getColumns() == 2 and tWorkbench.Widgets.TreeEx.getNode("faramir").Image ~= nil,
        "Workbench TreeEx uses inline node icons rather than a far-left Picture column.");
    click(tWorkbench.Widgets.TreeExPropagation.Control, 10, 16);
    check(not tWorkbench.Widgets.TreeEx.isCheckPropagationEnabled(), "Workbench exposes cascade opt-out.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
    collectgarbage("collect");
end

local bOK, sError = xpcall(run, debug.traceback);
if (not bOK) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end
print("Checkbox/TreeEx regression: ".._nChecks.." checks passed.");
