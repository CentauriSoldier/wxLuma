--[[!
@fqxn wxLuma.Tests.TabsRegression
@desc Verifies dynamic page identity, measured wrapping/scrolling, all header
    edges, disabled tabs, native events, skin overrides and workbench layout.
!]]
APP_PATH = assert(arg[1], "Pass export root.");
package.path = APP_PATH.."/Scripts/?.lua;"..APP_PATH.."/Scripts/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _Controls = require("UI.Controls");
local _Layout   = require("UI.Core.TabLayout");
local _nChecks  = 0;
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.TabsRegression.check
@desc Counts a behavioral assertion and labels failures.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.TabsRegression.click
@desc Dispatches native mouse callbacks with supplied coordinates, without OS input.
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
@fqxn wxLuma.Tests.TabsRegression.key
@desc Tests actual native keyboard handlers including the parent shortcut hook.
!]]
local function key(oTarget, nKey, bCommand, bShift)
    local jEvent = _wx.wxKeyEvent(bCommand and _wx.wxEVT_CHAR_HOOK or _wx.wxEVT_KEY_DOWN);
    jEvent.GetKeyCode = function()
        return nKey;
    end;
    jEvent.ControlDown = function()
        return bCommand == true;
    end;
    jEvent.ShiftDown = function()
        return bShift == true;
    end;
    jEvent:SetId(oTarget:GetId());
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.TabsRegression.run
@desc Exercises pure geometry and production native objects, then renders previews.
!]]
local function run()
    for _, sPosition in ipairs({"top", "bottom", "left", "right"}) do
        for _, sMode in ipairs({"wrap", "scroll"}) do
            for _, tSize in ipairs({{800, 500}, {320, 200}, {80, 80}}) do
                local tPlan = _Layout.compute({120, 160, 100, 140, 90, 200}, tSize[1], tSize[2], sMode, sPosition, 0, 6);
                check(tPlan.Page.Width >= 1 and tPlan.Page.Height >= 1, "Positive content geometry.");
                for _, tEntry in ipairs(tPlan.Entries) do
                    check(tEntry.Width > 0 and tEntry.Height > 0 and tEntry.X >= 0 and tEntry.Y >= 0
                        and tEntry.X + tEntry.Width <= tSize[1] and tEntry.Y + tEntry.Height <= tSize[2],
                        "Clipped headers remain inside client bounds.");
                end
                if (tPlan.Mode == "scroll") then
                    local bFound = false;
                    for _, tEntry in ipairs(tPlan.Entries) do
                        bFound = bFound or tEntry.Index == 6;
                    end
                    check(bFound, "Selected header is visible in scrolling layout.");
                end
            end
        end
    end
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Tabs regression", _wx.wxDefaultPosition, _wx.wxSize(900, 700));
    local oSpacer = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    oSpacer:Hide();
    local nChanges, nEvents, nClicks = 0, 0, 0;
    local oTabs = _Controls.tabs(oFrame, {Skin = oSkin, Items = {
        {Id = "one", Text = "First page"},
        {Id = "two", Text = "Second page with image", Image = APP_PATH.."/Images/UI/Menu/Command Shield.png"},
        {Id = "disabled", Text = "Disabled", Enabled = false},
        {Id = "four", Text = "Fourth page"},
    }, OnChange = function(nValue, oSource)
        check(oSource.getValue() == nValue, "Tabs callback identity/value.");
        nChanges = nChanges + 1;
    end});
    oTabs.on("selectionChanged", function(oSource, tEvent)
        local tItem = oSource.getItems()[tEvent.Value];
        check(oSource == tEvent.Source and (tItem and tItem.Id or nil) == tEvent.Id,
            "Selection event carries stable ID, or nil for no selection.");
        nEvents = nEvents + 1;
    end);
    oTabs.on("leftClick", function()
        nClicks = nClicks + 1;
    end);
    oTabs.layout(12, 12, 480, 500);
    oFrame:Show(true);
    _wx.wxYield();
    check(next(oTabs) == nil and getmetatable(oTabs) == "wxLuma.UI.Tabs", "Tabs actual/decoy identity.");
    check(oTabs.Items[1] == "First page" and #oTabs.Pages == 4 and oTabs.getValue() == 1,
        "Legacy captions/pages/numeric value API remains available.");
    local tPlan = oTabs.getLayout();
    check(#tPlan.Entries == 4 and tPlan.Page.Y > 40, "Measured captions wrap into more than one row.");
    local tSecond = tPlan.Entries[2];
    click(oTabs.Control, tSecond.X + tSecond.Width / 2, tSecond.Y + tSecond.Height / 2);
    check(oTabs.getValue() == 2 and nChanges == 1 and nEvents == 1 and nClicks == 1,
        "Native click selects and publishes generic/semantic events.");
    local oSecond = oTabs.getPage("two");
    local oChild = _Controls.textfield(oSecond, {Skin = oSkin, Value = "Preserved content"});
    oChild.layout(16, 16, 220, 40);
    oTabs.setItem("two", {Text = "Renamed page"}, true);
    check(oTabs.getPage("two"):GetId() == oSecond:GetId() and oChild.getValue() == "Preserved content",
        "Rename retains native page and application controls.");
    oTabs.moveItem("two", 1, true);
    check(oTabs.getValue() == 1 and oTabs.getPage(1):GetId() == oSecond:GetId(), "Reordering preserves selected page identity.");
    oTabs.addItem({Id = "inserted", Text = "Inserted"}, 1, true);
    check(oTabs.getValue() == 2 and oTabs.getPage(2):GetId() == oSecond:GetId(), "Insert preserves selected ID while index shifts.");
    oTabs.removeItem("inserted", true);
    check(oTabs.getValue() == 1, "Removing sibling preserves selected ID.");
    check(not pcall(oTabs.setValue, "disabled"), "Disabled tab cannot be selected.");
    oTabs.setValue("one");
    key(oTabs.Control, _wx.WXK_RIGHT);
    check(oTabs.getItems()[oTabs.getValue()].Id == "four", "Arrow navigation skips disabled tabs.");
    key(oTabs.Control, _wx.WXK_HOME);
    check(oTabs.getItems()[oTabs.getValue()].Id == "two", "Home selects first enabled tab.");
    key(oTabs.Control, _wx.WXK_TAB, true, false);
    check(oTabs.getItems()[oTabs.getValue()].Id == "one", "Ctrl/Cmd+Tab shortcut advances.");
    key(oTabs.Control, _wx.WXK_TAB, true, true);
    check(oTabs.getItems()[oTabs.getValue()].Id == "two", "Ctrl/Cmd+Shift+Tab reverses.");
    local nBefore = nChanges;
    oTabs.setValue(oTabs.getValue(), true);
    check(nChanges == nBefore, "Identical selection does not notify.");
    oTabs.setEnabled(false);
    check(not oTabs.handleKey("down", _wx.WXK_RIGHT) and not oSecond:IsEnabled(), "Disabled tabs propagate to pages.");
    oTabs.setEnabled(true);
    local tCopy = oTabs.getItems();
    tCopy[1].Text = "External edit";
    check(oTabs.getItems()[1].Text == "Renamed page", "Descriptor copies are independent.");
    check(not pcall(oTabs.setItems, {{Id = "x"}, {Id = "x"}}), "Duplicate IDs rejected atomically.");
    check(not pcall(oTabs.setItems, {[1] = "one", [3] = "three"}), "Sparse arrays rejected.");
    check(oTabs.getPage("two"):GetId() == oSecond:GetId(), "Failed mutation preserves live pages.");
    oTabs.setItem("two", {Enabled = false}, true);
    check(oTabs.getValue() > 0 and oTabs.getItems()[oTabs.getValue()].Enabled, "Disabling selection chooses enabled neighbor.");
    oTabs.setItem("two", {Enabled = true});
    local tMany = {};
    for nIndex = 1, 24 do
        tMany[nIndex] = {Id = "many"..nIndex, Text = "Example page "..nIndex};
    end
    oTabs.setItems(tMany);
    _wx.wxYield();
    check(oChild.Disposed, "Removing a page runs its child components' native-destruction lifecycle.");
    oTabs.setLayoutMode("scroll", true);
    oTabs.setValue(24);
    tPlan = oTabs.getLayout();
    check(tPlan.Offset > 0 and tPlan.Entries[#tPlan.Entries].Index == 24, "Selecting offscreen tab scrolls it into view.");
    local nSelected = oTabs.getValue();
    oTabs.scrollBy(-100000);
    check(oTabs.getLayout().Offset == 0 and oTabs.getValue() == nSelected, "Manual scrolling preserves page selection.");
    oTabs.setValue(24);
    check(oTabs.getLayout().Offset > 0, "Reselecting hidden current tab reveals its header.");
    for _, sPosition in ipairs({"top", "bottom", "left", "right"}) do
        oTabs.setPosition(sPosition, true);
        tPlan = oTabs.getLayout();
        check(oTabs.getPosition() == sPosition and oTabs.getPage(24):IsShown(), "Placement preserves page selection.");
        local nX, nY = oTabs.getPage(24):GetPositionXY();
        check(nX == tPlan.Page.X and nY == tPlan.Page.Y, "Native content follows computed bounds.");
    end
    oTabs.setPosition("top");
    oTabs.setLayoutMode("wrap");
    oTabs.layout(12, 12, 300, 140);
    check(oTabs.getLayout().Mode == "scroll", "Overfull wrapping falls back before consuming the page.");
    oTabs.setItems({{Id = "off", Text = "Unavailable", Enabled = false}});
    check(oTabs.getValue() == 0 and not oTabs.Pages[1]:IsShown(), "All-disabled set has no selected page.");
    oTabs.setValue(0);
    oTabs.setItems({});
    check(oTabs.getValue() == 0 and #oTabs.Pages == 0, "Empty tabs remain usable.");
    oTabs.addItem("First new page");
    check(oTabs.getValue() == 1 and #oTabs.Pages == 1, "Adding first page selects it.");
    oTabs.removeItem(1, true);
    check(oTabs.getValue() == 0, "Removing final page restores empty state.");

    -- Per-object palette sampling applies to both headers and native page hosts.
    local oColor = _wx.wxColour(210, 40, 170);
    local oBrush = _wx.wxBrush(oColor);
    local oToken = _wx.wxBitmap(1, 1);
    local oTokenDC = _wx.wxMemoryDC();
    oTokenDC:SelectObject(oToken);
    oTokenDC:SetBackground(oBrush);
    oTokenDC:Clear();
    oTokenDC:SelectObject(_wx.wxNullBitmap);
    oTokenDC:delete();
    local tSkin = {Font = oSkin.Font, getBitmap = function()
        return oToken;
    end, draw = function(oDC, sName, nX, nY, nWidth, nHeight)
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:SetBrush(oBrush);
        oDC:DrawRectangle(nX, nY, nWidth, nHeight);
    end};
    local oCustom = _Controls.tabs(oFrame, {Skin = tSkin, Items = {"Custom"}});
    oCustom.layout(520, 12, 300, 140);
    check(oCustom.Pages[1]:GetBackgroundColour():Red() == 210, "Native page background uses its own skin palette.");
    local oCustomBitmap = _wx.wxBitmap(300, 140);
    local oCustomDC = _wx.wxMemoryDC();
    oCustomDC:SelectObject(oCustomBitmap);
    oCustom.draw(oCustomDC, 300, 140);
    oCustomDC:SelectObject(_wx.wxNullBitmap);
    local oCustomImage = oCustomBitmap:ConvertToImage();
    check(oCustomImage:GetRed(1, 1) == 210 and oCustomImage:GetGreen(1, 1) == 40
        and oCustomImage:GetBlue(1, 1) == 170, "Header surface rendering honors the object's own Skin.");
    oCustomImage:delete();
    oCustomDC:delete();
    oCustomBitmap:delete();
    oCustom.destroy();
    oBrush:delete();
    oToken:delete();
    oColor:delete();
    check(not pcall(_Controls.tabs, oFrame, {Skin = oSkin, Items = {"Bad"}, LayoutMode = false}),
        "Invalid typed layout option rejected.");
    local oReentrant = _Controls.tabs(oFrame, {Skin = oSkin, Items = {"First", "Second"}});
    oReentrant.layout(12, 540, 320, 100);
    oReentrant.on("itemHovered", function()
        oReentrant.setItems({});
    end);
    oReentrant.handlePointer("move", 10, 10);
    check(#oReentrant.Pages == 0, "A hover callback may replace tabs without stale index access.");
    oReentrant.destroy();
    oTabs.destroy();
    oTabs.destroy();
    check(oTabs.Disposed, "Tabs disposal is idempotent.");
    oFrame:Destroy();
    _wx.wxYield();
    oSkin.destroy();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    _wx.wxYield();
    local oWorkbenchTabs = tWorkbench.Widgets.Tabs;
    check(#oWorkbenchTabs.Pages == 11 and #oWorkbenchTabs.getLayout().Entries == 11,
        "All workbench categories are visible without equal-width clipping.");
    local oDC = _wx.wxClientDC(oWorkbenchTabs.Control);
    oDC:SetFont(tWorkbench.Skin.Font);
    for _, tEntry in ipairs(oWorkbenchTabs.getLayout().Entries) do
        local nTextWidth = oDC:GetTextExtent(oWorkbenchTabs.Items[tEntry.Index]);
        check(tEntry.Width >= nTextWidth + 28, "Workbench captions retain measured text width.");
    end
    oDC:delete();
    tWorkbench.Frame:SetClientSize(_wx.wxSize(920, 780));
    tWorkbench.Layout();
    _wx.wxYield();
    check(#oWorkbenchTabs.getLayout().Entries == 11, "All categories fit at minimum workbench size.");
    oWorkbenchTabs.setValue(11);
    tWorkbench.Layout();
    local oExample = tWorkbench.Widgets.ExampleTabs;
    local oExamplePage = oExample.getPage(1);
    oExample.moveItem(1, 4);
    check(oExample.getPage(4):GetId() == oExamplePage:GetId(), "Workbench example demonstrates stable page moves.");
    oExample.setPosition("left");
    oExample.setLayoutMode("scroll");
    oExample.setValue(4);

    click(tWorkbench.Widgets.TabsRemove.Control, 10, 10);
    _wx.wxYield();
    oWorkbenchTabs.setValue(1);
    tWorkbench.Layout();
    click(tWorkbench.Widgets.Toggle.Control, 10, 10);
    click(tWorkbench.Widgets.Toggle.Control, 10, 10);
    check(tWorkbench.Widgets.ExampleTabs.isEnabled(), "Global enable switch skips disposed children of removed example pages.");
    oWorkbenchTabs.setValue(11);
    tWorkbench.Layout();
    -- Reproducible production header rendering, independent of OS screenshots.
    local oPreview = _wx.wxBitmap(820, 480);
    local oPreviewDC = _wx.wxMemoryDC();
    local oPreviewBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oPreviewDC:SelectObject(oPreview);
    oPreviewDC:SetBackground(oPreviewBrush);
    oPreviewDC:Clear();
    oPreviewDC:SetDeviceOrigin(12, 12);
    local nOuterWidth, nOuterHeight = oWorkbenchTabs.Control:GetClientSizeWH();
    oWorkbenchTabs.draw(oPreviewDC, math.min(796, nOuterWidth), math.min(450, nOuterHeight));
    oPreviewDC:SetDeviceOrigin(12, 140);
    local nExampleWidth, nExampleHeight = oExample.Control:GetClientSizeWH();
    oExample.draw(oPreviewDC, nExampleWidth, math.min(320, nExampleHeight));
    oPreviewDC:SetDeviceOrigin(0, 0);
    oPreviewDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oPreview:ConvertToImage();
    check(oImage:SaveFile(APP_PATH.."/Scripts/Tests/TabsPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save production Tabs preview.");
    oImage:delete();
    oPreviewDC:delete();
    oPreview:delete();
    oPreviewBrush:delete();
    tWorkbench.Frame:Close();
    _wx.wxYield();
    collectgarbage("collect");
end

local bOK, sError = xpcall(run, debug.traceback);
if (not bOK) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end
print("Tabs regression: ".._nChecks.." checks passed.");
