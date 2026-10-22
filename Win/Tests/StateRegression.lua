--[[!
@fqxn wxLuma.Tests.StateRegression
@desc Native and data-only tests for iterative state trees, stable identities,
    partial reconstruction, missing subtrees, detached snapshots and rollback.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Luma = require("wxLuma")();
local _Object = require("wxLuma.Core.ControlObject");
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.StateRegression.check
@desc Counts assertions and reports the violated persistence contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.StateRegression.probe
@desc Makes a small existing state object without native UI or any constructor
    accessible to restoration. Its setter intentionally rejects invalid values.
!]]
local function probe(nValue)
    local oObject = _Object.create({Value = nValue}, "wxLuma.Tests.StateProbe");
    oObject.getValue = function() return oObject.Value; end;
    oObject.setValue = function(nNext)
        assert(type(nNext) == "number", "Probe value must be numeric.");
        oObject.Value = nNext;
    end;
    return oObject;
end

--[[!
@fqxn wxLuma.Tests.StateRegression.run
@desc Exercises deep existing hierarchies and live widgets without LuaEx or an
    encoder. Objects are explicitly created before applying any saved state.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local tDeep = {};

    for nIndex = 1, 6000 do
        tDeep[nIndex] = probe(nIndex);

        if (nIndex > 1) then
            tDeep[nIndex - 1].addStateChild("next", tDeep[nIndex]);
        end
    end

    local tDeepState = tDeep[1].getObjectState();
    check(#tDeepState.Objects == 6000, "Six thousand child tiers capture without recursive calls.");
    local tPartial = {};

    for nIndex = 1, 1500 do
        tPartial[nIndex] = probe(-1);

        if (nIndex > 1) then
            tPartial[nIndex - 1].addStateChild("next", tPartial[nIndex]);
        end
    end

    local _, tReport = tPartial[1].setObjectState(tDeepState);
    check(tReport.Applied == 1500 and tReport.Skipped == 4500, "A reconstructed prefix skips its entire missing tail.");
    check(tPartial[1].getValue() == 1 and tPartial[1500].getValue() == 1500, "Matched deep descendants restore correctly.");
    tDeepState.Objects[1501].Properties.Value[1] = "unusable missing state";
    check(pcall(tPartial[1].setObjectState, tDeepState), "Missing objects are skipped without applying their properties.");
    tDeepState.Objects[1501].Properties.Value[1] = 1501;
    tDeep[6000].addStateChild("cycle", tDeep[1]);
    check(not pcall(tDeep[1].getObjectState), "Cyclic ownership is rejected instead of looping.");
    tDeep[6000].removeStateChild("cycle");

    local oRoot, oFirst, oSecond = probe(10), probe(20), probe(30);
    oRoot.addStateChild("first", oFirst).addStateChild("second", oSecond);
    local tInvalid = oRoot.getObjectState();
    tInvalid.Objects[1].Properties.Value[1] = 90;
    tInvalid.Objects[3].Properties.Value[1] = "bad";
    check(not pcall(oRoot.setObjectState, tInvalid), "Invalid matched data reports a restoration error.");
    check(oRoot.getValue() == 10 and oFirst.getValue() == 20 and oSecond.getValue() == 30,
        "Failed restore rolls already-applied values back.");
    local tMalformed = oRoot.getObjectState();
    tMalformed.Objects[1].Children.first = 1;
    check(not pcall(oRoot.setObjectState, tMalformed) and oRoot.getValue() == 10,
        "Malformed ownership fails before any live changes.");

    local oCustom = _Object.create({Setting = {Name = "before"}}, "wxLuma.Tests.CustomState");
    _Luma.State.register("wxLuma.Tests.CustomState", {
        capture = function(oObject) return oObject.Setting; end,
        validate = function(tData) assert(type(tData.Name) == "string", "Invalid custom name."); end,
        restore = function(oObject, tData) oObject.Setting = tData; end
    });
    local tCustom = oCustom.getObjectState();
    oCustom.Setting.Name = "after";
    check(tCustom.Objects[1].Properties.Custom.Name == "before", "Snapshot data is detached from live values.");
    oCustom.setObjectState(tCustom);
    tCustom.Objects[1].Properties.Custom.Name = "external";
    check(oCustom.Setting.Name == "before", "Restored state is detached from the caller's snapshot.");

    local oSkin = _Luma.Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "State regression");
    local oSource = _Luma.Controls.panel(oFrame, {Skin = oSkin});
    local oTarget = _Luma.Controls.panel(oFrame, {Skin = oSkin});
    local tOwned = {oSource, oTarget};

    --[[!
    @fqxn wxLuma.Tests.StateRegression.run.widget
    @desc Creates application-owned controls and assigns stable persistence IDs.
        Restoration itself has no access to this constructor helper.
    !]]
    local function fWidget(sFactory, oParent, sId, tOptions)
        tOptions = tOptions or {};
        tOptions.Skin = oSkin;
        local oWidget = _Luma.Controls[sFactory](oParent.Control, tOptions);
        oWidget.setStateId(sId);
        tOwned[#tOwned + 1] = oWidget;
        return oWidget;
    end

    local nChanges = 0;
    fWidget("textfield", oSource, "name", {Value = "saved name"});
    local oMissing = fWidget("panel", oSource, "missing branch");
    fWidget("textfield", oMissing, "nested", {Value = "skip me"});
    fWidget("checkbox", oSource, "changed type", {Selected = true});
    fWidget("globeProgress", oSource, "meter", {Min = 0, Max = 100, Value = 75, Reserved = 25});
    fWidget("propertyGrid", oSource, "settings", {Properties = {
        {Id = "name", Value = "saved setting"}, {Id = "removed", Value = "removed setting"}}});
    fWidget("tabs", oSource, "tabs", {Items = {{Id = "alpha", Text = "Alpha"}, {Id = "beta", Text = "Beta"}}, Value = 2});
    fWidget("treeEx", oSource, "tree", {Items = {{Id = "keep", Text = "Keep", Expanded = true,
        Children = {{Id = "leaf", Text = "Leaf"}}}, {Id = "gone", Text = "Gone"}}, Value = "gone"});

    -- Reordered construction proves matching does not depend on native IDs or
    -- sibling positions. Missing branches, grid rows, tabs and tree nodes are
    -- application schema differences rather than a reason to construct anything.
    local oTabs = fWidget("tabs", oTarget, "tabs", {Items = {{Id = "beta", Text = "Beta"}, {Id = "alpha", Text = "Alpha"}}, Value = 2});
    local oText = fWidget("textfield", oTarget, "name", {Value = "current name", OnChange = function() nChanges = nChanges + 1; end});
    local oExtra = fWidget("textfield", oTarget, "new child", {Value = "leave me"});
    local oDifferent = fWidget("slider", oTarget, "changed type", {Min = 0, Max = 100, Step = 1, Value = 12});
    local oMeter = fWidget("globeProgress", oTarget, "meter", {Min = 0, Max = 100, Value = 10});
    local oGrid = fWidget("propertyGrid", oTarget, "settings", {Properties = {
        {Id = "other", Value = "new setting"}, {Id = "name", Value = "current setting"}}});
    local oTree = fWidget("treeEx", oTarget, "tree", {Items = {{Id = "keep", Text = "Keep", Expanded = false,
        Children = {{Id = "leaf", Text = "Leaf"}}}}, Value = "keep"});
    local tSnapshot = oSource.getObjectState();
    local nBefore = 0;

    for _ in pairs(_Object.instances()) do nBefore = nBefore + 1; end
    local oReturned, tNativeReport = oTarget.setObjectState(tSnapshot);
    local nAfter = 0;
    for _ in pairs(_Object.instances()) do nAfter = nAfter + 1; end
    check(oReturned == oTarget and nBefore == nAfter, "Restoration creates no objects and preserves the target identity.");
    check(tNativeReport.Applied >= 6 and tNativeReport.Skipped >= 3, "Missing and replaced native children are reported as skipped.");
    check(oText.getValue() == "saved name" and nChanges == 0, "Named controls restore silently despite reordered construction.");
    check(oExtra.getValue() == "leave me" and oDifferent.getValue() == 12, "Extra live children and replaced types remain untouched.");
    check(oMeter.getValue() == 75 and oMeter.getReserved() == 25, "Reserve is restored before bounded current.");
    check(oGrid.getValue("name") == "saved setting" and oGrid.getValue("other") == "new setting", "Missing property rows are skipped without replacing the grid schema.");
    check(oTabs.getValue() == 1, "Tabs restore selection by stable ID rather than its old index.");
    check(oTree.getValue() == "keep" and oTree.getNode("keep").Expanded, "Missing tree selection is skipped while existing expansion restores.");

    for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); end
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxGetApp():Yield();

    -- Exercise the complete existing gallery, including compound controls.
    local tDemo = assert(loadfile(APP_PATH.."/Tests/UI.lua"))()();
    local tGallery = tDemo.Window.getObjectState();
    local _, tGalleryReport = tDemo.Window.setObjectState(tGallery);
    check(tGalleryReport.Applied == #tGallery.Objects and tGalleryReport.Skipped == 0,
        "The complete existing gallery restores every captured component.");
    tDemo.Frame:Close();
    _wx.wxGetApp():Yield();
    check(package.loaded["LuaEx.load"] == nil, "Native state support never loads LuaEx.");
end

run();
print("State regression: ".._nChecks.." checks passed.");
