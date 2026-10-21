--[[!
@fqxn wxLuma.Tests.ListExRegression
@desc Checks fixed typed column definitions, independent cell updates, runtime row
    mutations, native input, clipped image pixels, lazy rendering and workbench use.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
local _tFixtures = {};
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ListExRegression.check
@desc Counts checks and identifies failed behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ListExRegression.dispatch
@desc Dispatches native input with read-only event accessors supplied at the Lua
    callback boundary. It exercises handlers rather than hardware input.
!]]
local function dispatch(oTarget, nType, nX, nY, nKey)
    local jEvent;

    if (nKey) then
        jEvent = _wx.wxKeyEvent(nType);
        jEvent.GetKeyCode = function()
            return nKey;
        end;
    else
        jEvent = _wx.wxMouseEvent(nType);
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
@fqxn wxLuma.Tests.ListExRegression.pixels
@desc Returns an owned RGB image rendered through the real ListEx drawing path.
!]]
local function pixels(oList, nWidth, nHeight)
    local oBitmap = _wx.wxBitmap(nWidth, nHeight);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oList.draw(oDC, nWidth, nHeight);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    oDC:delete();
    oBitmap:delete();
    return oImage;
end

--[[!
@fqxn wxLuma.Tests.ListExRegression.run
@desc Creates visible native instances, verifies data/rendering behavior, then
    exercises the workbench's mutation buttons and minimum-size layout.
!]]
local function run()
    local pRed = APP_PATH.."/Tests/ListEx-red-fixture.png";
    local pGreen = APP_PATH.."/Tests/ListEx-green-fixture.png";

    for nIndex, pPath in ipairs({pRed, pGreen}) do
        local hExisting = io.open(pPath, "rb");
        assert(not hExisting, "Refusing to overwrite existing fixture.");
        local oSolid = _wx.wxImage(40, 20);
        oSolid:SetRGB(_wx.wxRect(0, 0, 40, 20), nIndex == 1 and 240 or 20,
            nIndex == 1 and 30 or 230, 20);
        assert(oSolid:SaveFile(pPath, _wx.wxBITMAP_TYPE_PNG));
        oSolid:delete();
        _tFixtures[#_tFixtures + 1] = pPath;
    end

    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "ListEx regression",
        _wx.wxDefaultPosition, _wx.wxSize(1000, 700));
    local oSkin = _Controls.loadSkin();
    local tColumns = {
        {Key = "Picture", Type = "image", Width = 64},
        {Key = "Name", Type = "text", Weight = 2},
        {Key = "Class", Type = "text", Weight = 1},
        {Key = "Level", Type = "number", Width = 70, Align = "right",
            Format = function(nValue)
                return "Lv "..nValue;
            end},
        {Key = "Ready", Type = "boolean", Width = 70}
    };
    local tRows = {
        {Picture = pRed, Name = "Arden", Class = "Ranger", Level = 7, Ready = false},
        {Picture = pGreen, Name = "Bryn", Class = "Mage", Level = 12, Ready = true},
        {Name = "Cora", Class = "Warrior", Level = 9}
    };
    local nSelections, nActivations = 0, 0;
    local oList = _Controls.listEx(oFrame, {
        Skin = oSkin, Columns = tColumns, Items = tRows, Value = 1, RowHeight = 64,
        OnChange = function()
            nSelections = nSelections + 1;
        end,
        OnActivate = function()
            nActivations = nActivations + 1;
        end
    });
    oList.layout(10, 10, 700, 210);
    oFrame:Show(true);
    _wx.wxYield();
    check(next(oList) == nil and getmetatable(oList) == "wxLuma.UI.ListEx", "ListEx has a single independent proxy identity.");
    check(#oList.getColumns() == 5 and oList.getCell(1, 5) == false, "Configured types preserve boolean false.");
    tColumns[1].Width = 999;
    tRows[1].Name = "outside mutation";
    check(oList.getColumns()[1].Width == 64 and oList.getCell(1, 2) == "Arden", "Definitions and rows are owned structural copies.");
    local tSnapshot = oList.getItem(1);
    tSnapshot.Class = "outside mutation";
    check(oList.getCell(1, 3) == "Ranger", "Row snapshots cannot mutate the list.");
    check(oList.getText() == "Arden", "Selection text uses the first text column.");
    local nCells, nItems = 0, 0;
    oList.on("cellChanged", function(oSource, tEvent)
        check(oSource == oList and tEvent.Index == 1, "Cell event identifies the proxy and row.");
        nCells = nCells + 1;
    end).on("itemChanged", function()
        nItems = nItems + 1;
    end);
    oList.setCell(1, 3, "Mage", true);
    oList.setCell(1, 3, "Mage", true);
    check(nCells == 1 and nItems == 1 and nSelections == 0, "Changed cell notifies once without a selection change.");
    check(oList.getCell(1, 2) == "Arden" and oList.getCell(1, 4) == 7, "Cell editing preserves the rest of the row.");
    oList.setCell(1, 4, 8);
    check(nCells == 1 and oList.getCell(1, 4) == 8, "Cell setters default to silent.");
    check(not pcall(oList.setCell, 1, 4, "eight", true), "Reject incorrect cell type.");
    check(oList.getCell(1, 4) == 8 and nCells == 1, "Rejected edits leave data/events unchanged.");
    check(not pcall(oList.setCell, 1, 9, "bad"), "Reject absent columns.");
    check(not pcall(oList.setItems, {{Name = "bad", Level = 0 / 0}}), "Reject invalid replacement atomically.");
    check(#oList.Items == 3 and oList.getValue() == 1, "Rejected replacement preserves existing rows and selection.");

    local oRed = pixels(oList, 700, 210);
    check(oRed:GetRed(30, 30) == 240 and oRed:GetGreen(30, 30) == 30, "Image cell renders source pixels.");
    check(oRed:GetRed(9, 30) ~= 240 and oRed:GetRed(69, 30) ~= 240, "Image clipping stays within its cell.");
    oRed:delete();
    oList.setCell(1, 1, pGreen);
    local oGreen = pixels(oList, 700, 210);
    check(oGreen:GetRed(30, 30) == 20 and oGreen:GetGreen(30, 30) == 230, "Picture cells update independently at runtime.");
    oGreen:delete();
    oList.setCell(1, 1, APP_PATH.."/missing-picture.png");
    local oMissing = pixels(oList, 700, 210);
    check(oMissing:IsOk(), "Missing images render a safe placeholder.");
    oMissing:delete();
    oList.setCell(1, 1, nil);
    check(oList.getCell(1, 1) == nil, "Nil clears an image cell.");

    oList.setValue(2);
    oList.addItem({Name = "Dara", Class = "Mage", Level = 3}, true);
    check(#oList.Items == 4 and oList.getValue() == 2, "Appending preserves selection.");
    oList.removeItem(1, true);
    check(oList.getValue() == 1 and oList.getText() == "Bryn", "Removal before selection retains its logical row.");
    oList.removeItem(1, true);
    check(oList.getValue() == 0 and #oList.Items == 2, "Removing selected row clears selection.");
    oList.setItem(1, {Name = "Changed row", Class = "Knight", Level = 10, Ready = false});
    check(oList.getCell(1, 2) == "Changed row" and oList.getCell(1, 5) == false, "Whole-row replacement preserves typed values.");
    oList.setItems({}, true);
    check(oList.getValue() == 0 and #oList.Items == 0, "Empty replacement clears rows and selection.");
    dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_HOME);
    check(oList.getValue() == 0, "Empty list keyboard navigation remains safe.");

    -- Only visible rows format/render, even with 10,000 records.
    local nFormats = 0;
    local tLarge = {};

    for nIndex = 1, 10000 do
        tLarge[nIndex] = {Name = string.format("Entry %05d", nIndex), Level = nIndex, Ready = nIndex % 2 == 0};
    end

    local oLarge = _Controls.listEx(oFrame, {
        Skin = oSkin, Columns = {
            {Key = "Name", Type = "text", Format = function(sValue)
                nFormats = nFormats + 1;
                return sValue;
            end},
            {Key = "Level", Type = "number"}, {Key = "Ready", Type = "boolean"}
        }, Items = tLarge, RowHeight = 40
    });
    oLarge.layout(10, 240, 700, 168);
    local nBeforeFormats = nFormats;
    local oLargePixels = pixels(oLarge, 700, 168);
    check(nFormats - nBeforeFormats == oLarge.getVisibleCount(), "Large lists draw only visible rows.");
    oLargePixels:delete();
    dispatch(oLarge.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_END);
    check(oLarge.getValue() == 10000 and oLarge.First > 1, "End selects/reveals the last rich row.");
    dispatch(oLarge.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_HOME);
    check(oLarge.getValue() == 1 and oLarge.First == 1, "Home returns to the first rich row.");
    dispatch(oLarge.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_PAGEDOWN);
    check(oLarge.getValue() == 1 + oLarge.getVisibleCount(), "Page Down navigates rich rows.");
    oLarge.setItems({{Name = "Alpha"}, {Name = "Beta"}});
    oLarge.setValue(1);
    dispatch(oLarge.Control, _wx.wxEVT_CHAR, nil, nil, string.byte("b"));
    check(oLarge.getValue() == 2, "Character search uses rich row text.");
    oList.setItems({{Name = "First"}, {Name = "Second"}});
    dispatch(oList.Control, _wx.wxEVT_LEFT_DOWN, 100, 80);
    dispatch(oList.Control, _wx.wxEVT_LEFT_UP, 100, 80);
    check(oList.getValue() == 2 and nActivations == 1 and not oList.Control:HasCapture(),
        "Native pointer selects/activates a rich row and releases capture.");
    local nRight = 0;
    oList.on("rightClick", function()
        nRight = nRight + 1;
    end);
    dispatch(oList.Control, _wx.wxEVT_RIGHT_DOWN, 100, 20);
    dispatch(oList.Control, _wx.wxEVT_RIGHT_UP, 100, 20);
    check(nRight == 1, "ListEx exposes standard right-click subscriptions.");
    oList.setEnabled(false);
    local nDisabledValue = oList.getValue();
    dispatch(oList.Control, _wx.wxEVT_KEY_DOWN, nil, nil, _wx.WXK_HOME);
    check(oList.getValue() == nDisabledValue, "Disabled rich list ignores navigation.");
    oList.setEnabled(true);
    oList.Control:Update();
    local nPaints = 0;
    local fDraw = oList.draw;
    oList.draw = function(...)
        nPaints = nPaints + 1;
        return fDraw(...);
    end;

    for nIndex = 1, 100 do
        oList.setCell(1, 2, oList.getCell(1, 2), true);
        oList.setItem(1, oList.getItem(1), true);
    end

    oList.Control:Update();
    check(nPaints == 0, "Repeated cell/row bindings do not repaint.");
    local nDestroyed = 0;
    oList.on("destroyed", function()
        nDestroyed = nDestroyed + 1;
    end);
    oList.destroy();
    oList.destroy();
    oLarge.destroy();
    check(nDestroyed == 1, "Repeated disposal emits once and releases caches.");
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Widgets.Tabs.setValue(6);
    tWorkbench.Layout();
    _wx.wxYield();
    local oDemo = tWorkbench.Widgets.ListEx;
    check(oDemo.Control:IsShownOnScreen() and #oDemo.getColumns() == 3, "Workbench exposes the three-column ListEx example.");
    local sName = oDemo.getCell(1, 2);
    local sClass = oDemo.getCell(1, 3);
    local nRows = #oDemo.Items;
    dispatch(tWorkbench.Widgets.ListExUpdate.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    dispatch(tWorkbench.Widgets.ListExUpdate.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(oDemo.getCell(1, 3) ~= sClass and oDemo.getCell(1, 2) == sName, "Workbench edits class independently.");
    dispatch(tWorkbench.Widgets.ListExAdd.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    dispatch(tWorkbench.Widgets.ListExAdd.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(#oDemo.Items == nRows + 1, "Workbench appends rows at runtime.");
    dispatch(tWorkbench.Widgets.ListExRemove.Control, _wx.wxEVT_LEFT_DOWN, 20, 20);
    dispatch(tWorkbench.Widgets.ListExRemove.Control, _wx.wxEVT_LEFT_UP, 20, 20);
    check(#oDemo.Items == nRows, "Workbench removes rows at runtime.");
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Layout();
    local _, nDemoHeight = oDemo.Control:GetClientSizeWH();
    check(nDemoHeight >= oDemo.RowHeight + 8, "Minimum workbench size displays a complete rich row.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

for _, pFixture in ipairs(_tFixtures) do
    os.remove(pFixture);
end

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("ListEx regression passed: ".._nChecks.." checks.");