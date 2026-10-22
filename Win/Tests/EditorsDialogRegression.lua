--[[!
@fqxn wxLuma.Tests.EditorsDialogRegression
@desc Native regressions for toggle state, decimal editing, skin rendering,
    reusable modal/modeless dialogs, event identity and workbench integration.
!]]
APP_PATH = assert(arg[1], "Pass export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.EditorsDialogRegression.check
@desc Counts each behavior assertion and reports its purpose on failure.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.EditorsDialogRegression.key
@desc Dispatches an event through the real native key binding.
!]]
local function key(oTarget, nKey, nType)
    local jEvent = _wx.wxKeyEvent(nType or _wx.wxEVT_KEY_DOWN);
    jEvent.GetKeyCode = function()
        return nKey;
    end;
    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.EditorsDialogRegression.click
@desc Exercises real mouse callbacks without hardware input automation.
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
@fqxn wxLuma.Tests.EditorsDialogRegression.run
@desc Verifies public contracts and native ownership, then renders production
    widgets into a memory bitmap for a reproducible preview.
!]]
local function run()
    local oSkin  = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Editors regression",
        _wx.wxDefaultPosition, _wx.wxSize(800, 600));
    local nToggleChanges, nToggleEvents, nClicks = 0, 0, 0;
    local oToggle = _Controls.toggleButton(oFrame, {Skin = oSkin, Text = "Auto-cast",
        OnChange = function(bValue, oSource)
            check(type(bValue) == "boolean" and oSource.Control ~= nil, "Toggle callback identity.");
            nToggleChanges = nToggleChanges + 1;
        end});
    oToggle.on("valueChanged", function(oSource, tEvent)
        check(oSource == tEvent.Source and tEvent.Value ~= tEvent.OldValue, "Toggle event identity.");
        nToggleEvents = nToggleEvents + 1;
    end);
    oToggle.on("leftClick", function()
        nClicks = nClicks + 1;
    end);
    oToggle.layout(20, 20, 220, 40);
    -- A synthetic character event tests the production filter's decision. Native
    -- text changes below independently exercise paste/undo/text-updated routing.
    local function fCharacter(oText, nKey)
        local jEvent = _wx.wxKeyEvent(_wx.wxEVT_CHAR);
        jEvent.GetKeyCode = function()
            return nKey;
        end;
        jEvent:SetId(oText:GetId());
        jEvent:SetEventObject(oText);
        oText:GetEventHandler():ProcessEvent(jEvent);
        local bAllowed = jEvent:GetSkipped();
        jEvent:delete();
        return bAllowed;
    end
    local nChanges, nInvalid, nCommitted = 0, 0, 0;
    local oNumber = _Controls.numericField(oFrame, {Skin = oSkin, Min = -10, Max = 10,
        Value = 1.25, Step = 0.25, Precision = 2,
        OnChange = function(nValue, oSource)
            check(type(nValue) == "number" and oSource.TextControl ~= nil, "Numeric callback identity.");
            nChanges = nChanges + 1;
        end});
    oNumber.layout(20, 80, 220, 40);
    oNumber.on("validationFailed", function()
        nInvalid = nInvalid + 1;
    end);
    oNumber.on("committed", function()
        nCommitted = nCommitted + 1;
    end);
    local oPlain = _Controls.numericField(oFrame, {Skin = oSkin, StepButtons = false, Value = 0});
    oPlain.layout(20, 140, 220, 40);
    local oReadOnly = _Controls.numericField(oFrame, {Skin = oSkin, ReadOnly = true, Value = 42.5});
    oReadOnly.layout(20, 200, 220, 40);
    oFrame:Show(true);
    _wx.wxYield();
    check(next(oToggle) == nil and getmetatable(oToggle) == "wxLuma.UI.ToggleButton", "Toggle decoy identity.");
    check(next(oNumber) == nil and getmetatable(oNumber) == "wxLuma.UI.NumericField", "Numeric decoy identity.");
    check(oToggle.getValue() == false, "Toggle defaults off.");
    oToggle.setValue(true);
    check(nToggleChanges == 0 and nToggleEvents == 0, "Silent setter.");
    oToggle.setValue(false, true);
    oToggle.setValue(false, true);
    check(nToggleChanges == 1 and nToggleEvents == 1, "Notify only effective changes.");
    click(oToggle.Control, 10, 10);
    check(oToggle.getValue() and nClicks == 1, "Native click activates and observes.");
    key(oToggle.Control, _wx.WXK_SPACE);
    key(oToggle.Control, _wx.WXK_SPACE);
    check(oToggle.getValue(), "Key repeat does not toggle before release.");
    key(oToggle.Control, _wx.WXK_SPACE, _wx.wxEVT_KEY_UP);
    check(not oToggle.getValue(), "Space releases exactly once.");
    key(oToggle.Control, _wx.WXK_RETURN);
    key(oToggle.Control, _wx.WXK_RETURN, _wx.wxEVT_KEY_UP);
    check(oToggle.getValue(), "Enter toggles.");
    oToggle.setEnabled(false);
    click(oToggle.Control, 10, 10);
    check(oToggle.getValue(), "Disabled toggle ignores activation.");
    oToggle.setEnabled(true);
    check(not pcall(oToggle.setValue, 1), "Strict boolean value.");
    check(oNumber.TextControl:GetValue() == "1.25", "Canonical decimal text.");
    local oText = oNumber.TextControl;
    local nTextEvents = 0;
    oNumber.on("textChanged", function(oSource, tEvent)
        check(oSource == oNumber and tEvent.Text == oText:GetValue(), "Filtered text event identity.");
        nTextEvents = nTextEvents + 1;
    end);
    oText:SetSelection(0, -1);
    check(not fCharacter(oText, string.byte("a")), "Letter rejected before insertion.");
    check(not fCharacter(oText, string.byte("e")), "Scientific-notation letter rejected.");
    check(not fCharacter(oText, string.byte(" ")), "Whitespace rejected.");
    check(fCharacter(oText, string.byte("-")), "Selection replacement permits a leading sign.");
    check(fCharacter(oText, _wx.WXK_BACK), "Backspace remains native.");
    oText:SetSelection(4, 4);
    check(not fCharacter(oText, string.byte("-")), "Sign rejected inside a number.");
    check(not fCharacter(oText, string.byte(".")), "Second decimal point rejected.");
    check(fCharacter(oText, string.byte("7")), "Digit accepted at caret.");
    oText:SetSelection(1, 2);
    check(fCharacter(oText, string.byte(".")), "Replacing the existing decimal point is valid.");
    local nBeforeText = nTextEvents;
    oText:Replace(1, 2, "garbage");
    check(oText:GetValue() == "1.25" and nTextEvents == nBeforeText,
        "Invalid paste-like text update restores accepted text without textChanged.");
    local nStart, nEnd = oText:GetSelection();
    check(nStart == 1 and nEnd == 2, "Rejected edit restores selection.");
    for _, sBad in ipairs({"1.2.3", "--2", "2-", "0x10", "1e2", "12 apples", " 2", "2\n3"}) do
        oText:SetValue(sBad);
        check(oText:GetValue() == "1.25", "Reject entire invalid text update: "..sBad);
    end
    for _, sPartial in ipairs({"", "-", "+", ".", "-.", "+.", "0.", "-.5", "+2.5"}) do
        oText:SetValue(sPartial);
        check(oText:GetValue() == sPartial and oNumber.getValue() == 1.25,
            "Partial decimal retained without committing: "..sPartial);
    end
    oText:SetValue("3.37");
    check(oText:GetValue() == "3.37", "Valid pasted decimal retained.");
    local oNativeText = _wx.wxTextCtrl(oFrame, _wx.wxID_ANY, "1.25");
    oNativeText:Hide();
    for _, oEditor in ipairs({oText, oNativeText}) do
        oEditor:SetValue("1.25");
        oEditor:Replace(0, 4, "2.50");
    end
    check(oText:CanUndo() == oNativeText:CanUndo(), "Valid editing retains native undo.");
    oText:Undo();
    oNativeText:Undo();
    check(oText:GetValue() == oNativeText:GetValue(), "Undo matches the native text editor.");
    oText:Redo();
    oNativeText:Redo();
    check(oText:GetValue() == oNativeText:GetValue(), "Redo matches the native text editor.");
    oNumber.off("textChanged");
    oNumber.setValue(1.25);

    oNumber.TextControl:ChangeValue("3.37");
    check(oNumber.commitText() and oNumber.getValue() == 3.37, "Typed decimals do not snap to Step.");
    check(nChanges == 1, "Committed text notifies once.");
    for _, sBad in ipairs({"", "-", "abc", "1e999", "11", "-11", "nan"}) do
        oNumber.TextControl:ChangeValue(sBad);
        check(not oNumber.commitText() and oNumber.getValue() == 3.37
            and oNumber.TextControl:GetValue() == "3.37", "Invalid text restores prior value: "..sBad);
    end
    check(nInvalid == 7 and nChanges == 1, "Validation failures do not change value.");
    oNumber.TextControl:ChangeValue("2.50");
    key(oNumber.TextControl, _wx.WXK_UP);
    check(oNumber.getValue() == 2.75, "Native Up commits then steps.");
    key(oNumber.TextControl, _wx.WXK_PAGEDOWN);
    check(oNumber.getValue() == 0.25, "Page Down steps ten increments.");
    check(not oNumber.handleKey("down", _wx.WXK_LEFT)
        and not oNumber.handleKey("down", _wx.WXK_HOME), "Caret keys remain native.");
    oNumber.TextControl:ChangeValue("7.89");
    key(oNumber.TextControl, _wx.WXK_ESCAPE);
    check(oNumber.TextControl:GetValue() == "0.25", "Escape discards edit.");
    click(oNumber.Control, 210, 6);
    check(oNumber.getValue() == 0.5, "Step button activates.");
    oNumber.handlePointer("down", 210, 6);
    oNumber.handlePointer("cancel", 210, 6);
    oNumber.handlePointer("up", 210, 6);
    check(oNumber.getValue() == 0.5, "Cancelled press cannot step.");
    oNumber.setValue(999);
    check(oNumber.getValue() == 10, "Setter clamps high.");
    oNumber.setValue(-999);
    check(oNumber.getValue() == -10, "Setter clamps low.");
    oNumber.setValue(1.236);
    check(oNumber.getValue() == 1.24, "Setter rounds precision.");
    local nBefore = nChanges;
    oNumber.setValue(1.24, true);
    check(nChanges == nBefore, "Identical setter is quiet.");
    oNumber.setPrecision(1);
    check(oNumber.getValue() == 1.2 and oNumber.TextControl:GetValue() == "1.2", "Runtime precision.");
    oNumber.setRange(-1, 1);
    check(oNumber.getValue() == 1, "Runtime range clamps value.");
    check(not pcall(oNumber.setRange, 4, 2) and oNumber.getRange() == -1, "Invalid range is atomic.");
    check(not pcall(oNumber.setPrecision, 11) and oNumber.getPrecision() == 1, "Invalid precision is atomic.");
    check(not pcall(oNumber.setStep, 0) and oNumber.getStep() == 0.25, "Invalid step is atomic.");
    check(not pcall(oNumber.setValue, 0/0), "Reject NaN.");
    oNumber.setReadOnly(true);
    check(not oNumber.TextControl:IsEditable() and not oNumber.handleKey("down", _wx.WXK_UP), "Runtime read-only.");
    oNumber.setValue(0.5);
    check(oNumber.getValue() == 0.5, "Bindings still update read-only field.");
    oNumber.setReadOnly(false);
    oNumber.setEnabled(false);
    check(not oNumber.commitText() and not oNumber.handleKey("down", _wx.WXK_UP), "Disabled editor ignores user changes.");
    oNumber.setEnabled(true);
    check(oReadOnly.isReadOnly() and not oReadOnly.commitText(), "Creation read-only.");

    local nClosed, nOpened = 0, 0;
    local oDialog = _Controls.dialog(oFrame, {Skin = oSkin, Title = "Settings", Message = "Sample content",
        OnClose = function(sResult, oSource)
            check(oSource.getValue() == sResult, "Dialog callback identity/result.");
            nClosed = nClosed + 1;
        end});
    check(next(oDialog) == nil and getmetatable(oDialog) == "wxLuma.UI.Dialog", "Dialog decoy identity.");
    check(not oDialog.isOpen() and oDialog.getValue() == nil, "Dialog starts hidden.");
    oDialog.on("opened", function()
        nOpened = nOpened + 1;
    end);
    check(oDialog.show() and not oDialog.show(), "Modeless opening is idempotent.");
    _wx.wxYield();
    check(oDialog.getContainment():GetId() == oDialog.Dialog:GetId(), "Dialog is child-popup boundary.");
    oDialog.close("ok");
    check(not oDialog.isOpen() and oDialog.getValue() == "ok" and nClosed == 1, "Modeless result.");
    oDialog.close("cancel");
    check(nClosed == 1, "Closed dialog does not notify twice.");
    oDialog.show();
    check(oDialog.getValue() == nil, "New opening clears result.");
    key(oDialog.Dialog, _wx.WXK_ESCAPE, _wx.wxEVT_CHAR_HOOK);
    check(oDialog.getValue() == "cancel" and not oDialog.isOpen(), "Escape cancels.");
    oDialog.show();
    click(oDialog.Buttons.ok.Control, 10, 10);
    check(oDialog.getValue() == "ok" and not oDialog.isOpen(), "Skinned button completes dialog.");
    oDialog.show();
    oDialog.Dialog:Close();
    check(oDialog.getValue() == "cancel" and not oDialog.Disposed, "Title close is reusable cancellation.");
    local oTimer = _wx.wxTimer(oDialog.Dialog);
    oDialog.Dialog:Connect(oTimer:GetId(), _wx.wxEVT_TIMER, function()
        oTimer:Stop();
        check(oDialog.Dialog:IsModal() and oDialog.isOpen(), "Real native modal loop active.");
        oDialog.close("ok");
    end);
    oTimer:Start(100, true);
    check(oDialog.showModal() == "ok", "Modal call returns result.");
    check(nOpened == 5, "Opened emitted once per opening, including modal.");
    oTimer:delete();
    oDialog.setEnabled(false);
    check(not oDialog.show() and oDialog.showModal() == nil, "Disabled dialog cannot open.");
    oDialog.setEnabled(true);
    check(not pcall(_Controls.dialog, oFrame, {Skin = oSkin, Buttons = {"wrong"}}), "Invalid buttons rejected.");

    -- Native focus and event routing must preserve editor-owned Enter handling.
    local oDialogNumber = _Controls.numericField(oDialog.Content, {Skin = oSkin, Value = 1.25});
    oDialogNumber.layout(12, 70, 220, 40);
    oDialog.show();
    oDialogNumber.TextControl:SetFocus();
    _wx.wxYield();
    oDialogNumber.TextControl:ChangeValue("4.75");
    key(oDialog.Dialog, _wx.WXK_RETURN, _wx.wxEVT_CHAR_HOOK);
    check(oDialog.isOpen(), "Enter belongs to a text editor that processes it.");
    local jEnter = _wx.wxCommandEvent(_wx.wxEVT_COMMAND_TEXT_ENTER, oDialogNumber.TextControl:GetId());
    jEnter:SetEventObject(oDialogNumber.TextControl);
    oDialogNumber.TextControl:GetEventHandler():ProcessEvent(jEnter);
    jEnter:delete();
    check(oDialogNumber.getValue() == 4.75, "Editor Enter commits inside dialog.");
    oDialog.close();
    oDialogNumber.destroy();
    local bReopened = false;
    oDialog.OnClose = function()
        if (not bReopened) then
            bReopened = true;
            oDialog.show();
        end
    end;
    local oReopenTimer = _wx.wxTimer(oDialog.Dialog);
    oDialog.Dialog:Connect(oReopenTimer:GetId(), _wx.wxEVT_TIMER, function()
        oReopenTimer:Stop();
        oDialog.close("yes");
    end);
    oReopenTimer:Start(80, true);
    check(oDialog.showModal() == "yes" and oDialog.isOpen() and oDialog.getValue() == nil,
        "Modal result survives reentrant callback reopening.");
    oReopenTimer:delete();
    oDialog.close();
    local oFour = _Controls.dialog(oFrame, {Skin = oSkin, Width = 320,
        Buttons = {"yes", "no", "ok", "cancel"}});
    oFour.show();
    _wx.wxYield();
    for _, oButton in pairs(oFour.Buttons) do
        local nX = oButton.Control:GetPositionXY();
        local nWidth = oButton.Control:GetSizeWH();
        check(nX >= 0 and nX + nWidth <= 320, "All four actions fit the minimum dialog width.");
    end
    oFour.destroy();
    local nFocusChanges = nChanges;
    oNumber.TextControl:ChangeValue("0.8");
    local jFocus = _wx.wxFocusEvent(_wx.wxEVT_KILL_FOCUS, oNumber.TextControl:GetId());
    jFocus:SetEventObject(oNumber.TextControl);
    oNumber.TextControl:GetEventHandler():ProcessEvent(jFocus);
    jFocus:delete();
    check(oNumber.getValue() == 0.8 and nChanges == nFocusChanges + 1, "Focus loss commits edited decimal.");
    local oBounded = _Controls.numericField(oFrame, {Skin = oSkin, Min = 0.001, Max = 0.019,
        Precision = 2, Step = 0.01});
    check(oBounded.getValue() == 0.01, "Non-lattice endpoints remain inside bounds.");
    oBounded.setValue(0.019);
    check(oBounded.getValue() == 0.01, "Rounding cannot exceed an off-lattice maximum.");
    oBounded.destroy();
    oNumber.setEnabled(false);
    oPlain.setEnabled(false);
    oReadOnly.setEnabled(false);

    -- Render real controls rather than a mockup or desktop screenshot.
    local oBitmap = _wx.wxBitmap(780, 420);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oDC:SetBackground(oBrush);
    oDC:Clear();
    local nY = 12;
    for _, oWidget in ipairs({oToggle, oNumber, oPlain, oReadOnly}) do
        oDC:SetDeviceOrigin(12, nY);
        oWidget.draw(oDC, 220, 40);
        nY = nY + 58;
    end
    -- All dedicated materials must load in every state, not just the defaults.
    for _, bValue in ipairs({false, true}) do
        oToggle.setValue(bValue);
        for _, sState in ipairs({"Normal", "Hover", "Pressed", "Disabled"}) do
            oToggle.setEnabled(sState ~= "Disabled");
            oToggle.Hover = sState == "Hover" or sState == "Pressed";
            oToggle.Pressed = sState == "Pressed";
            oToggle.draw(oDC, 220, 40);
            check(true, "Toggle skin state rendered: "..sState);
        end
    end
    oToggle.setEnabled(true);
    oToggle.setValue(true);
    oToggle.Hover, oToggle.Pressed = false, false;
    oDC:SetDeviceOrigin(12, 12);
    oToggle.draw(oDC, 220, 40);
    oDC:SetDeviceOrigin(264, 12);
    oDialog.draw(oDC, 500, 300);
    oDC:SetDeviceOrigin(0, 0);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    check(oImage:IsOk(), "Production skin rendering succeeded.");
    oImage:SaveFile(APP_PATH.."/Tests/EditorsDialogPreview.png", _wx.wxBITMAP_TYPE_PNG);
    oImage:delete();
    oDC:delete();
    oBitmap:delete();
    oBrush:delete();
    oDialog.destroy();
    oDialog.destroy();
    check(oDialog.Disposed, "Dialog disposal idempotent.");
    for _, oWidget in ipairs({oToggle, oNumber, oPlain, oReadOnly}) do
        oWidget.destroy();
        oWidget.destroy();
        check(oWidget.Disposed, "Control disposal idempotent.");
    end
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    check(#tWorkbench.Widgets.Tabs.Pages == #tWorkbench.Gallery.Categories, "Every gallery category has a tab.");
    tWorkbench.Gallery.show("Dialog", true);
    tWorkbench.Layout();
    check(tWorkbench.Widgets.ToggleButton and tWorkbench.Widgets.NumericField
        and tWorkbench.Widgets.Dialog and tWorkbench.Widgets.ModalDialog, "All objects demonstrated.");
    tWorkbench.Widgets.Dialog.show();
    tWorkbench.Frame:Close();
    _wx.wxYield();
    collectgarbage("collect");
end

local bOK, sError = xpcall(run, debug.traceback);
if (not bOK) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end
print("Editors/dialog regression: ".._nChecks.." checks passed.");
