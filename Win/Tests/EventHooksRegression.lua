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
local function mouse(oTarget, nType, nX, nY)
    local jEvent = _wx.wxMouseEvent(nType);
    jEvent.GetX = function() return nX or oTarget.TestHitX or 10; end;
    jEvent.GetY = function() return nY or oTarget.TestHitY or 10; end;
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
    -- Shape-aware controls need a point on their artwork, not host padding.
    if (oComponent.PointerHitTest and oTarget == oComponent.Control) then
        local nWidth, nHeight = oTarget:GetClientSizeWH();
        local bFound = false;
        for nY = 0, nHeight - 1 do
            for nX = 0, nWidth - 1 do
                if (oComponent.PointerHitTest(nX, nY)) then
                    oTarget.TestHitX, oTarget.TestHitY, bFound = nX, nY, true; break;
                end
            end
            if (bFound) then break; end
        end
        check(bFound, "Interactive artwork has an accepted point.");
        local nOutsideClicks = 0;
        oComponent.on("rightClick", function() nOutsideClicks = nOutsideClicks + 1; end);
        mouse(oTarget, _wx.wxEVT_RIGHT_DOWN, -1, -1);
        mouse(oTarget, _wx.wxEVT_RIGHT_UP, -1, -1);
        check(nOutsideClicks == 0, "Outside points cannot emit button clicks.");
        if (not oComponent.PointerHitTest(0, 0)) then
            mouse(oTarget, _wx.wxEVT_RIGHT_DOWN, 0, 0);
            mouse(oTarget, _wx.wxEVT_RIGHT_UP, 0, 0);
            check(nOutsideClicks == 0, "Transparent artwork or host padding cannot emit button clicks.");
        end
        oComponent.off("rightClick");
    end
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

    -- Listener-local snapshots cannot corrupt later listeners or the emitter's data.
    local tPayload = {Value = {Text = "original"}, Target = oTarget};
    tPayload.Value.Self = tPayload.Value;
    oComponent.on("regressionEvent", function(_, tEvent)
        tEvent.Name = "changed"; tEvent.Value.Text = "changed";
    end);
    oComponent.on("regressionEvent", function(_, tEvent)
        check(tEvent.Name == "regressionEvent" and tEvent.Value.Text == "original"
            and tEvent.Value.Self == tEvent.Value and tEvent.Source == oComponent and tEvent.Target == oTarget,
            "Event snapshots isolate nested data and preserve resource identities.");
    end);
    _Events.attach(oComponent).emit("regressionEvent", tPayload);
    check(tPayload.Value.Text == "original", "Event listeners cannot mutate the original payload.");
    oComponent.off("regressionEvent");
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

    -- Rejected item updates must preserve the open preview, not silently
    -- cancel it before List's atomic validation reports the invalid data.
    local nDropdownChanges = 0;
    local oDropdown = _Controls.dropdown(oPanel, {Skin = oSkin, Items = {"First", "Second"}, Value = 1,
        OnChange = function() nDropdownChanges = nDropdownChanges + 1; end});
    oDropdown.layout(20, 20, 220, 40); oDropdown.open(); oDropdown.List.setValue(2);
    check(oDropdown.isOpen(), "Dropdown fixture has an open preview.");
    check(not pcall(oDropdown.setItems, {17}) and oDropdown.isOpen() and oDropdown.getValue() == 1
        and oDropdown.List.getValue() == 2 and oDropdown.getText() == "First",
        "Rejected dropdown items retain popup, preview, accepted value and contents.");
    oDropdown.setItems({"Replacement"});
    check(not oDropdown.isOpen() and oDropdown.getValue() == 1 and oDropdown.getText() == "Replacement"
        and nDropdownChanges == 0, "Valid dropdown replacement closes and adopts clamped selection silently.");
    oDropdown.destroy();

    -- Public group selection must not let a foreign member invalidate either
    -- group's exclusivity or silently change what getValue reports.
    local oOtherGroup = _Controls.radioGroup();
    local oOtherRadio = _Controls.radio(oPanel, {Skin = oSkin, Text = "Other", Group = oOtherGroup, Value = "other", Selected = true});
    tObjects.radio.setValue(true);
    check(not pcall(oGroup.select, oOtherRadio, true) and oGroup.getValue() == "one"
        and tObjects.radio.getValue() and oOtherGroup.getValue() == "other" and oOtherRadio.getValue(),
        "Foreign radio selection is rejected without changing either group's selection.");
    check(not pcall(oGroup.select, {}) and not pcall(oGroup.select, nil) and oGroup.getValue() == "one",
        "Unregistered/nil radio members cannot clear valid group state.");
    oOtherRadio.destroy();
    check(not pcall(oOtherGroup.select, oOtherRadio) and oOtherGroup.getValue() == nil,
        "Retired radio members cannot be selected again.");

    -- Exercise both shared bases: parent availability must not substitute for
    -- a child's own flag, including when its value is saved under that parent.
    for _, sFactory in ipairs({"button", "label"}) do
        local oObject = tObjects[sFactory]; oObject.setEnabled(true);
        oPanel:Enable(false); oObject.setEnabled(false);
        check(not oObject.Control:IsThisEnabled(), "Disabled ancestor does not swallow a local disable: "..sFactory);
        check(oObject.getObjectState().Objects[1].Properties.Enabled[1] == false,
            "State captures the local disabled policy under a disabled ancestor: "..sFactory);
        oPanel:Enable(true);
        check(not oObject.isEnabled(), "Re-enabling a parent preserves an explicitly disabled child: "..sFactory);
        oPanel:Enable(false); oObject.setEnabled(true);
        check(oObject.Control:IsThisEnabled() and not oObject.isEnabled(),
            "A local enable request preserves inherited disabling: "..sFactory);
        oPanel:Enable(true);
        check(oObject.isEnabled(), "Parent re-enable reveals the retained local enable: "..sFactory);
    end

    -- Lazy section hosts retain their own policy while a parent is disabled.
    local oStatus = tObjects.statusBar;
    oStatus.setItems({{Id = "custom", Text = "Custom"}, {Id = "second", Text = "Second"}});
    oPanel:Enable(false);
    local oHost = oStatus.getSection("custom");
    check(oHost:IsThisEnabled() and not oHost:IsEnabled(), "New status sections retain local enabling under disabled ancestors.");
    oPanel:Enable(true);
    check(oHost:IsEnabled(), "Status sections become available when their ancestor is enabled.");
    oPanel:Enable(false); oStatus.setEnabled(false);
    local oSecondHost = oStatus.getSection("second");
    oPanel:Enable(true);
    check(not oSecondHost:IsThisEnabled() and not oSecondHost:IsEnabled(), "New sections preserve an explicitly disabled status bar.");
    oStatus.setEnabled(true);
    check(oHost:IsEnabled() and oSecondHost:IsEnabled(), "Enabling a status bar enables its section hosts.");

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
