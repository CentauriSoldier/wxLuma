--[[!
@fqxn wxLuma.Tests.MenuRegression
@desc Verifies measured radial spacing, overflow reachability, nested Back paths,
    context rows, containment, outside dismissal/reset, attachment lifetime, image
    masks, native events, callback reentrancy and workbench menu examples.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua";
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx       = require("wx");
local _pFramework = require("wxLuma")().Config.ImagePath;
local _Controls = require("wxLuma.Controls");
local _Renderer = require("wxLuma.Core.MenuRenderer");
local _nChecks = 0;
local _tFixtures = {};
_wx.wxGetApp():SetExitOnFrameDelete(false);

--[[!
@fqxn wxLuma.Tests.MenuRegression.check
@desc Counts assertions and identifies the failing contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.MenuRegression.ids
@desc Returns a stable page signature, including Back and More.
!]]
local function ids(tLayout)
    local tIds = {};

    for nIndex, tEntry in ipairs(tLayout.Entries) do
        tIds[nIndex] = tEntry.Id;
    end

    return table.concat(tIds, ",");
end

--[[!
@fqxn wxLuma.Tests.MenuRegression.verifyLayout
@desc Checks radius bounds, actual pixel-space footprint spacing and More ordering.
!]]
local function verifyLayout(oMenu)
    local tLayout = oMenu.getLayout();
    local nMin, nMax = oMenu.getRadiusRange();
    check(tLayout.Radius >= nMin and tLayout.Radius <= nMax, "Radius stays within configured bounds.");

    for nIndex, tLeft in ipairs(tLayout.Entries) do
        check(tLeft.X >= 0 and tLeft.Y >= 0 and tLeft.X + tLeft.Width <= tLayout.Width
            and tLeft.Y + tLeft.Height <= tLayout.Height, "Complete footprint stays inside popup.");

        if (tLeft.Role == "overflow") then
            check(nIndex == #tLayout.Entries, "Overflow is the last button.");
        end

        for nOther = nIndex + 1, #tLayout.Entries do
            local tRight = tLayout.Entries[nOther];
            local nDX = math.max(tLeft.X - tRight.X - tRight.Width, tRight.X - tLeft.X - tLeft.Width);
            local nDY = math.max(tLeft.Y - tRight.Y - tRight.Height, tRight.Y - tLeft.Y - tLeft.Height);
            check((nDX >= 0 or nDY >= 0)
                and math.max(0, nDX)^2 + math.max(0, nDY)^2 >= oMenu.getSpacing()^2,
                "All item pairs retain the requested edge spacing.");
        end
    end

    if (tLayout.Depth > 0) then
        check(tLayout.Entries[1].Role == "back", "Every non-root page begins with Back.");
    end

    return tLayout;
end

--[[!
@fqxn wxLuma.Tests.MenuRegression.contextEvent
@desc Dispatches the actual attachment callback type with screen coordinates.
!]]
local function contextEvent(oTarget, nX, nY)
    local jEvent = _wx.wxContextMenuEvent(_wx.wxEVT_CONTEXT_MENU, oTarget:GetId());
    jEvent.GetPosition = function()
        return _wx.wxPoint(nX, nY);
    end;
    jEvent:SetEventObject(oTarget);
    oTarget:GetEventHandler():ProcessEvent(jEvent);
    jEvent:delete();
end

--[[!
@fqxn wxLuma.Tests.MenuRegression.click
@desc Dispatches native left-button callbacks at an object's local coordinates.
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
@fqxn wxLuma.Tests.MenuRegression.run
@desc Uses owned native fixtures, production drawing and real popup windows.
!]]
local function run()
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Menu regression",
        _wx.wxDefaultPosition, _wx.wxSize(980, 780));
    local oHost = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local oSpacer = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    oHost:SetSize(20, 20, 650, 620);
    oSpacer:SetSize(900, 700, 1, 1);
    local oTarget = _wx.wxButton(oHost, _wx.wxID_ANY, "Target");
    oTarget:SetSize(260, 280, 120, 40);
    oFrame:Show();
    _wx.wxYield();
    local tValue = {Command = "chosen"};
    local tChildren = {{Id = "deep", Text = "Deep", Items = {{Id = "deep-action", Text = "Act", Value = tValue}}}};

    for nIndex = 1, 24 do
        tChildren[#tChildren + 1] = {Id = "child-"..nIndex, Text = "C"..nIndex};
    end

    local tItems = {
        {Id = "submenu", Text = "Build", Items = tChildren},
        {Id = "disabled", Text = "Locked", Enabled = false},
        {Id = "wide", Text = "Wide", Shape = "diamond", Width = 80, Height = 64}
    };

    for nIndex = 1, 29 do
        tItems[#tItems + 1] = {Id = "root-"..nIndex, Text = "R"..nIndex,
            Shape = ({"circle", "diamond", "square"})[(nIndex - 1) % 3 + 1], Value = nIndex};
    end

    local nSelected = 0;
    local oRadial = _Controls.radialMenu(oHost, {Skin = oSkin, Items = tItems,
        MinRadius = 50, MaxRadius = 132, Spacing = 12,
        OnSelect = function(tSelection, oSource)
            check(not oSource.isOpen(), "Actions close before OnSelect.");
            check(oSource.getLayout().Depth == 0, "Action closes and resets navigation immediately.");
            check(tSelection.Id == "deep-action" and tSelection.Value == tValue, "Selection preserves ID and application identity.");
            check(table.concat(tSelection.Path, "/") == "submenu/deep/deep-action", "Selection path excludes navigation controls.");
            nSelected = nSelected + 1;
        end});
    local oContext = _Controls.contextMenu(oHost, {Skin = oSkin, Items = tItems});

    for _, oMenu in ipairs({oRadial, oContext}) do
        check(next(oMenu) == nil and getmetatable(oMenu) == "wxLuma.UI."..oMenu.Kind, "Menu has its own public proxy identity.");
        check(oMenu.getContainment():GetId() == oFrame:GetId(), "Default containment is topmost parent.");
        oMenu.setContainment(oHost);
    end

    check(oRadial.showAtObject(oTarget), "Programmatic radial opening.");
    _wx.wxYield();
    check(oRadial.isOpen(), "Native radial popup remains open after yielding.");
    local tFirst = verifyLayout(oRadial);
    check(tFirst.Entries[1].Y < tFirst.AnchorY, "Default start is above anchor.");
    check(tFirst.Entries[2].X + tFirst.Entries[2].Width / 2 > tFirst.AnchorX, "Default order proceeds clockwise.");
    local sRoot = ids(tFirst);
    local tSeen = {};
    local nPages = 0;

    while (true) do
        local tPage = verifyLayout(oRadial);
        nPages = nPages + 1;
        check(nPages < 40, "Overflow navigation makes forward progress.");
        local bMore = false;

        for _, tEntry in ipairs(tPage.Entries) do
            if (not tEntry.Role) then
                check(not tSeen[tEntry.Id], "No real item is repeated across overflow pages.");
                tSeen[tEntry.Id] = true;
            elseif (tEntry.Role == "overflow") then
                bMore = true;
            end
        end

        if (not bMore) then
            break;
        end

        check(oRadial.activateItem("__overflow"), "Every More button reaches a usable next page.");
    end

    check(nPages >= 3, "Large menu produces nested overflow pages.");
    for _, tItem in ipairs(tItems) do
        check(tSeen[tItem.Id], "Every root item remains reachable.");
    end
    while (oRadial.back()) do
        verifyLayout(oRadial);
    end
    check(ids(oRadial.getLayout()) == sRoot, "Back restores the original root page.");
    check(not oRadial.activateItem("disabled") and oRadial.isOpen(), "Disabled action cannot activate.");
    check(oRadial.activateItem("submenu"), "Opens submenu in the same ring.");
    verifyLayout(oRadial);
    check(oRadial.activateItem("__overflow"), "Submenu can overflow too.");
    verifyLayout(oRadial);
    check(oRadial.back() and oRadial.activateItem("deep"), "Back restores submenu before deeper navigation.");
    check(oRadial.getLayout().Entries[1].Role == "back", "Nested submenu has Back.");
    local bChosen, tChosen = oRadial.activateItem("deep-action");
    check(bChosen and tChosen.Id == "deep-action" and nSelected == 1, "Activation returns completed selection snapshot.");
    local tSelectionCopy = oRadial.getSelection();
    tSelectionCopy.Path[1] = "changed";
    check(oRadial.getSelection().Path[1] == "submenu", "Selection snapshot does not expose internal path.");
    check(oRadial.getValue() == "deep-action", "Scalar getter returns completed ID.");

    check(oRadial.showAtObject(oTarget) and oRadial.getSelection() == nil, "Opening resets previous selection.");
    oRadial.activateItem("submenu");
    oRadial.activateItem("__overflow");
    oRadial.handlePointer("down", 0, 0);
    check(not oRadial.isOpen() and oRadial.getLayout().Depth == 0
        and ids(oRadial.getLayout()) == sRoot, "Outside-gap click closes and resets to first menu.");
    oRadial.showAtObject(oTarget);
    oRadial.activateItem("submenu");
    oFrame:Raise();
    oTarget:SetFocus();
    _wx.wxYield();
    check(not oRadial.isOpen() and oRadial.getLayout().Depth == 0, "Native outside focus dismisses and resets submenu.");
    oRadial.showAtObject(oTarget);
    oRadial.activateItem("submenu");
    oRadial.handleKey("down", _wx.WXK_ESCAPE);
    check(oRadial.isOpen() and oRadial.getLayout().Depth == 0, "Escape first returns to root.");
    oRadial.handleKey("down", _wx.WXK_ESCAPE);
    check(not oRadial.isOpen(), "Escape at root closes.");

    oRadial.showAtObject(oTarget);
    local nAngleEvents = 0;
    oRadial.on("startAngleChanged", function()
        nAngleEvents = nAngleEvents + 1;
    end);
    oRadial.setStartAngle(90, true);
    oRadial.setStartAngle(450, true);
    local tRotated = verifyLayout(oRadial);
    check(nAngleEvents == 1 and tRotated.Entries[1].X > tRotated.AnchorX, "Runtime angle rotates ring; equivalent angle is silent.");
    oRadial.setStartAngle(0);
    oRadial.setDirection("CCW", true);
    tRotated = verifyLayout(oRadial);
    check(tRotated.Entries[2].X + tRotated.Entries[2].Width / 2 < tRotated.AnchorX, "Runtime CCW reverses placement.");
    oRadial.setSpacing(20, true);
    verifyLayout(oRadial);
    oRadial.setRadiusRange(70, 150, true);
    verifyLayout(oRadial);
    local nBeforeWidth, nBeforeHeight = oRadial.Popup:GetSizeWH();
    local tBounds = oRadial.getContainmentBounds();
    oRadial.setAnchor(tBounds.X + tBounds.Width + 200, tBounds.Y + tBounds.Height + 200);
    local nPopupX, nPopupY = oRadial.Popup:GetPositionXY();
    local nAfterWidth, nAfterHeight = oRadial.Popup:GetSizeWH();
    check(nBeforeWidth == nAfterWidth and nBeforeHeight == nAfterHeight, "Containment adjusts position only.");
    check(nPopupX >= tBounds.X and nPopupY >= tBounds.Y and nPopupX + nAfterWidth <= tBounds.X + tBounds.Width
        and nPopupY + nAfterHeight <= tBounds.Y + tBounds.Height, "Complete popup remains contained.");
    check(nPopupX == tBounds.X + tBounds.Width - nAfterWidth
        and nPopupY == tBounds.Y + tBounds.Height - nAfterHeight, "Containment applies minimum displacement on each axis.");
    check(not pcall(oRadial.setRadiusRange, 100, 50) and not pcall(oRadial.setStartAngle, math.huge), "Invalid runtime geometry rejected.");
    oRadial.close();
    local tSnapshot = oRadial.getItems();
    tSnapshot[1].Text = "Changed";
    check(oRadial.getItems()[1].Text == "Build", "Menu owns descriptor structure.");
    check(not pcall(oRadial.setItems, {{Id = "dup"}, {Id = "dup"}}), "Duplicate IDs rejected atomically.");
    check(#oRadial.getItems() == #tItems, "Invalid item replacement preserves hierarchy.");
    oRadial.setItem("wide", {Width = 96, Shape = "circle"}, true);
    check(oRadial.getItems()[3].Width == 96, "Runtime descriptor patch is applied.");
    oRadial.setShape("diamond", true);
    check(oRadial.getShape() == "diamond" and oRadial.getItems()[3].Shape == "circle", "Default shape preserves explicit overrides.");

    -- Context rows use the same hierarchy and selection semantics, with full-row
    -- rectangular hit areas instead of the radial shapes.
    check(oContext.showAtObject(oTarget), "Context menu programmatic opening.");
    check(oContext.getLayout().Entries[1].Shape == "rectangle", "Context rows expose rectangular geometry.");
    check(oContext.activateItem("submenu") and oContext.getLayout().Entries[1].Role == "back", "Context submenu includes Back.");
    oContext.handleKey("down", _wx.WXK_ESCAPE);
    check(oContext.getLayout().Depth == 0 and oContext.isOpen(), "Context Escape returns first page.");
    oContext.close();
    oContext.attach(oTarget);
    local oPoint = oTarget:ClientToScreen(_wx.wxPoint(30, 20));
    contextEvent(oTarget, oPoint:GetX(), oPoint:GetY());
    check(oContext.isOpen(), "Native right-click/context attachment opens menu.");
    oContext.close();
    oContext.detach(oTarget);
    contextEvent(oTarget, oPoint:GetX(), oPoint:GetY());
    check(not oContext.isOpen(), "Detached target no longer opens menu.");
    oContext.attach(oTarget);
    contextEvent(oTarget, -1, -1);
    check(oContext.isOpen(), "Keyboard context gesture opens at target center.");
    oContext.close();
    oContext.setEnabled(false);
    check(not oContext.showAtObject(oTarget), "Disabled menu cannot open.");
    oContext.setEnabled(true);

    local oImpossible = _Controls.radialMenu(oHost, {Skin = oSkin, Items = tItems,
        MinRadius = 0, MaxRadius = 10, ItemWidth = 64, ItemHeight = 64});
    local bFit, sReason = oImpossible.showAtObject(oTarget);
    check(not bFit and type(sReason) == "string" and not oImpossible.isOpen(), "Impossible layout fails clearly without resize or infinite overflow.");
    oImpossible.destroy();

    -- Known solid image proves clipping and overlap without depending on the
    -- theme's colours. The renderer itself is exercised through native DCs.
    local pFixture = assert(os.getenv("TEMP")).."/wxLuma-menu-mask-"..os.time()..".png";
    local oSolid = _wx.wxImage(32, 32);
    oSolid:SetRGB(_wx.wxRect(0, 0, 32, 32), 240, 200, 20);
    check(oSolid:SaveFile(pFixture, _wx.wxBITMAP_TYPE_PNG), "Write image-mask fixture.");
    _tFixtures[#_tFixtures + 1] = pFixture;
    oSolid:delete();
    local tRender = _Renderer.create(oSkin, "Menu", true);

    for _, sShape in ipairs({"circle", "diamond", "square"}) do
        local tItem = {Id = "mask-"..sShape, Text = "", Shape = sShape, Width = 80, Height = 80,
            ImageWidth = 80, ImageHeight = 80, Image = pFixture, ClipImage = true};
        local tEntry = {Item = tItem, X = 0, Y = 0, Width = 80, Height = 80};
        local oBitmap = _wx.wxBitmap(120, 120);
        local oDC = _wx.wxMemoryDC();
        local oBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
        oDC:SelectObject(oBitmap);
        oDC:SetBackground(oBrush);
        oDC:Clear();
        tRender.draw(oDC, tEntry, "Normal");
        oDC:SelectObject(_wx.wxNullBitmap);
        local oImage = oBitmap:ConvertToImage();
        check(oImage:GetRed(40, 40) == 240 and oImage:GetGreen(40, 40) == 200, "Image reaches host center.");
        check((oImage:GetRed(3, 3) == 240) == (sShape == "square"), "Image is clipped to "..sShape.." host by default.");
        check(_Renderer.hit(tEntry, 3, 3, true) == (sShape == "square"), "Shape-aware hit testing matches host.");
        oImage:delete();
        oDC:delete();
        oBitmap:delete();
        oBrush:delete();
    end

    local tOverlap = {Item = {Id = "overlap", Text = "", Shape = "circle", Width = 80, Height = 80,
        ImageWidth = 112, ImageHeight = 112, Image = pFixture, ClipImage = false}, X = 0, Y = 0, Width = 112, Height = 112};
    local oBitmap = _wx.wxBitmap(112, 112);
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    tRender.draw(oDC, tOverlap, "Normal");
    oDC:SelectObject(_wx.wxNullBitmap);
    local oImage = oBitmap:ConvertToImage();
    check(oImage:GetRed(4, 4) == 240 and not _Renderer.hit(tOverlap, 4, 4, true), "Explicit image overlap paints outside host without enlarging hit target.");
    oImage:delete();
    oDC:delete();
    oBitmap:delete();
    local pMagenta = pFixture.."-magenta.png";
    local oMagenta = _wx.wxImage(16, 16);
    oMagenta:SetRGB(_wx.wxRect(0, 0, 16, 16), 255, 0, 255);
    check(oMagenta:SaveFile(pMagenta, _wx.wxBITMAP_TYPE_PNG), "Write full-colour mask fixture.");
    _tFixtures[#_tFixtures + 1] = pMagenta;
    oMagenta:delete();
    local tMagenta = {Item = {Id = "magenta", Text = "", Shape = "circle", Width = 80, Height = 80,
        ImageWidth = 80, ImageHeight = 80, Image = pMagenta, ClipImage = true}, X = 0, Y = 0, Width = 80, Height = 80};
    local oMagentaBitmap = _wx.wxBitmap(80, 80);
    local oMagentaDC = _wx.wxMemoryDC();
    oMagentaDC:SelectObject(oMagentaBitmap);
    tRender.draw(oMagentaDC, tMagenta, "Normal");
    oMagentaDC:SelectObject(_wx.wxNullBitmap);
    local oMagentaImage = oMagentaBitmap:ConvertToImage();
    check(oMagentaImage:GetRed(40, 40) == 255 and oMagentaImage:GetGreen(40, 40) == 0
        and oMagentaImage:GetBlue(40, 40) == 255, "Image clipping does not reserve magenta as transparent.");
    oMagentaImage:delete();
    oMagentaDC:delete();
    oMagentaBitmap:delete();
    tRender.destroy();

    -- Reentrant listeners must not replace the selection delivered to OnSelect.
    local tReentrant;
    local oReentrant = _Controls.contextMenu(oHost, {Skin = oSkin, Items = {{Id = "again", Text = "Again"}},
        OnSelect = function(tResult)
            tReentrant = tResult;
        end});
    oReentrant.on("selected", function(oSource)
        oSource.showAtObject(oTarget);
    end);
    oReentrant.showAtObject(oTarget);
    local bAgain, tAgain = oReentrant.activateItem("again");
    check(bAgain and tAgain.Id == "again" and tReentrant.Id == "again", "Reopening listener cannot corrupt delivered selection.");
    oReentrant.destroy();

    local oKeyboard = _Controls.contextMenu(oHost, {Skin = oSkin, Items = {
        {Id = "key-disabled", Text = "Disabled", Enabled = false},
        {Id = "key-branch", Text = "Branch", Items = {{Id = "key-leaf", Text = "Leaf"}}}
    }});
    oKeyboard.showAtObject(oTarget);
    check(oKeyboard.getFocusedItem() == "key-branch", "Initial keyboard focus skips disabled choices.");
    oKeyboard.handleKey("down", _wx.WXK_RIGHT);
    check(oKeyboard.getLayout().Depth == 1 and oKeyboard.getFocusedItem() == "__back", "Context Right opens submenu.");
    oKeyboard.handleKey("down", _wx.WXK_LEFT);
    check(oKeyboard.getLayout().Depth == 0, "Context Left goes back.");
    oKeyboard.handleKey("down", _wx.WXK_RIGHT);
    local tKeyLayout = oKeyboard.getLayout();
    local nClicks = 0;
    oKeyboard.on("leftClick", function(oSource)
        check(oSource == oKeyboard, "Native menu event uses public proxy identity.");
        nClicks = nClicks + 1;
    end);
    local tKeyLeaf = tKeyLayout.Entries[2];
    click(oKeyboard.Control, tKeyLeaf.X + 20, tKeyLeaf.Y + 15);
    check(nClicks == 1 and not oKeyboard.isOpen() and oKeyboard.getSelection().Id == "key-leaf",
        "Native pointer activation closes and delivers the selected leaf.");
    oKeyboard.destroy();

    local tWeak;
    do
        local oCollectible = _Controls.contextMenu(oHost, {Skin = oSkin, Items = {{Id = "gc", Text = "GC"}}});
        oCollectible.attach(oTarget);
        oCollectible.detach(oTarget);
        oCollectible.attach(oTarget);
        tWeak = setmetatable({oCollectible}, {__mode = "v"});
        oCollectible.destroy();
        oCollectible = nil;
    end
    _wx.wxYield();
    collectgarbage("collect");
    collectgarbage("collect");
    check(tWeak[1] == nil, "Attachments do not retain a destroyed menu while targets stay alive.");

    local nDestroyed = 0;
    oContext.on("destroyed", function()
        nDestroyed = nDestroyed + 1;
    end);
    oContext.destroy();
    oContext.destroy();
    check(nDestroyed == 1, "Menu disposal notifies exactly once.");
    oRadial.destroy();
    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxYield();

    local tWorkbench = require("Tests.UI")(_wx.NULL);
    tWorkbench.Gallery.show("RadialMenuTarget", true);
    tWorkbench.Layout();
    _wx.wxYield();
    click(tWorkbench.Widgets.RadialMenuTarget.Control, 20, 20);
    check(tWorkbench.Widgets.RadialMenu.isOpen(), "Workbench programmatic radial button opens menu.");
    tWorkbench.Widgets.RadialMenu.activateItem("attack");
    check(tWorkbench.Widgets.MenuSelection.getValue() == "Selected: attack", "Workbench displays returned action path.");
    tWorkbench.Gallery.show("ContextMenuTarget", true);
    local oDemoTarget = tWorkbench.Widgets.ContextMenuTarget.Control;
    local oDemoPoint = oDemoTarget:ClientToScreen(_wx.wxPoint(20, 20));
    contextEvent(oDemoTarget, oDemoPoint:GetX(), oDemoPoint:GetY());
    check(tWorkbench.Widgets.ContextMenu.isOpen(), "Workbench right-click attachment opens context menu.");
    tWorkbench.Widgets.ContextMenu.close();
    tWorkbench.Gallery.show("RadialMenuTarget", true);
    tWorkbench.Widgets.RadialMenu.showAtObject(tWorkbench.Widgets.RadialMenuTarget);
    local tRadialLayout = tWorkbench.Widgets.RadialMenu.getLayout();
    local oPreviewContext = _Controls.contextMenu(tWorkbench.Frame, {Skin = tWorkbench.Skin, Items = {
        {Id = "preview-attack", Text = "Attack", Image = _pFramework.."/Menu/Command Sword.png"},
        {Id = "preview-guard", Text = "Guard", Image = _pFramework.."/Menu/Command Shield.png"},
        {Id = "preview-build", Text = "Build", Items = {{Id = "preview-tower", Text = "Tower"}}},
        {Id = "preview-disabled", Text = "Unavailable", Enabled = false}
    }});
    tWorkbench.Gallery.show("ContextMenuTarget", true);
    oPreviewContext.showAtObject(tWorkbench.Widgets.ContextMenuTarget);
    local tContextLayout = oPreviewContext.getLayout();
    local nPreviewWidth = tRadialLayout.Width + tContextLayout.Width + 96;
    local nPreviewHeight = math.max(tRadialLayout.Height, tContextLayout.Height) + 100;
    local oPreview = _wx.wxBitmap(nPreviewWidth, nPreviewHeight);
    local oPreviewDC = _wx.wxMemoryDC();
    local oPreviewBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    oPreviewDC:SelectObject(oPreview);
    oPreviewDC:SetBackground(oPreviewBrush);
    oPreviewDC:Clear();
    oPreviewDC:SetDeviceOrigin(24, 50);
    tWorkbench.Widgets.RadialMenu.draw(oPreviewDC, tRadialLayout.Width, tRadialLayout.Height);
    oPreviewDC:SetDeviceOrigin(tRadialLayout.Width + 60, 50);
    oPreviewContext.draw(oPreviewDC, tContextLayout.Width, tContextLayout.Height);
    oPreviewDC:SetDeviceOrigin(0, 0);
    tWorkbench.Skin.text(oPreviewDC, "Radial / mixed shapes, images and overflow", 24, 16, true);
    tWorkbench.Skin.text(oPreviewDC, "Context", tRadialLayout.Width + 60, 16, true);
    oPreviewDC:SelectObject(_wx.wxNullBitmap);
    local oPreviewImage = oPreview:ConvertToImage();
    check(oPreviewImage:SaveFile(APP_PATH.."/Tests/MenuPreview.png", _wx.wxBITMAP_TYPE_PNG), "Save production menu preview.");
    oPreviewImage:delete();
    oPreviewDC:delete();
    oPreviewBrush:delete();
    oPreview:delete();
    oPreviewContext.destroy();
    tWorkbench.Widgets.RadialMenu.close();
    tWorkbench.Frame:Close();
    _wx.wxYield();
end

local bPassed, sError = xpcall(run, debug.traceback);

for _, pFile in ipairs(_tFixtures) do
    os.remove(pFile);
end

if (not bPassed) then
    io.stderr:write(sError.."\n");
    os.exit(1);
end

print("Menu regression passed: ".._nChecks.." checks.");
