--[[!
@fqxn wxLuma.Tests.InspectorRegression
@desc Exercises inspector widgets against the packaged native wx runtime.
    Filesystem tests browse existing fixtures without creating or changing files.
    Audio is not played. Frames, popups, timers and owned editors are disposed.
!]]
APP_PATH = APP_PATH or assert(arg[1], "Pass the Windows host directory.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Framework = require("wxLuma")();
local _Controls = _Framework.Controls;
local _Skin = _Controls.loadSkin();
local _Frame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Inspector regression",
    _wx.wxDefaultPosition, _wx.wxSize(900, 760));
local _tObjects = {};
local _nChecks = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.InspectorRegression.check
@desc Counts successful behavioral assertions and identifies failures.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.InspectorRegression.create
@desc Creates and tracks a component, reusing one caller-owned skin.
!]]
local function create(sFactory, tOptions)
    tOptions.Skin = _Skin;
    local oObject = _Controls[sFactory](_Frame, tOptions);
    _tObjects[#_tObjects + 1] = oObject;
    oObject.layout(12, 12, 680, 520);
    return oObject;
end

--[[!
@fqxn wxLuma.Tests.InspectorRegression.mouse
@desc Dispatches a real native mouse event to an owned input surface.
!]]
local function mouse(oTarget, nType, nX, nY)
    local jEvent = _wx.wxMouseEvent(nType);
    jEvent.GetX = function() return nX or 10; end;
    jEvent.GetY = function() return nY or 10; end;
    jEvent:SetId(oTarget:GetId()); jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent); jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.InspectorRegression.dispatchTimers
@desc Runs a bounded native event loop so real timer delivery is tested rather
    than assuming wxApp.Yield dispatches Windows timer messages in this host.
!]]
local function dispatchTimers()
    local oTimer = _wx.wxTimer(_Frame);
    local nId = oTimer:GetId();
    _Frame:Connect(nId, _wx.wxEVT_TIMER, function() _wx.wxGetApp():ExitMainLoop(); end);
    assert(oTimer:Start(70, true));
    _wx.wxGetApp():MainLoop();
    _Frame:Disconnect(nId, _wx.wxEVT_TIMER);
    oTimer:Stop(); oTimer:delete();
end

--[[!
@fqxn wxLuma.Tests.InspectorRegression.run
@desc Checks typed values, notifications, real editor events, browser commits,
    popup cancellation, exclusivity, artwork states and repeat-safe disposal.
!]]
local function run()
    _Frame:Show(true);
    local nSearch, nChange = 0, 0;
    local oSearch = create("searchField", {OnSearch = function() nSearch = nSearch + 1; end,
        OnChange = function() nChange = nChange + 1; end});
    oSearch.setValue("binding"); check(nSearch == 0 and nChange == 0, "Silent search binding.");
    oSearch.setValue("typed", true); check(nSearch == 1 and nChange == 1, "Immediate search.");
    oSearch.setValue("typed", true); check(nSearch == 1, "Identical search setter.");
    oSearch.clear(); check(nSearch == 2 and oSearch.getValue() == "", "Clear searches empty text.");
    oSearch.clear(); check(nSearch == 2, "Repeated clear is silent.");
    oSearch.TextControl:SetValue("native"); check(nSearch == 3 and nChange == 3, "Native typing notification.");
    oSearch.onEditorKey(_wx.WXK_ESCAPE); check(oSearch.getValue() == "", "Escape clears search.");
    oSearch.setEnabled(false); check(not oSearch.search(), "Disabled search."); oSearch.setEnabled(true);
    local nDelayed = 0;
    local oDelayed = create("searchField", {Debounce = 20, OnSearch = function() nDelayed = nDelayed + 1; end});
    oDelayed.setValue("pending", true); check(nDelayed == 0, "Debounce waits.");
    dispatchTimers(); check(nDelayed == 1, "Debounce searches once.");
    oDelayed.setValue("old", true); oDelayed.setValue("binding");
    dispatchTimers(); check(nDelayed == 1, "Silent binding cancels stale debounce.");
    oDelayed.setValue("disabled", true); oDelayed.setEnabled(false);
    dispatchTimers(); check(nDelayed == 1, "Disabling cancels debounce.");

    local oCombo = create("comboBox", {Items = {"Alpha", "Beta"}, Value = "free"});
    check(oCombo.getValue() == "free" and oCombo.getSelection() == 0, "Combo allows free text.");
    oCombo.setSelection(2); check(oCombo.getValue() == "Beta" and oCombo.getSelection() == 2, "Combo selection.");
    check(not pcall(oCombo.setSelection, 3) and oCombo.getValue() == "Beta", "Invalid combo selection is atomic.");
    local tItems = oCombo.getItems(); tItems[1] = "changed";
    check(oCombo.getItems()[1] == "Alpha", "Combo copies items.");
    _Frame:Show(true); _wx.wxGetApp():Yield();
    check(oCombo.open(), "Combo opens."); oCombo.List.setValue(1); oCombo.close(false);
    check(oCombo.getValue() == "Beta", "Combo preview cancellation.");
    check(oCombo.open(), "Combo reopens."); oCombo.List.setValue(1); oCombo.List.handleKey("down", _wx.WXK_RETURN);
    check(oCombo.getValue() == "Alpha" and not oCombo.isOpen(), "List Enter commits combo text.");
    check(oCombo.open(), "Combo opens before disabling."); oCombo.setEnabled(false);
    check(not oCombo.isOpen() and not oCombo.open(), "Disabled combo closes."); oCombo.setEnabled(true);
    oCombo.setItems({}); check(oCombo.getValue() == "Alpha" and not oCombo.open(), "Empty suggestions preserve free text.");
    oCombo.setItems({"Alpha", "Beta"});
    check(oCombo.getAutoComplete(), "Combo typing completion defaults on.");
    oCombo.TextControl:SetFocus(); oCombo.TextControl:SetValue("b");
    check(oCombo.isOpen() and oCombo.List.getValue() == 2, "Typing opens and selects a prefix match.");
    check(oCombo.getValue() == "b" and oCombo.TextControl:HasFocus(), "Typing preview preserves text and caret focus.");
    dispatchTimers(); check(oCombo.isOpen() and oCombo.TextControl:HasFocus(), "Nonactivating preview survives native dispatch.");
    oCombo.onEditorKey(_wx.WXK_UP); check(oCombo.List.getValue() == 1 and oCombo.TextControl:HasFocus(), "Typing preview arrow navigation.");
    local jEnter = _wx.wxCommandEvent(_wx.wxEVT_COMMAND_TEXT_ENTER, oCombo.TextControl:GetId());
    jEnter:SetEventObject(oCombo.TextControl); oCombo.TextControl:GetEventHandler():ProcessEvent(jEnter); jEnter:delete();
    check(oCombo.getValue() == "Alpha" and not oCombo.isOpen(), "Native editor Enter commits without reopening.");
    oCombo.TextControl:SetValue("B"); check(oCombo.isOpen() and oCombo.List.getValue() == 2, "Prefix match ignores case.");
    oCombo.TextControl:SetValue("no match"); check(not oCombo.isOpen() and oCombo.getValue() == "no match", "Unmatched typing remains free text.");
    oCombo.TextControl:SetValue("a"); oCombo.onEditorKey(_wx.WXK_ESCAPE);
    check(not oCombo.isOpen() and oCombo.getValue() == "a", "Escape cancels automatic preview only.");
    oCombo.setAutoComplete(false); oCombo.TextControl:SetValue("b");
    check(not oCombo.getAutoComplete() and not oCombo.isOpen(), "Typing completion can be disabled.");
    check(oCombo.open(), "Manual suggestions still open with completion disabled."); oCombo.close(false);
    oCombo.setAutoComplete(true); oCombo.TextControl:SetValue("a"); oCombo.setAutoComplete(false);
    check(not oCombo.isOpen() and oCombo.getValue() == "a", "Disabling completion cancels its preview.");
    oCombo.setAutoComplete(true); oCombo.setValue("Beta", true);
    check(not oCombo.isOpen(), "Notified programmatic bindings do not autocomplete.");
    oCombo.TextControl:SetValue("a"); oSearch.TextControl:SetFocus();
    check(not oCombo.isOpen(), "Editor focus loss closes automatic preview.");
    local oManualCombo = create("comboBox", {Items = {"Alpha", "Beta"}, AutoComplete = false});
    oManualCombo.TextControl:SetFocus(); oManualCombo.TextControl:SetValue("a");
    check(not oManualCombo.isOpen(), "Constructor can disable typing completion.");

    local oFile = create("filePicker", {Directory = _Framework.Path.."/..", Value = "original"});
    oFile.layout(12, 12, 500, 38);
    mouse(oFile.Control, _wx.wxEVT_LEFT_DOWN, 485, 18); mouse(oFile.Control, _wx.wxEVT_LEFT_UP, 485, 18);
    check(oFile.isOpen(), "File browse image opens through native mouse dispatch.");
    check(oFile.UpButton.Control:GetClientSizeWH() >= 24 and oFile.DirectoryField.Control:GetClientSizeWH() > 20,
        "Browser children are laid out before first show.");
    dispatchTimers(); check(oFile.isOpen(), "File browser survives native paint dispatch.");
    check(not oFile.navigate(oFile.getDirectory().."missing-directory-fixture") and oFile.isOpen(), "Invalid directory preserves browser.");
    oFile.NameField.setValue("missing-file-fixture"); check(not oFile.close(true), "Invalid file keeps browser open.");
    oFile.NameField.setValue("README.md"); check(oFile.close(true), "Existing file commits.");
    check(_wx.wxFileExists(oFile.getValue()) and oFile.getValue():match("README%.md$"), "Committed absolute file path.");
    local sFile = oFile.getValue(); check(oFile.open(), "File browser reopens.");
    oFile.NameField.setValue("LICENSE"); oFile.close(false); check(oFile.getValue() == sFile, "File cancel preserves value.");
    local oFolder = create("folderPicker", {Directory = _Framework.Path});
    oFolder.layout(12, 12, 500, 38);
    mouse(oFolder.Control, _wx.wxEVT_LEFT_DOWN, 485, 18); mouse(oFolder.Control, _wx.wxEVT_LEFT_UP, 485, 18);
    check(oFolder.isOpen(), "Folder browse image opens through native mouse dispatch.");
    dispatchTimers(); check(oFolder.isOpen(), "Folder browser survives native paint dispatch.");
    check(oFolder.close(true), "Current folder commits.");
    check(_wx.wxDirExists(oFolder.getValue()), "Committed folder exists.");
    for _, oPicker in ipairs({oFile, oFolder}) do
        check(oPicker.open(), "Picker opens before disable."); oPicker.setEnabled(false);
        check(not oPicker.isOpen() and not oPicker.open(), "Disabled picker closes browser."); oPicker.setEnabled(true);
    end

    local sCommand;
    local oMenus = create("menuBar", {Menus = {{Id = "file", Text = "File", Items = {
        {Id = "open", Text = "Open"}, {Id = "nested", Text = "Nested", Items = {{Id = "child", Text = "Child"}}}}},
        {Id = "disabled", Text = "Disabled", Enabled = false, Items = {{Id = "noop", Text = "Noop"}}},
        {Id = "help", Text = "Help", Items = {{Id = "about", Text = "About"}}}},
        OnSelect = function(tSelection) sCommand = tSelection.MenuId..":"..tSelection.Id; end});
    check(oMenus.open("file"), "Menu heading opens.");
    check(getmetatable(oMenus) == "wxLuma.UI.MenuBar", "MenuBar retains its own public type.");
    oMenus.getMenu("file").handleKey("down", _wx.WXK_RIGHT);
    check(oMenus.getMenu("help").isOpen(), "Menu Right skips disabled headings.");
    oMenus.getMenu("help").handleKey("down", _wx.WXK_LEFT);
    check(oMenus.getMenu("file").isOpen(), "Menu Left switches headings.");
    oMenus.getMenu("file").activateItem("nested");
    check(oMenus.getMenu("file").getLayout().Depth == 1, "Menu enters nested page.");
    oMenus.getMenu("file").handleKey("down", _wx.WXK_LEFT);
    check(oMenus.getMenu("file").getLayout().Depth == 0, "Nested Left retains Back navigation.");
    oMenus.getMenu("file").activateItem("open"); check(sCommand == "file:open", "Menu command stable IDs.");
    check(not oMenus.open("disabled"), "Disabled menu heading.");
    check(not oMenus.getMenu("disabled").isEnabled(), "Disabled heading disables owned popup.");
    check(not pcall(oMenus.setMenus, {{Id = "bad", Items = {{Id = "dup", Text = "A"}, {Id = "dup", Text = "B"}}}}), "Invalid nested menu rejected.");
    check(oMenus.getMenus()[1].Id == "file", "Invalid menu replacement preserves previous menus.");
    local tMenus = oMenus.getMenus(); tMenus[1].Items[1].Text = "changed";
    check(oMenus.getMenus()[1].Items[1].Text == "Open", "Menu descriptors are copied.");
    check(oMenus.open("file"), "Menu opens before disable."); oMenus.setEnabled(false);
    check(not oMenus.isOpen() and not oMenus.open("file"), "Disabling dismisses menu."); oMenus.setEnabled(true);

    local oPanel = create("collapsiblePanel", {Text = "Details", Expanded = false, ContentHeight = 90});
    check(not oPanel.isExpanded() and oPanel.getBestHeight() == 36, "Collapsed panel height.");
    oPanel.handleKey("down", _wx.WXK_RIGHT); check(oPanel.isExpanded() and oPanel.getBestHeight() == 126, "Keyboard expansion.");
    local oChild = _wx.wxTextCtrl(oPanel.Content, _wx.wxID_ANY, "retained");
    oPanel.setExpanded(false); oPanel.setExpanded(true); check(oChild:GetValue() == "retained", "Collapse preserves child state.");
    oPanel.setEnabled(false); check(not oPanel.toggle(), "Disabled panel cannot toggle."); oPanel.setEnabled(true);
    local oAccordion = create("accordion", {Sections = {{Id = "a", Expanded = true}, {Id = "b", Expanded = true}}});
    check(#oAccordion.getExpanded() == 1 and oAccordion.getExpanded()[1] == "a", "Exclusive initial expansion.");
    oAccordion.setExpanded("b", true); check(not oAccordion.getSection("a").isExpanded() and oAccordion.getSection("b").isExpanded(), "Exclusive sibling collapse.");
    oAccordion.getSection("a").toggle(); check(oAccordion.getExpanded()[1] == "a" and #oAccordion.getExpanded() == 1, "Section click respects exclusivity.");
    local oMultiple = create("accordion", {Exclusive = false, Sections = {{Id = "a", Expanded = true}, {Id = "b", Expanded = true}}});
    check(#oMultiple.getExpanded() == 2, "Nonexclusive accordion.");

    local nProperties = 0;
    local oGrid = create("propertyGrid", {Properties = {{Id = "general", Type = "category"},
        {Id = "text", Value = "sample"}, {Id = "number", Type = "number", Value = 1.234, Max = 10, Precision = 2},
        {Id = "boolean", Type = "boolean", Value = true}, {Id = "choice", Type = "choice", Items = {"A", "B"}, Value = "B"},
        {Id = "color", Type = "color", Value = {R = 10, G = 20, B = 30}}, {Id = "file", Type = "file"}, {Id = "folder", Type = "folder"},
        {Id = "readonly", Value = "fixed", ReadOnly = true}}, OnChange = function() nProperties = nProperties + 1; end});
    check(oGrid.getValue("number") == 1.23 and oGrid.getValue("boolean") == true, "Grid normalized typed values.");
    oGrid.setValue("text", "updated", true); oGrid.setValue("text", "updated", true);
    check(nProperties == 1, "Grid emits once for effective changes.");
    oGrid.getEditor("text").TextControl:SetValue("native"); check(oGrid.getValue("text") == "native" and nProperties == 2, "Grid native text binding.");
    oGrid.getEditor("boolean").setValue(false, true); check(oGrid.getValue("boolean") == false, "Grid checkbox binding.");
    oGrid.getEditor("choice").setValue(1, true); check(oGrid.getValue("choice") == "A", "Grid choice binding.");
    check(not pcall(oGrid.setValue, "number", 11, true) and oGrid.getValue("number") == 1.23, "Invalid grid number is atomic.");
    check(not pcall(oGrid.setValue, "choice", "C"), "Invalid grid choice rejected.");
    local tColor = oGrid.getValue("color"); tColor.R = 255; check(oGrid.getValue("color").R == 10, "Grid copies colors.");
    local tProps = oGrid.getProperties(); tProps[5].Items[1] = "changed";
    check(oGrid.getProperties()[5].Items[1] == "A", "Grid copies choice descriptors.");
    check(not oGrid.getEditor("readonly").isEnabled(), "Read-only grid row.");
    oGrid.setReadOnly("readonly", false); check(oGrid.getEditor("readonly").isEnabled(), "Read-only policy change.");
    oGrid.setReadOnly("readonly", true); oGrid.setEnabled(false); oGrid.setEnabled(true);
    check(not oGrid.getEditor("readonly").isEnabled() and oGrid.getEditor("text").isEnabled(), "Grid reenable preserves row policy.");

    -- Every new component must retain the same public event identity and artwork states.
    for _, oObject in ipairs(_tObjects) do
        local nDown, nDestroyed = 0, 0;
        -- Each fixture occupies the same bounds; expose the actual native
        -- input target before dispatch instead of focusing a covered surface.
        oObject.Control:Raise();
        oObject.on("leftDown", function(oSource) check(oSource == oObject, "Public input source."); nDown = nDown + 1; end);
        oObject.on("destroyed", function(oSource) check(oSource == oObject, "Public destruction source."); nDestroyed = nDestroyed + 1; end);
        mouse(oObject.Control, _wx.wxEVT_LEFT_DOWN); mouse(oObject.Control, _wx.wxEVT_LEFT_UP);
        check(nDown == 1, "One native pointer notification.");
        local oBitmap = _wx.wxBitmap(680, 520); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        -- Transient clipped parts must not allocate zero/negative native bitmaps.
        _Skin.draw(oDC, "Button Middle Normal", 0, 0, 0, 36);
        _Skin.drawOpaque(oDC, "Button Middle Normal", 0, 0, -4, 36);
        check(true, "Nonpositive skin parts are safely clipped.");
        for _, sState in ipairs({"Normal", "Hover", "Pressed", "Disabled"}) do
            oObject.setEnabled(sState ~= "Disabled"); oObject.Hover = sState == "Hover"; oObject.Pressed = sState == "Pressed";
            oObject.draw(oDC, 680, 520); check(true, "Artwork state: "..sState);
        end
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
        oObject.destroy(); oObject.destroy(); check(nDestroyed == 1, "Repeat-safe destruction.");
    end
end

local bOK, sError = xpcall(run, debug.traceback);
for _, oObject in ipairs(_tObjects) do oObject.destroy(); end
_Frame:Destroy(); _Skin.destroy();
assert(bOK, sError);
print("Inspector regression: ".._nChecks.." checks passed.");
