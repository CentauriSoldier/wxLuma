--[[!
@fqxn wxLuma.Tests.EventHooksRegression
@desc Exercises application audio subscription hooks through real wx event
    dispatch. No audio is played and no fixture or preview files are written.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the Windows host directory.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Framework = require("wxLuma")();
local _Controls = _Framework.Controls;
local _Events = require("wxLuma.Core.ControlEvents");
local _nChecks = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.EventHooksRegression.check
@desc Counts an assertion and identifies a failed event contract.
@param boolean bPassed Whether the contract holds.
@param string sMessage Failure description.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.EventHooksRegression.mouse
@desc Sends a native mouse event through the production handler chain.
@param wxWindow oTarget Component-owned native surface.
@param number nType Native event type.
!]]
local function mouse(oTarget, nType)
    local jEvent = _wx.wxMouseEvent(nType);
    jEvent.GetX = function() return 10; end;
    jEvent.GetY = function() return 10; end;
    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.EventHooksRegression.exercise
@desc Verifies exact-once delivery, public source identity, listener removal,
    repeated attachment and disabled-click cancellation on one native target.
@param table oComponent Public object under test.
@param wxWindow oTarget Native interaction surface belonging to the object.
!]]
local function exercise(oComponent, oTarget)
    local tCounts = {pointerEnter = 0, pointerLeave = 0, rightClick = 0};
    for sName in pairs(tCounts) do
        oComponent.on(sName, function(oSource, tEvent)
            check(oSource == oComponent and tEvent.Source == oComponent, "Public event source.");
            tCounts[sName] = tCounts[sName] + 1;
        end);
    end

    -- Reattachment must extend the same emitter, retaining every subscription.
    _Events.attach(oComponent, {oTarget}, {"regressionEvent"});
    _Events.attach(oComponent, {oTarget});
    mouse(oTarget, _wx.wxEVT_ENTER_WINDOW);
    mouse(oTarget, _wx.wxEVT_LEAVE_WINDOW);
    mouse(oTarget, _wx.wxEVT_RIGHT_DOWN);
    mouse(oTarget, _wx.wxEVT_RIGHT_UP);
    check(tCounts.pointerEnter == 1 and tCounts.pointerLeave == 1 and tCounts.rightClick == 1,
        "Exactly one enter, leave and click per native gesture: "..tostring(getmetatable(oComponent))
            .." "..tCounts.pointerEnter.."/"..tCounts.pointerLeave.."/"..tCounts.rightClick);

    mouse(oTarget, _wx.wxEVT_RIGHT_DOWN);
    oComponent.setEnabled(false);
    oComponent.setEnabled(true);
    mouse(oTarget, _wx.wxEVT_RIGHT_UP);
    check(tCounts.rightClick == 1, "Disabling cancels incomplete clicks.");
    oComponent.off("rightClick");
    mouse(oTarget, _wx.wxEVT_RIGHT_DOWN);
    mouse(oTarget, _wx.wxEVT_RIGHT_UP);
    check(tCounts.rightClick == 1, "Removed audio hook remains removed.");
    oComponent.off("pointerEnter").off("pointerLeave");
end

--[[!
@fqxn wxLuma.Tests.EventHooksRegression.run
@desc Covers every factory, owned native editors, row/node transitions and
    existing semantic subscriptions without invoking the audio backend.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Event hooks regression",
        _wx.wxDefaultPosition, _wx.wxSize(800, 600));
    local oPanel = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local tObjects = {};
    local oGroup = _Controls.radioGroup();
    local tFactories = {
        checkbox = {}, radio = {Group = oGroup, Value = "one"},
        slider = {Min = 0, Max = 100, Step = 1, Value = 20},
        spinner = {Min = 0, Max = 100, Step = 1, Value = 20}, button = {}, toggleButton = {},
        scrollbar = {Min = 0, Max = 100, Page = 10, Value = 0},
        list = {Items = {"One", "Two"}}, dropdown = {Items = {"One", "Two"}}, textfield = {},
        numericField = {}, label = {}, image = {}, colorPicker = {}, toolbar = {}, statusBar = {},
        progress = {Min = 0, Max = 100, Value = 20},
        circularProgress = {Min = 0, Max = 100, Value = 20},
        globeProgress = {Min = 0, Max = 100, Value = 20},
        radialProgress = {Min = 0, Max = 100, Value = 20},
        irisProgress = {Min = 0, Max = 100, Value = 20},
        panel = {}, tabs = {Items = {"One", "Two"}}, scrollContainer = {}, splitContainer = {},
        tree = {Items = {{Id = "one", Text = "One"}}},
        treeEx = {Items = {{Id = "one", Text = "One"}, {Id = "two", Text = "Two"}}},
        table = {Columns = {{Text = "Name"}}, Items = {{Id = "one", Cells = {"One"}}}},
        listEx = {Columns = {{Key = "Text"}}, Items = {{Text = "One"}, {Text = "Two"}}},
        imageButton = {Image = _Framework.Config.ImagePath.."/Menu/Command Sword.png"},
        contextMenu = {}, radialMenu = {}, dialog = {},
    };

    for sName, tOptions in pairs(tFactories) do
        tOptions.Skin = oSkin;
        local oObject = _Controls[sName](oPanel, tOptions);
        tObjects[sName] = oObject;
        if (oObject.layout) then oObject.layout(0, 0, 400, 240); end
        exercise(oObject, oObject.Control);
        if (oObject.TextControl) then exercise(oObject, oObject.TextControl); end
    end

    local oTip = _Controls.tooltip(oPanel, {Skin = oSkin, Text = "Tip", Enabled = false});
    oTip.setEnabled(true);
    exercise(oTip, oPanel);
    oTip.destroy();
    local oWindow = _Framework.Window.create(oPanel, {Decorated = false});
    exercise(oWindow, oWindow.Control);
    oWindow.destroy();
    local oTop = _Framework.TopLevelWindow.create(nil, {Skin = oSkin, Decorated = false});
    exercise(oTop, oTop.Control);
    oTop.destroy();

    for _, sName in ipairs({"list", "listEx"}) do
        local oList = tObjects[sName];
        local nEnter, nLeave = 0, 0;
        oList.on("itemHovered", function() nEnter = nEnter + 1; end);
        oList.on("itemLeft", function() nLeave = nLeave + 1; end);
        oList.setHover(1); oList.setHover(1); oList.setHover(2); oList.setHover(0);
        check(nEnter == 2 and nLeave == 2, "Row transitions suppress repeated hover.");
    end
    local oTree = tObjects.treeEx;
    local sEntered, sLeft;
    oTree.on("itemHovered", function(oSource, tEvent) sEntered = tEvent.Id; end);
    oTree.on("itemLeft", function(oSource, tEvent) sLeft = tEvent.Id; end);
    oTree.Rows.setHover(1); oTree.Rows.setHover(0);
    check(sEntered == "one" and sLeft == "one", "Tree hover hooks expose stable node IDs.");

    -- A visible button exercises shared capture/activation alongside observers.
    -- Hide other fixtures so native painting stays limited to this interaction.
    for _, oObject in pairs(tObjects) do oObject.Control:Hide(); end
    local nClicks, nActions = 0, 0;
    local oAction = _Controls.button(oPanel, {Skin = oSkin, Text = "Action",
        OnClick = function() nActions = nActions + 1; end});
    oAction.layout(20, 20, 180, 40);
    oAction.on("leftClick", function() nClicks = nClicks + 1; end);
    oFrame:Show(true);
    _wx.wxYield();
    mouse(oAction.Control, _wx.wxEVT_LEFT_DOWN);
    mouse(oAction.Control, _wx.wxEVT_LEFT_UP);
    check(nClicks == 1 and nActions == 1 and not oAction.Control:HasCapture(),
        "Mouse audio hook preserves button activation and releases capture.");
    oAction.handleKey("down", _wx.WXK_RETURN);
    oAction.handleKey("up", _wx.WXK_RETURN);
    check(nActions == 2 and nClicks == 1, "Keyboard activation does not fabricate a mouse click.");
    oAction.destroy();

    -- Existing widget-specific events share the base emitter after extension.
    local nValues, nSelections = 0, 0;
    tObjects.toggleButton.on("valueChanged", function() nValues = nValues + 1; end);
    tObjects.toggleButton.setValue(true, true);
    tObjects.list.on("selectionChanged", function() nSelections = nSelections + 1; end);
    tObjects.list.setValue(2, true);
    check(nValues == 1 and nSelections == 1, "Widget semantic events survive base attachment.");

    for _, oObject in pairs(tObjects) do
        local nDestroyed = 0;
        oObject.on("destroyed", function() nDestroyed = nDestroyed + 1; end);
        oObject.destroy(); oObject.destroy();
        check(nDestroyed == 1, "Repeated attachment preserves exact-once disposal.");
    end
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();
end

run();
print("Event hooks regression: ".._nChecks.." checks passed.");
