--[[!
@fqxn wxLuma.Tests.ListStress
@desc Compares the preserved plain list with the actual/decoy/metatable list.
Run with Lua 5.4 from the export root. Reports CPU time and memory, validates
matching behavior and rendered pixels, and leaves no result files.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path  = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";

local _wx        = require("wx");
local _Plain     = require("UI.Widgets.ListPlain");
local _Object    = require("UI.Widgets.List");
local _Skin      = require("UI.Core.ControlSkin").load();
local _oFrame    = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma List Stress", _wx.wxDefaultPosition, _wx.wxSize(800, 600));
local _tItems    = {};
local _tLists    = {};
local _tTimes    = {Plain = {}, Object = {}};
local _tCounts   = {Plain = 0, Object = 0};
local _nRows     = 100000;
local _nRounds   = 7;

for nIndex = 1, _nRows do
    _tItems[nIndex] = string.format("Sample entry %06d", nIndex);
end

--[[!
@fqxn wxLuma.Tests.ListStress.create
@desc Creates one variant and checks the identity delivered by list callbacks.
@param table Module The list factory module.
@param string sName The result label.
@ret table oList The created component.
!]]
local function create(Module, sName)
    local nBefore = collectgarbage("count");
    local oList;

    oList = Module.create(_oFrame, {
        Skin     = _Skin,
        Items    = _tItems,
        Value    = 1,
        OnChange = function(nValue, oSource)
            assert(oSource == oList and nValue == oList.getValue(), "Callback mismatch.");
            _tCounts[sName] = _tCounts[sName] + 1;
        end,
    });

    assert(oList.layout(0, 0, 640, 480) == oList, 'Layout identity mismatch.');
    assert(oList.setEnabled(true) == oList, 'Enabled identity mismatch.');
    print(string.format("%s creation memory delta: %.1f KiB", sName, collectgarbage("count") - nBefore));
    return oList;
end

_tLists.Plain  = create(_Plain,  "Plain");
_tLists.Object = create(_Object, "Object");
assert(next(_tLists.Object) == nil, "The object must store fields outside its decoy.");

--[[!
@fqxn wxLuma.Tests.ListStress.exercise
@desc Exercises selection, wheel scrolling, hover, keyboard and buffered drawing.
@param table oList The component under test.
@param string sMode The workload name.
@param number nCount Number of operations.
@ret number nElapsed CPU seconds for the workload.
!]]
local function exercise(oList, sMode, nCount)
    oList.setValue(1);
    oList.scrollTo(1);
    local oBitmap;
    local oDC;

    if (sMode == "draw") then
        oBitmap = _wx.wxBitmap(640, 480);
        oDC     = _wx.wxMemoryDC();
        oDC:SelectObject(oBitmap);
    end

    local nStart = os.clock();

    for nIndex = 1, nCount do
        if (sMode == "selection") then
            oList.setValue((nIndex * 97) % _nRows + 1, true);
        elseif (sMode == "input") then
            oList.handlePointer("move", 20, 8 + (nIndex % 15) * 28);
            oList.handleKey("down", nIndex % 2 == 0 and _wx.WXK_DOWN or _wx.WXK_UP);
            oList.wheel(nIndex % 2 == 0 and 1 or -1);
        else
            oList.setValue((nIndex * 97) % _nRows + 1);
            oList.draw(oDC, 640, 480);
        end
    end

    local nElapsed = os.clock() - nStart;

    if (oDC) then
        oDC:SelectObject(_wx.wxNullBitmap);
        oDC:delete();
        oBitmap:delete();
    end

    return nElapsed;
end

--[[!
@fqxn wxLuma.Tests.ListStress.median
@desc Returns the middle of an odd number of measured times.
@param table tValues Measured CPU durations.
@ret number nMedian The median duration.
!]]
local function median(tValues)
    table.sort(tValues);
    return tValues[math.floor(#tValues / 2) + 1];
end

local _tWorkloads = {{"selection", 50000}, {"input", 25000}, {"draw", 1000}};

for _, tWorkload in ipairs(_tWorkloads) do
    local sMode, nCount = tWorkload[1], tWorkload[2];
    _tTimes = {Plain = {}, Object = {}};

    -- Warm both paths, then alternate order to reduce ordering bias.
    exercise(_tLists.Plain,  sMode, 100);
    exercise(_tLists.Object, sMode, 100);

    for nRound = 1, _nRounds do
        local tOrder = nRound % 2 == 0 and {"Object", "Plain"} or {"Plain", "Object"};

        for _, sName in ipairs(tOrder) do
            collectgarbage("collect");
            _tTimes[sName][nRound] = exercise(_tLists[sName], sMode, nCount);
        end

        assert(_tLists.Plain.getValue() == _tLists.Object.getValue(), "Selection mismatch.");
        assert(_tLists.Plain.First == _tLists.Object.First, "Scroll mismatch.");
        assert(_tLists.Plain.HoverRow == _tLists.Object.HoverRow, "Hover mismatch.");
    end

    local nPlain  = median(_tTimes.Plain);
    local nObject = median(_tTimes.Object);
    print(string.format("%s (%d operations): plain %.4fs; object %.4fs; delta %+.2f%%", sMode, nCount, nPlain, nObject, (nObject / nPlain - 1) * 100));
end

assert(_tCounts.Plain == _tCounts.Object, "Notification count mismatch.");

-- Compare native rendered pixels with identical selection and hover state.
local _tImages = {};

for _, sName in ipairs({"Plain", "Object"}) do
    local oList = _tLists[sName];
    oList.setValue(50000);
    oList.setHover(50000);
    local oBitmap = _wx.wxBitmap(640, 480);
    local oDC     = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oList.draw(oDC, 640, 480);
    oDC:SelectObject(_wx.wxNullBitmap);
    oDC:delete();
    _tImages[sName] = oBitmap:ConvertToImage();
    oBitmap:delete();
end

for nY = 0, 479 do
    for nX = 0, 639 do
        for _, sChannel in ipairs({"GetRed", "GetGreen", "GetBlue"}) do
            assert(_tImages.Plain[sChannel](_tImages.Plain, nX, nY) == _tImages.Object[sChannel](_tImages.Object, nX, nY), "Rendered pixel mismatch.");
        end
    end
end

for _, oImage in pairs(_tImages) do
    oImage:delete();
end
for _, oList in pairs(_tLists) do
    oList.destroy();
end
_oFrame:Destroy();
_wx.wxGetApp():ProcessPendingEvents();
_Skin.destroy();
collectgarbage("collect");
print("PASS: matching selection, scroll, hover, callback identity/counts and rendered RGB pixels.");
-- Verify integration using the real event loop and the object-backed dropdown.
local _tWorkbench = require("Tests.UI")(_wx.NULL);
local _oTimer     = _wx.wxTimer(_tWorkbench.Frame);

_tWorkbench.Frame:Connect(_oTimer:GetId(), _wx.wxEVT_TIMER, function()
    _oTimer:Stop();
    _tWorkbench.Widgets.Tabs.setValue(2);
    _tWorkbench.Widgets.List.setValue(2000);
    assert(_tWorkbench.Widgets.List.getValue() == 2000);

    local oDropdown = _tWorkbench.Widgets.Dropdown;
    assert(oDropdown.open(), "Dropdown failed to open.");
    oDropdown.List.setValue(100);
    oDropdown.close(true);
    assert(oDropdown.getValue() == 100, "Dropdown failed to commit.");
    assert(oDropdown.open(), "Dropdown failed to reopen.");
    oDropdown.List.setValue(200);
    oDropdown.close(false);
    assert(oDropdown.getValue() == 100, "Dropdown failed to cancel.");

    _tWorkbench.Frame:Close();
    print("PASS: native workbench startup, object list, dropdown commit/cancel and close.");
end);

_oTimer:Start(500, true);
_wx.wxGetApp():MainLoop();
_oTimer:delete();
collectgarbage("collect");