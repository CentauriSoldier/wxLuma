--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression
@desc Checks list modifier routing, native Table selection aggregation, shared
    public APIs, row mutations, events and workbench mode toggles.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx        = require("wx");
local _Controls  = require("wxLuma.Controls");
local _nChecks   = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.check
@desc Counts an assertion and names the failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.selected
@desc Checks both selected membership and required display ordering.
!]]
local function selected(oComponent, tExpected, sMessage)
    local tActual = oComponent.getSelected();
    check(type(tActual) == "table" and #tActual == #tExpected, sMessage.." count");

    for nIndex, vValue in ipairs(tExpected) do
        check(tActual[nIndex] == vValue, sMessage.." row "..nIndex);
    end
end

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.dispatch
@desc Delivers native callbacks with event-local accessors. These fixtures test
    adapter routing rather than hardware or native platform default processing.
!]]
local function dispatch(oTarget, nType, nX, nY, nKey, tModifiers)
    local jEvent = nKey and _wx.wxKeyEvent(nType) or _wx.wxMouseEvent(nType);
    tModifiers = tModifiers or {};
    jEvent.ShiftDown = function()
        return tModifiers.Shift == true;
    end;
    jEvent.ControlDown = function()
        return tModifiers.Control == true;
    end;
    jEvent.CmdDown = function()
        return tModifiers.Command == true;
    end;
    jEvent.MetaDown = function()
        return tModifiers.Meta == true;
    end;

    if (nKey) then
        jEvent.GetKeyCode = function()
            return nKey;
        end;
    else
        jEvent.GetX = function()
            return nX;
        end;
        jEvent.GetY = function()
            return nY;
        end;
    end

    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.click
@desc Clicks a custom list row or a supplied button coordinate through callbacks.
!]]
local function click(oComponent, nIndex, tModifiers)
    local nY = nIndex and (4 + (nIndex - oComponent.First) * oComponent.RowHeight + 10) or 10;
    dispatch(oComponent.Control, _wx.wxEVT_LEFT_DOWN, 10, nY, nil, tModifiers);
    dispatch(oComponent.Control, _wx.wxEVT_LEFT_UP, 10, nY, nil, tModifiers);
end

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.idle
@desc Flushes a native Table gesture once at the production idle boundary.
!]]
local function idle(oComponent)
    local jEvent = _wx.wxIdleEvent();
    oComponent.TableControl:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.MultiSelectionRegression.run
@desc Exercises both shared list identities and the stable-ID native Table.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Selection regression",
        _wx.wxDefaultPosition, _wx.wxSize(1000, 750));
    local tLists = {};
    local tPlain, tTyped, tRows = {}, {}, {};

    for nIndex = 1, 12 do
        tPlain[nIndex] = "Row "..nIndex;
        tTyped[nIndex] = {Text = "Row "..nIndex};
        tRows[nIndex] = {Id = "id-"..nIndex, Cells = {string.format("Row %02d", nIndex)}};
    end

    tLists[1] = _Controls.list(oFrame, {Skin = oSkin, Items = tPlain, Value = 2});
    tLists[2] = _Controls.listEx(oFrame, {Skin = oSkin, Columns = {{Key = "Text", Type = "text"}},
        Items = tTyped, RowHeight = 28, Value = 2});
    local oTable = _Controls.table(oFrame, {Skin = oSkin, Columns = {{Text = "Name"}}, Items = tRows, Value = "id-2"});
    tLists[1].layout(0, 0, 300, 450);
    tLists[2].layout(320, 0, 300, 450);
    oTable.layout(640, 0, 300, 450);
    oFrame:Show();
    _wx.wxYield();

    for _, oList in ipairs(tLists) do
        check(not oList.isMultiSelectEnabled(), "List defaults to single selection.");
        selected(oList, {2}, "Single getter is an array");
        check(not pcall(oList.setSelected, {1, 2}), "Single mode rejects multiple selections.");
        click(oList, 4, {Control = true});
        selected(oList, {4}, "Single mode ignores toggle modifiers");
        oList.setMultiSelectEnabled(true);
        check(oList.isMultiSelectEnabled(), "Enables multi-selection.");
        click(oList, 2);
        click(oList, 5, {Shift = true});
        selected(oList, {2, 3, 4, 5}, "Shift click range");
        click(oList, 3, {Shift = true});
        selected(oList, {2, 3}, "Shift range shrinks around anchor");
        click(oList, 8, {Control = true});
        selected(oList, {2, 3, 8}, "Ctrl click adds row");
        click(oList, 3, {Command = true});
        selected(oList, {2, 8}, "Cmd click removes row");
        click(oList, 5, {Shift = true, Control = true});
        selected(oList, {2, 3, 4, 5, 8}, "Ctrl Shift adds anchored range");
        click(oList, 7, {Meta = true});
        selected(oList, {2, 3, 4, 5, 7, 8}, "Meta modifier routes through native adapter");
        click(oList, 2);
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_DOWN, {Shift = true});
        selected(oList, {2, 3}, "Shift Down extends");
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_DOWN, {Control = true});
        selected(oList, {2, 3}, "Ctrl Down only moves focus");
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_SPACE, {Control = true});
        selected(oList, {2, 3, 4}, "Ctrl Space toggles focused row");
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_HOME, {Shift = true});
        selected(oList, {1, 2, 3, 4}, "Shift Home uses current anchor");
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_END, {Shift = true});
        selected(oList, {4, 5, 6, 7, 8, 9, 10, 11, 12}, "Shift End extends to last row");
        dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, 65, {Command = true});
        check(#oList.getSelected() == 12, "Cmd A selects all.");
        local tCopy = oList.getSelected();
        tCopy[1] = 999;
        check(oList.getSelected()[1] == 1, "Getter returns independent snapshot.");
        oList.setSelected({8, 2, 4, 2});
        selected(oList, {2, 4, 8}, "Setter deduplicates and orders");
        local nEvents, nChanges = 0, 0;
        oList.OnChange = function(nPrimary, oSource, tSelected)
            check(oSource == oList and nPrimary == oList.getValue() and type(tSelected) == "table", "Compatible OnChange snapshot.");
            nChanges = nChanges + 1;
        end;
        oList.on("selectionChanged", function(oSource, tEvent)
            check(oSource == oList and type(tEvent.Selected) == "table"
                and type(tEvent.OldSelected) == "table", "Selection event snapshots.");
            nEvents = nEvents + 1;
        end);
        oList.setSelected({2, 4, 8}, true);
        oList.setSelected({2, 4, 8}, true);
        check(nEvents == 1 and nChanges == 1, "Primary changes notify once; repeat is silent.");
        oList.setSelected({4, 8}, true);
        check(nEvents == 2 and nChanges == 2, "Membership changes notify with unchanged primary.");
        check(not pcall(oList.setSelected, {1, 99}), "Invalid selected row rejected.");
        selected(oList, {4, 8}, "Invalid setter preserves selection");
        check(not pcall(oList.setSelected, {[2] = 4}), "Sparse array rejected.");
        oList.setMultiSelectEnabled(false, true);
        selected(oList, {8}, "Disabling retains primary");
        oList.setMultiSelectEnabled(true);
        oList.setSelected({2, 4, 8});
        oList.removeItem(3);
        selected(oList, {2, 3, 7}, "Removal shifts surviving selected rows");
        oList.removeItem(7);
        selected(oList, {2, 3}, "Removing primary retains other rows");
        check(oList.getValue() == 2, "First survivor becomes primary.");
        oList.setItems(oList == tLists[1] and {"A", "B"} or {{Text = "A"}, {Text = "B"}});
        selected(oList, {2}, "Replacement drops out-of-range selections");
        oList.setEnabled(false);
        click(oList, 1, {Control = true});
        selected(oList, {2}, "Disabled input preserves selection");
        oList.setEnabled(true);
        click(oList, 5);
        selected(oList, {}, "Plain empty-space click clears");
        oList.setValue(1);
        selected(oList, {1}, "Scalar setter replaces multi-selection");
        oList.setSelected({});
        selected(oList, {}, "Empty setter clears");
        check(oList.getValue() == 0, "Empty list primary is zero.");
    end

    check(not oTable.isMultiSelectEnabled(), "Table defaults to single selection.");
    selected(oTable, {"id-2"}, "Table single getter");
    check(not pcall(oTable.setSelected, {"id-1", "id-2"}), "Table rejects multiple in single mode.");
    local nNativeId = oTable.TableControl:GetId();
    oTable.setMultiSelectEnabled(true);
    check(not oTable.TableControl:HasFlag(_wx.wxLC_SINGLE_SEL), "Native multi-selection style enabled.");
    oTable.setSelected({"id-8", "id-2", "id-4"});
    selected(oTable, {"id-2", "id-4", "id-8"}, "Table getter display order");
    check(oTable.getValue() == "id-4", "Table primary follows last requested ID.");
    local nEvents = 0;
    oTable.on("selectionChanged", function(oSource, tEvent)
        check(oSource == oTable and type(tEvent.Selected) == "table"
            and type(tEvent.OldSelected) == "table", "Table snapshot payload.");
        nEvents = nEvents + 1;
    end);
    oTable.setSelected({"id-2", "id-4"}, true);
    oTable.setSelected({"id-2", "id-4"}, true);
    check(nEvents == 1, "Table membership event with same primary, no repeat.");
    oTable.TableControl:SetItemState(5, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
    oTable.TableControl:SetItemState(6, _wx.wxLIST_STATE_SELECTED, _wx.wxLIST_STATE_SELECTED);
    selected(oTable, {"id-2", "id-4", "id-6", "id-7"}, "Native selections immediately readable");
    check(nEvents == 1, "Native multi changes defer aggregate event.");
    idle(oTable);
    idle(oTable);
    check(nEvents == 2, "Native gesture notifies once at idle.");
    oTable.sortBy(1, "descending");
    selected(oTable, {"id-7", "id-6", "id-4", "id-2"}, "Sort retains IDs in display order");
    oTable.removeRow("id-4");
    selected(oTable, {"id-7", "id-6", "id-2"}, "Removing primary retains selected IDs");
    oTable.setItems({tRows[2], tRows[6], tRows[12]});
    selected(oTable, {"id-2", "id-6"}, "Replacement retains surviving IDs");
    check(not pcall(oTable.setSelected, {"id-2", "missing"}), "Table invalid setter atomic.");
    selected(oTable, {"id-2", "id-6"}, "Invalid Table selection unchanged");
    local sBeforeAll = oTable.getValue();
    local nBeforeTop = oTable.TableControl:GetTopItem();
    dispatch(oTable.TableControl, _wx.wxEVT_KEY_DOWN, nil, nil, 65, {Control = true});
    selected(oTable, {"id-2", "id-6", "id-12"}, "Native Table Ctrl A callback");
    oTable.setMultiSelectEnabled(false, true);
    selected(oTable, {sBeforeAll}, "Table disable retains primary");
    check(oTable.getValue() == sBeforeAll and oTable.TableControl:GetTopItem() == nBeforeTop,
        "Ctrl A retains native focus and scroll position.");
    check(oTable.TableControl:HasFlag(_wx.wxLC_SINGLE_SEL)
        and oTable.TableControl:GetId() == nNativeId, "Runtime mode keeps native object.");
    oTable.setValue(nil);
    selected(oTable, {}, "Table clear returns empty array");
    oTable.setMultiSelectEnabled(true);
    selected(oTable, {}, "Enable with no selection stays empty");

    for _, oComponent in ipairs({tLists[1], tLists[2], oTable}) do
        check(not pcall(oComponent.setMultiSelectEnabled, "yes"), "Mode requires boolean.");
        oComponent.destroy();
        oComponent.destroy();
    end

    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();
    local tWorkbench = require("Tests.UI")(_wx.NULL);

    for _, tPair in ipairs({{"List", "ListMultiSelect", 2}, {"Table", "TableMultiSelect", 6}, {"ListEx", "ListExMultiSelect", 6}}) do
        tWorkbench.Gallery.show(tPair[2], true);
        tWorkbench.Layout();
        _wx.wxYield();
        local oDemo = tWorkbench.Widgets[tPair[1]];
        check(not oDemo.isMultiSelectEnabled(), "Workbench starts in single mode.");
        click(tWorkbench.Widgets[tPair[2]]);
        check(oDemo.isMultiSelectEnabled(), "Workbench checkbox enables multi-selection.");
        click(tWorkbench.Widgets[tPair[2]]);
        check(not oDemo.isMultiSelectEnabled(), "Workbench checkbox disables multi-selection.");
    end

    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Multi-selection regression passed: ".._nChecks.." checks.");
