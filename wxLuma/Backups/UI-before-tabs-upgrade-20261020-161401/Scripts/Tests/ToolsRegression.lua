--[[!
@fqxn wxLuma.Tests.ToolsRegression
@desc Native tests for skinned tool/status strips and contained RGBA/HSV editing.
    Uses production drawing and native callbacks, not hardware input automation.
!]]
APP_PATH = assert(arg[1], "Pass export root.");
package.path = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _Color    = require("UI.Core.ControlColor");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.ToolsRegression.check
@desc Counts a behavior assertion and reports its purpose on failure.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ToolsRegression.click
@desc Routes pointer events through native bindings using explicit event coordinates.
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
@fqxn wxLuma.Tests.ToolsRegression.key
@desc Routes synthetic keys through actual native callbacks without claiming OS input.
!]]
local function key(oTarget, nCode, nType)
    local jEvent = _wx.wxKeyEvent(nType or _wx.wxEVT_KEY_DOWN);
    jEvent.GetKeyCode = function()
        return nCode;
    end;
    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.ToolsRegression.run
@desc Checks mutation, geometry, containment, commit/cancel, custom skins and disposal.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Tools regression",
        _wx.wxDefaultPosition, _wx.wxSize(800, 740));
    oFrame:SetClientSize(800, 740);
    local oPanel = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local nActivated, nClicked = 0, 0;
    local tCommands = {
        {Id = "one", Text = "Attack", Width = 120, Image = APP_PATH.."/Images/UI/Menu/Command Sword.png",
            Tooltip = "Attack the target"},
        {Id = "sep", Kind = "separator"},
        {Id = "toggle", Text = "Auto-cast", Kind = "toggle", Width = 120},
        {Id = "disabled", Text = "Disabled", Enabled = false},
    };
    for nIndex = 1, 8 do
        tCommands[#tCommands + 1] = {Id = "extra"..nIndex, Text = "Extra "..nIndex};
    end
    local oToolbar = _Controls.toolbar(oPanel, {Skin = oSkin, Items = tCommands,
        OnActivate = function(sId, oSource)
            check(oSource.getValue() == sId, "Toolbar callback identity/value.");
            nActivated = nActivated + 1;
        end});
    oToolbar.layout(12, 12, 600, 48);
    oToolbar.on("leftClick", function()
        nClicked = nClicked + 1;
    end);
    local oStatus = _Controls.statusBar(oPanel, {Skin = oSkin, Items = {
        {Id = "a", Text = "Ready", Weight = 1}, {Id = "b", Text = "Working", Weight = 2},
        {Id = "fixed", Text = "Fixed", Width = 100},
    }});
    oStatus.layout(12, 80, 600, 42);
    local nChanges, nPreview = 0, 0;
    local oPicker = _Controls.colorPicker(oPanel, {Skin = oSkin, Value = {R = 10, G = 20, B = 30, A = 100},
        OnChange = function(tValue, oSource)
            check(tValue.A == oSource.getValue().A, "Color callback identity/alpha.");
            nChanges = nChanges + 1;
        end});
    oPicker.on("previewChanged", function()
        nPreview = nPreview + 1;
    end);
    oPicker.layout(12, 150, 260, 44);
    oFrame:Show(true);
    _wx.wxYield();
    for sKind, oComponent in pairs({Toolbar = oToolbar, StatusBar = oStatus, ColorPicker = oPicker}) do
        check(next(oComponent) == nil and getmetatable(oComponent) == "wxLuma.UI."..sKind,
            "Actual/decoy identity: "..sKind);
    end
    local tToolbarLayout = oToolbar.getLayout();
    check(#tToolbarLayout.Overflow > 0 and tToolbarLayout.Entries[#tToolbarLayout.Entries].Id == "__more",
        "Toolbar reserves a final overflow button.");
    for _, tRect in ipairs(tToolbarLayout.Entries) do
        check(tRect.X >= 0 and tRect.X + tRect.Width <= 600, "Visible tools remain in bounds.");
    end
    click(oToolbar.Control, 20, 20);
    check(nClicked == 1 and nActivated == 1, "Native click activates and notifies generic listeners.");
    check(oToolbar.activateItem("toggle") and oToolbar.getSelected()[1] == "toggle", "Toggle selection.");
    check(not oToolbar.activateItem("disabled") and not oToolbar.activateItem("sep"), "Disabled/separator do not activate.");
    oToolbar.setSelected({});
    check(#oToolbar.getSelected() == 0, "Selected IDs always an array.");
    check(not pcall(oToolbar.setSelected, {"one"}), "Only toggles may be selected.");
    local tCopy = oToolbar.getItems();
    tCopy[1].Text = "Changed outside";
    check(oToolbar.getItems()[1].Text == "Attack", "Toolbar descriptors are copies.");
    check(not pcall(oToolbar.addItem, {Id = "one"}), "Duplicate ID rejected atomically.");
    oToolbar.addItem({Id = "added", Text = "Added"}, 2, true);
    check(oToolbar.getItems()[2].Id == "added", "Insert at runtime.");
    oToolbar.removeItem("added", true);
    oToolbar.setItem("one", {Text = "Strike"}, true);
    check(oToolbar.getItems()[1].Text == "Strike", "Patch existing command.");
    oToolbar.layout(12, 12, 160, 48);
    check(oToolbar.openOverflow(), "Contained overflow menu opens.");
    check(oToolbar.OverflowMenu.activateItem("toggle"), "Overflow command returns through shared activation.");
    check(oToolbar.getSelected()[1] == "toggle", "Overflow preserves toggle behavior.");
    oToolbar.layout(12, 12, 600, 48);
    key(oToolbar.Control, _wx.WXK_HOME);
    key(oToolbar.Control, _wx.WXK_RETURN);
    check(oToolbar.getValue() == "one", "Keyboard activates focused command.");
    oToolbar.setEnabled(false);
    check(not oToolbar.openOverflow() and not oToolbar.activateItem("one"), "Disabled toolbar.");
    oToolbar.setEnabled(true);
    local tRects = oStatus.getLayout();
    check(tRects[1].Width == 166 and tRects[2].Width == 334 and tRects[3].Width == 100,
        "Weighted sections distribute all remaining pixels.");
    local oHost = oStatus.getSection("b");
    local oChild = _Controls.toggleButton(oHost, {Skin = oSkin, Text = "Hosted"});
    oChild.layout(2, 2, 130, 30);
    oStatus.setItem("a", {Text = "Updated"}, true);
    check(oStatus.getSection("b"):GetId() == oHost:GetId(), "Matching section retains its host.");
    oStatus.addItem({Id = "new", Text = "New"});
    oStatus.removeItem("new");
    check(#oStatus.getItems() == 3, "Status sections add/remove at runtime.");
    check(not pcall(oStatus.setItems, {{Id = "bad", Weight = 0}}), "Invalid weight rejected.");
    check(#oStatus.getItems() == 3, "Invalid status edit is atomic.");
    oStatus.layout(12, 80, 60, 42);
    for _, tRect in ipairs(oStatus.getLayout()) do
        check(tRect.Width >= 0 and tRect.X + tRect.Width <= 60, "Narrow section clipping is nonnegative.");
    end
    check(not oHost:IsShown(), "Zero-width hosted section hides.");
    oStatus.layout(12, 80, 600, 42);
    oStatus.setEnabled(false);
    check(not oHost:IsEnabled(), "Disabled status host propagates input policy.");
    oStatus.setEnabled(true);

    -- Pure conversions cover chromatic/gray/black boundaries and byte rounding.
    for nR = 0, 255, 51 do
        for nG = 0, 255, 51 do
            for nB = 0, 255, 51 do
                local tRGBA = {R = nR, G = nG, B = nB, A = 73};
                local tRound = _Color.fromHSV(_Color.hsv(tRGBA));
                check(tRound.R == nR and tRound.G == nG and tRound.B == nB and tRound.A == 73,
                    "RGB/HSV roundtrip.");
            end
        end
    end
    local tColor = oPicker.getValue();
    tColor.R = 255;
    check(oPicker.getValue().R == 10, "Color getter returns independent data.");
    oPicker.setValue({R = 10, G = 20, B = 30, A = 100}, true);
    check(nChanges == 0, "Identical color does not notify.");
    check(not pcall(oPicker.setValue, {R = -1, G = 2, B = 3}), "Invalid RGBA rejected.");
    check(oPicker.getValue().R == 10, "Invalid RGBA preserves value.");
    oPicker.setHSV({H = 120, S = 100, V = 100}, true);
    check(oPicker.getValue().G == 255 and oPicker.getValue().R == 0 and oPicker.getValue().A == 100,
        "HSV setter preserves alpha.");
    check(oPicker.open() and not oPicker.open(), "Color popup opens once.");
    key(oPicker.Editor.Control, _wx.WXK_END);
    check(oPicker.getPreview().R == 255 and oPicker.getValue().R == 0 and nPreview > 0, "Preview is independent of committed value.");
    key(oPicker.Popup, _wx.WXK_ESCAPE, _wx.wxEVT_CHAR_HOOK);
    check(not oPicker.isOpen() and oPicker.getValue().R == 0, "Escape cancels color preview.");
    oPicker.open();
    key(oPicker.Editor.Control, _wx.WXK_END);
    key(oPicker.Popup, _wx.WXK_RETURN, _wx.wxEVT_CHAR_HOOK);
    check(oPicker.getValue().R == 255 and not oPicker.isOpen(), "Enter applies preview.");
    oPicker.open();
    click(oPicker.Editor.Control, 100, 284 + 10);
    click(oPicker.Editor.Control, 160, 334);
    check(not oPicker.isOpen(), "Swatch and Apply pointer routing.");
    oPicker.open();
    key(oPicker.Editor.Control, _wx.WXK_HOME);
    local jDeactivate = _wx.wxActivateEvent(_wx.wxEVT_ACTIVATE, false, oPicker.Popup:GetId());
    jDeactivate:SetEventObject(oPicker.Popup);
    oPicker.Popup:GetEventHandler():ProcessEvent(jDeactivate);
    jDeactivate:delete();
    check(not oPicker.isOpen(), "Outside activation cancels popup.");
    oPicker.open();
    oPicker.Popup:Hide();
    check(not oPicker.isOpen(), "Native hiding resets popup state.");
    local tPalette = oPicker.getSwatches();
    tPalette[1].R = 4;
    check(oPicker.getSwatches()[1].R ~= 4, "Swatches are copied.");
    oPicker.setSwatches({{R = 1, G = 2, B = 3, A = 4}}, true);
    check(#oPicker.getSwatches() == 1 and oPicker.getSwatches()[1].A == 4, "Runtime swatches retain alpha.");
    oPicker.setEnabled(false);
    check(not oPicker.open(), "Disabled color picker stays closed.");
    oPicker.setEnabled(true);
    local oSmall = _wx.wxPanel(oPanel, _wx.wxID_ANY, _wx.wxPoint(400, 150), _wx.wxSize(120, 100));
    local oContained = _Controls.colorPicker(oSmall, {Skin = oSkin});
    oContained.layout(4, 4, 100, 40);
    oContained.setContainment(oSmall);
    check(not oContained.open(), "Oversized popup follows default hide policy.");
    oContained.setContainmentOverflow("allow");
    check(oContained.open(), "Explicit allow preserves oversized popup.");
    local nPopupWidth, nPopupHeight = oContained.Popup:GetClientSizeWH();
    check(nPopupWidth == 360 and nPopupHeight == 360, "Containment never resizes the color editor.");
    oContained.close(false, false);
    oContained.destroy();

    oPicker.layout(700, 680, 80, 44);
    check(oPicker.open(), "Color editor opens near the bottom-right containment corner.");
    local tBounds = oPicker.getContainmentBounds();
    local nPlacedX, nPlacedY = oPicker.Popup:GetPositionXY();
    check(nPlacedX == tBounds.X + tBounds.Width - 360 and nPlacedY == tBounds.Y + tBounds.Height - 360,
        "Overflowing popup axes move by only the required distance.");
    oPicker.Control:Hide();
    check(not oPicker.isOpen(), "Hiding the picker cancels its preview editor.");
    oPicker.Control:Show(true);
    oPicker.layout(12, 150, 260, 44);

    -- Verify every new object actually honors its own skin palette. This
    -- deliberately conspicuous skin must not affect the original instances.
    local oMarkerColor = _wx.wxColour(210, 40, 170);
    local oMarkerBitmap = _wx.wxBitmap(1, 1);
    local oMarkerDC = _wx.wxMemoryDC();
    local oMarkerBrush = _wx.wxBrush(oMarkerColor);
    oMarkerDC:SelectObject(oMarkerBitmap);
    oMarkerDC:SetBackground(oMarkerBrush);
    oMarkerDC:Clear();
    oMarkerDC:SelectObject(_wx.wxNullBitmap);
    oMarkerDC:delete();
    local tCustomSkin = {
        Font = oSkin.Font,
        getBitmap = function()
            return oMarkerBitmap;
        end,
        draw = function(oDrawDC, sName, nX, nY, nWidth, nHeight)
            oDrawDC:SetPen(_wx.wxTRANSPARENT_PEN);
            oDrawDC:SetBrush(oMarkerBrush);
            oDrawDC:DrawRectangle(nX, nY, nWidth or 32, nHeight or 32);
        end,
    };
    tCustomSkin.drawOpaque = tCustomSkin.draw;
    tCustomSkin.text = function(oDrawDC, sText, nX, nY)
        oDrawDC:SetFont(oSkin.Font);
        oDrawDC:SetTextForeground(oMarkerColor);
        oDrawDC:DrawText(sText, nX, nY);
    end;
    for _, fFactory in ipairs({_Controls.toolbar, _Controls.statusBar, _Controls.colorPicker}) do
        local oCustom = fFactory(oPanel, {Skin = tCustomSkin});
        oCustom.layout(12, 600, 240, 44);
        local oSample = _wx.wxBitmap(240, 44);
        local oSampleDC = _wx.wxMemoryDC();
        oSampleDC:SelectObject(oSample);
        oCustom.draw(oSampleDC, 240, 44);
        oSampleDC:SelectObject(_wx.wxNullBitmap);
        if (oCustom.Kind == "Toolbar") then
            oCustom.setItems({{Id = "wide", Width = 400}, {Id = "other", Width = 400}});
            check(oCustom.openOverflow(), "Custom-skinned overflow opens through the shared menu engine.");
            local tLayout = oCustom.OverflowMenu.getLayout();
            local oOverflowBitmap = _wx.wxBitmap(tLayout.Width, tLayout.Height);
            local oOverflowDC = _wx.wxMemoryDC();
            oOverflowDC:SelectObject(oOverflowBitmap);
            oCustom.OverflowMenu.draw(oOverflowDC, tLayout.Width, tLayout.Height);
            oOverflowDC:SelectObject(_wx.wxNullBitmap);
            local oOverflowImage = oOverflowBitmap:ConvertToImage();
            check(oOverflowImage:GetRed(1, 1) == 210 and oOverflowImage:GetGreen(1, 1) == 40,
                "Overflow chrome uses the toolbar skin, including text/palette rendering.");
            oOverflowImage:delete();
            oOverflowDC:delete();
            oOverflowBitmap:delete();
            oCustom.OverflowMenu.close();
        end
        local oSampleImage = oSample:ConvertToImage();
        check(oCustom.Skin == tCustomSkin and oSampleImage:GetRed(1, 1) == 210
            and oSampleImage:GetGreen(1, 1) == 40 and oSampleImage:GetBlue(1, 1) == 170,
            "Per-object skin drives the new object's rendered background.");
        oSampleImage:delete();
        oSampleDC:delete();
        oSample:delete();
        oCustom.destroy();
    end
    oMarkerBrush:delete();
    oMarkerBitmap:delete();
    oMarkerColor:delete();
    check(oToolbar.Skin == oSkin and oStatus.Skin == oSkin and oPicker.Skin == oSkin,
        "Per-object skin override leaves other instances alone.");

    check(not pcall(oToolbar.setItems, {[1] = {Id = "x"}, [3] = {Id = "z"}}), "Sparse toolbar data rejected.");
    check(not pcall(oStatus.setItems, {[1] = {Id = "x"}, [3] = {Id = "z"}}), "Sparse status data rejected.");
    check(not pcall(oPicker.setSwatches, {[1] = {R = 0, G = 0, B = 0}, [3] = {R = 1, G = 1, B = 1}}),
        "Sparse palette rejected.");
    oStatus.setItems({{Id = "a", Weight = 1e308}, {Id = "b", Weight = 1e308}});
    oStatus.layout(12, 80, 600, 42);
    check(oStatus.getLayout()[1].Width == 300 and oStatus.getLayout()[2].Width == 300,
        "Large finite weights retain proportional allocation without overflow.");
    oStatus.setItems({{Id = "a", Text = "Ready", Weight = 2},
        {Id = "b", Text = "Working", Weight = 1}, {Id = "fixed", Text = "Fixed", Width = 100}});
    oPicker.setSwatches({{R = 255, G = 255, B = 255}, {R = 0, G = 0, B = 0},
        {R = 220, G = 60, B = 60}, {R = 60, G = 190, B = 90}, {R = 60, G = 120, B = 230},
        {R = 240, G = 200, B = 60}, {R = 160, G = 80, B = 220}, {R = 0, G = 0, B = 0, A = 0}});
    oPicker.setValue({R = 65, G = 140, B = 210, A = 190});
    oPicker.open();
    oPicker.close(false, false);
    -- Compose production draw methods for visual QA, with no desktop screenshot.
    local oBitmap = _wx.wxBitmap(760, 580);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oDC:SetBackground(oBrush);
    oDC:Clear();
    oToolbar.layout(12, 12, 728, 48);
    oDC:SetDeviceOrigin(16, 16);
    oToolbar.draw(oDC, 728, 48);
    oDC:SetDeviceOrigin(16, 82);
    oStatus.draw(oDC, 600, 42);
    oDC:SetDeviceOrigin(16, 150);
    oPicker.draw(oDC, 260, 44);
    oDC:SetDeviceOrigin(380, 150);
    oPicker.Editor.draw(oDC, 360, 360);
    oDC:SetDeviceOrigin(0, 0);
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    check(oImage:SaveFile(APP_PATH.."/Scripts/Tests/ToolsPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save production preview.");
    oImage:delete();
    oDC:delete();
    oBrush:delete();
    oBitmap:delete();
    oChild.destroy();
    for _, oComponent in ipairs({oToolbar, oStatus, oPicker}) do
        oComponent.destroy();
        oComponent.destroy();
        check(oComponent.Disposed, "New object disposal is idempotent.");
    end
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();
    local tWorkbench = require("Tests.UI")(_wx.NULL);
    check(#tWorkbench.Widgets.Tabs.Pages == 10, "Tools workbench category added.");
    tWorkbench.Widgets.Tabs.setValue(10);
    tWorkbench.Layout();
    _wx.wxYield();
    check(tWorkbench.Widgets.Toolbar and tWorkbench.Widgets.StatusBar and tWorkbench.Widgets.ColorPicker,
        "Every new object has a workbench example.");
    tWorkbench.Frame:Close();
    _wx.wxYield();
    collectgarbage("collect");
end

local bOK, sError = xpcall(run, debug.traceback);
if (not bOK) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end
print("Tools regression: ".._nChecks.." checks passed.");
