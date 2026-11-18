local _wx = require("wx");
local FileBrowserRegression = {};

--[[!
@fqxn wxLuma.Tests.FileBrowserRegression.run
@desc Exercises real directory navigation, bounded history semantics, stable
    multi-selection, native header/activation events, numeric sorting, literal
    and glob filters, failures, refresh, appearance and disposal. All filesystem
    mutations belong to a temporary fixture, removed after success or failure.
@ret number nChecks Successful behavior assertions.
!]]
function FileBrowserRegression.run()
    local oLuma = require("wxLuma")();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "File browser regression");
    local pRoot = os.tmpname(); os.remove(pRoot);
    local tFiles, tDirectories, tOwned = {}, {}, {};
    local nChecks = 0;
    local bExit = _wx.wxGetApp():GetExitOnFrameDelete();
    _wx.wxGetApp():SetExitOnFrameDelete(false);

    --[[!
    @fqxn wxLuma.Tests.FileBrowserRegression.fCheck
    @desc Counts assertions and reports the violated user-facing contract.
    !]]
    local function fCheck(bValue, sMessage) assert(bValue, sMessage); nChecks = nChecks + 1; end

    --[[!
    @fqxn wxLuma.Tests.FileBrowserRegression.fDirectory
    @desc Creates one explicitly tracked temporary directory for this fixture.
    !]]
    local function fDirectory(sPath)
        assert(_wx.wxMkdir(sPath), "Cannot create browser fixture directory.");
        tDirectories[#tDirectories + 1] = sPath;
    end

    --[[!
    @fqxn wxLuma.Tests.FileBrowserRegression.fFile
    @desc Creates deterministic-size fixture files; the browser never writes them.
    !]]
    local function fFile(sPath, sData)
        local hFile = assert(io.open(sPath, "wb")); hFile:write(sData); hFile:close();
        tFiles[#tFiles + 1] = sPath;
    end

    --[[!
    @fqxn wxLuma.Tests.FileBrowserRegression.fFind
    @desc Resolves a displayed entry by name without depending on native row indices.
    !]]
    local function fFind(oBrowser, sName)
        for _, tEntry in ipairs(oBrowser.getEntries()) do if (tEntry.Name == sName) then return tEntry; end end
    end

    --[[!
    @fqxn wxLuma.Tests.FileBrowserRegression.fNative
    @desc Sends an actual wxListEvent through the composed report control.
    !]]
    local function fNative(oBrowser, nType, nIndex, nColumn)
        local oEvent = _wx.wxListEvent(nType, oBrowser.BrowserList.TableControl:GetId());
        oEvent.GetIndex = function() return nIndex or 0; end;
        oEvent.GetColumn = function() return nColumn or 0; end;
        oEvent:SetEventObject(oBrowser.BrowserList.TableControl);
        oBrowser.BrowserList.TableControl:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
    end

    local bOK, sError = xpcall(function()
        fDirectory(pRoot); fDirectory(pRoot.."/alpha"); fDirectory(pRoot.."/empty");
        fFile(pRoot.."/small.lua", "123456789"); fFile(pRoot.."/large.txt", ("x"):rep(120));
        fFile(pRoot.."/literal[1].txt", "literal"); fFile(pRoot.."/alpha/inside.lua", "inside");
        local nChanged, nSelections, nFailed, nActivated = 0, 0, 0, 0;
        local oBrowser = oLuma.Controls.fileBrowser(oFrame, {Directory = pRoot, OnChange = function() nChanged = nChanged + 1; end,
            OnActivate = function() nActivated = nActivated + 1; end});
        tOwned[#tOwned + 1] = oBrowser; oBrowser.layout(0, 0, 760, 380);
        oBrowser.on("selectionChanged", function(oSource, tEvent)
            nSelections = nSelections + 1;
            fCheck(oSource == oBrowser and type(tEvent.Selected) == "table", "Browser owns copied selection event payloads.");
            tEvent.Selected[1] = "caller mutation";
        end);
        oBrowser.on("navigationFailed", function() nFailed = nFailed + 1; end);
        fCheck(next(oBrowser) == nil and getmetatable(oBrowser) == "wxLuma.UI.FileBrowser", "Browser follows actual/decoy conventions.");
        fCheck(#oBrowser.getEntries() == 5 and oBrowser.getEntries()[1].Directory, "Initial directory lists immediate entries with folders first.");
        local sRoot = oBrowser.getDirectory();
        fCheck(_wx.wxDirExists(sRoot) and oBrowser.getValue() == sRoot and not oBrowser.canGoBack(), "Initial path is canonical and creates no history step.");
        local tSmall, tLarge = fFind(oBrowser, "small.lua"), fFind(oBrowser, "large.txt");
        fCheck(tSmall.Size == 9 and tLarge.Size == 120 and type(tSmall.Modified) == "number", "File metadata reports byte counts and numeric modification times.");
        local tSnapshot = oBrowser.getEntries(); tSnapshot[1].Name = "changed";
        fCheck(oBrowser.getEntries()[1].Name ~= "changed", "Entry snapshots are independent.");
        oBrowser.setSelected({tSmall.Path, tLarge.Path});
        fCheck(#oBrowser.getSelected() == 2 and nSelections == 0, "Multiselection is enabled by default and setters are silent.");
        fCheck(not pcall(oBrowser.setSelected, {[2] = tSmall.Path}) and #oBrowser.getSelected() == 2,
            "Sparse selections are rejected before changing existing selected paths.");
        fCheck(not pcall(oBrowser.setSelected, {Named = tSmall.Path}) and #oBrowser.getSelected() == 2,
            "Non-array selections cannot silently clear selected paths.");
        oBrowser.sortBy("Size", "ascending", true);
        local tRows = oBrowser.getEntries();
        fCheck(tRows[1].Directory and tRows[2].Directory and tRows[#tRows].Name == "large.txt", "Ascending byte sort is numeric and keeps folders first.");
        oBrowser.sortBy("Size", "descending");
        tRows = oBrowser.getEntries();
        fCheck(tRows[1].Directory and tRows[3].Name == "large.txt" and #oBrowser.getSelected() == 2, "Descending byte sort keeps folders first and preserves selected paths.");
        fNative(oBrowser, _wx.wxEVT_COMMAND_LIST_COL_CLICK, 0, 2);
        fCheck(oBrowser.getSort().Column == "Size" and oBrowser.getSort().Direction == "ascending", "Native headers toggle the browser's numeric sorter.");
        fNative(oBrowser, _wx.wxEVT_COMMAND_LIST_COL_CLICK, 0, 2);
        fCheck(oBrowser.getSort().Direction == "descending", "Repeated native header clicks reverse sort direction.");
        oBrowser.setPattern("*.lua;literal[?].txt");
        fCheck(#oBrowser.getEntries() == 4 and fFind(oBrowser, "literal[1].txt") ~= nil, "Filename globs support literal punctuation and ? without hiding folders.");
        fCheck(#oBrowser.getSelected() == 1 and oBrowser.getSelected()[1] == tSmall.Path, "Filtering retains only visible selected paths.");
        oBrowser.setPattern("*"); oBrowser.setFilter("[1]");
        fCheck(#oBrowser.getEntries() == 1 and oBrowser.getEntries()[1].Name == "literal[1].txt", "Name filtering treats Lua pattern punctuation literally.");
        oBrowser.setFilter("nothing matches");
        fCheck(#oBrowser.getEntries() == 0 and #oBrowser.getSelected() == 0, "Empty filter results are valid and clear hidden selections.");
        oBrowser.setFilter(""); oBrowser.setSelected({tSmall.Path}, true);
        fCheck(nSelections == 1 and oBrowser.getSelected()[1] == tSmall.Path, "Selection events cannot mutate selected paths.");
        oBrowser.setFilter("small"); oBrowser.setPattern("*.lua"); oBrowser.sortBy("Size", "descending");
        local tSavedBrowser = oBrowser.getObjectState();
        fCheck(#tSavedBrowser.Objects == 1, "Browser state captures its model once rather than derived private controls.");
        oBrowser.setFilter("large"); oBrowser.setPattern("*.txt"); oBrowser.sortBy("Name", "ascending");
        local nSavedNotifications = nChanged + nSelections + nFailed + nActivated;
        oBrowser.setObjectState(tSavedBrowser);
        fCheck(oBrowser.getFilter() == "small" and oBrowser.FilterField.getValue() == "small"
            and #oBrowser.getEntries() == 1 and oBrowser.getEntries()[1].Name == "small.lua"
            and oBrowser.getPattern() == "*.lua" and oBrowser.getSelected()[1] == tSmall.Path,
            "Browser state restores the private filter, editor, listing and selection coherently.");
        fCheck(oBrowser.getSort().Column == "Size" and oBrowser.getSort().Direction == "descending"
            and nChanged + nSelections + nFailed + nActivated == nSavedNotifications, "Browser state restores sort silently.");
        local tInvalidBrowser = oBrowser.getBrowserState(); tInvalidBrowser.Directory = sRoot.."missing";
        fCheck(not pcall(oBrowser.setBrowserState, tInvalidBrowser) and oBrowser.getDirectory() == sRoot
            and oBrowser.getFilter() == "small" and oBrowser.getSelected()[1] == tSmall.Path
            and nFailed + nChanged + nSelections + nActivated == nSavedNotifications,
            "Failed aggregate browser restore preserves model, children and notifications.");
        local tDetachedBrowser = oBrowser.getBrowserState(); tDetachedBrowser.Sort.Column = "Modified";
        fCheck(oBrowser.getSort().Column == "Size", "Aggregate browser state getters detach nested records.");
        oBrowser.setFilter(""); oBrowser.setPattern("*");
        fCheck(oBrowser.navigate("alpha", true), "Relative child navigation succeeds.");
        fCheck(#oBrowser.getEntries() == 1 and oBrowser.canGoBack() and #oBrowser.getSelected() == 0 and nChanged == 1,
            "Navigation publishes the new listing, clears selection and records history.");
        local sAlpha = oBrowser.getDirectory();
        fCheck(oBrowser.goBack(true) and oBrowser.getDirectory() == sRoot and oBrowser.getSelected()[1] == tSmall.Path
            and oBrowser.canGoForward(), "Back restores directory and surviving selection.");
        fCheck(oBrowser.goForward() and oBrowser.getDirectory() == sAlpha, "Forward restores the next location.");
        local tSavedHistory = oBrowser.getObjectState();
        oBrowser.goBack(); oBrowser.navigate("empty");
        oBrowser.setObjectState(tSavedHistory);
        fCheck(oBrowser.getDirectory() == sAlpha and oBrowser.canGoBack() and not oBrowser.canGoForward(),
            "Object state restores navigation stacks with their original direction.");
        local tBeforeMissingRestore = oBrowser.getObjectState();
        tBeforeMissingRestore.Objects[1].Properties.Custom.Directory = sRoot.."not-present";
        fCheck(not pcall(oBrowser.setObjectState, tBeforeMissingRestore) and oBrowser.getDirectory() == sAlpha
            and oBrowser.canGoBack(), "Failed object-state browser restore retains directory and history.");
        fCheck(oBrowser.goUp() and oBrowser.getDirectory() == sRoot and not oBrowser.canGoForward(), "New parent navigation clears forward history.");
        oBrowser.setSelected({tSmall.Path});
        local nBeforeChanged = nChanged;
        fCheck(not oBrowser.navigate("missing", true) and oBrowser.getDirectory() == sRoot
            and oBrowser.getSelected()[1] == tSmall.Path and nChanged == nBeforeChanged and nFailed == 1,
            "Failed navigation preserves directory, selection and notification state.");
        fCheck(oBrowser.DirectoryField.getValue() == sRoot and oBrowser.getError().Reason ~= nil, "Failure restores the actual address and exposes its inline error.");
        local tError = oBrowser.getError(); tError.Reason = "changed";
        fCheck(oBrowser.getError().Reason ~= "changed", "Error getters return independent snapshots.");
        fCheck(oBrowser.reload() and oBrowser.getError() == nil and oBrowser.getSelected()[1] == tSmall.Path, "Refresh clears errors and preserves existing selections.");
        oBrowser.activate(tSmall.Path, true);
        fCheck(nActivated == 1 and oBrowser.getDirectory() == sRoot, "Activating a file reports it without navigating or launching another app.");
        for nIndex, tEntry in ipairs(oBrowser.getEntries()) do
            if (tEntry.Name == "small.lua") then fNative(oBrowser, _wx.wxEVT_COMMAND_LIST_ITEM_ACTIVATED, nIndex - 1); break; end
        end
        fCheck(nActivated == 2, "Native Enter/double-click activation emits one file callback.");
        for nIndex, tEntry in ipairs(oBrowser.getEntries()) do
            if (tEntry.Name == "empty") then fNative(oBrowser, _wx.wxEVT_COMMAND_LIST_ITEM_ACTIVATED, nIndex - 1); break; end
        end
        fCheck(#oBrowser.getEntries() == 0 and oBrowser.getDirectory() ~= sRoot, "Native folder activation opens an empty directory normally.");
        local sEmpty = oBrowser.getDirectory();
        oBrowser.goBack();
        assert(_wx.wxRmdir(pRoot.."/empty"));
        fCheck(not oBrowser.goForward() and oBrowser.getDirectory() == sRoot and oBrowser.canGoForward(), "Deleted history destinations do not consume the forward stack.");
        assert(_wx.wxMkdir(pRoot.."/empty"));
        fCheck(oBrowser.goForward() and oBrowser.getDirectory() == sEmpty, "A restored history destination is still reachable.");
        oBrowser.goBack();
        oBrowser.setSelected({tSmall.Path, tLarge.Path}); oBrowser.setMultiSelectEnabled(false);
        fCheck(#oBrowser.getSelected() == 1 and not oBrowser.isMultiSelectEnabled(), "Single-selection mode retains only the primary row.");
        fCheck(not pcall(oBrowser.setSelected, {tSmall.Path, tLarge.Path}), "Single-selection mode rejects multiple paths atomically.");
        local nBeforeSelection = nSelections;
        oBrowser.BrowserList.setValue(tSmall.Path:lower(), true);
        fCheck(nSelections == nBeforeSelection + 1 and oBrowser.getSelected()[1] == tSmall.Path,
            "Rejected selection does not break subsequent child selection routing.");
        oBrowser.setMultiSelectEnabled(true); oBrowser.setSelected({tSmall.Path, tLarge.Path});
        oBrowser.navigate(sAlpha); oBrowser.setMultiSelectEnabled(false);
        fCheck(oBrowser.goBack() and #oBrowser.getSelected() == 1,
            "History restoration fits saved multiselection into the current single-selection policy.");
        oBrowser.setMultiSelectEnabled(true); oBrowser.setSelected({tSmall.Path});
        assert(os.remove(pRoot.."/small.lua"));
        fCheck(not oBrowser.activate(tSmall.Path, true) and nActivated == 2, "Removed files cannot emit activation callbacks.");
        oBrowser.reload();
        fCheck(#oBrowser.getSelected() == 0 and fFind(oBrowser, "small.lua") == nil, "Refresh drops deleted entries and stale selection.");
        local nCount = #oBrowser.getEntries();
        fCheck(oBrowser.setShowHiddenEnabled(true) and oBrowser.isShowHiddenEnabled()
            and #oBrowser.getEntries() >= nCount, "Hidden-entry policy refreshes the current directory.");
        fCheck(not pcall(oBrowser.setPattern, " ; ") and not pcall(oBrowser.setFilter, false)
            and not pcall(oBrowser.sortBy, "NoColumn", "ascending")
            and not pcall(oBrowser.setSelected, {"not a visible path"}), "Invalid filter/sort/selection inputs are rejected.");
        oBrowser.setEnabled(false);
        fCheck(not oBrowser.BrowserList.isEnabled() and not oBrowser.DirectoryField.isEnabled()
            and not oBrowser.handleNavigationKey(_wx.WXK_F5), "Disabling the browser disables child input and navigation shortcuts.");
        oBrowser.setEnabled(true);
        for _, sTheme in ipairs({"Obsidian", "System"}) do
            local oNative = oBrowser.BrowserList.TableControl;
            oLuma.Theme.setName(sTheme);
            local oBitmap = _wx.wxBitmap(760, 380); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
            oBrowser.draw(oDC, 760, 380);
            oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
            fCheck(oBrowser.getDirectory() == sRoot and oBrowser.BrowserList.TableControl == oNative,
                "Appearance preserves directory data and the native report control: "..sTheme);
        end
        local tEnabledState = oBrowser.getBrowserState();
        oFrame:Enable(false); oBrowser.setBrowserState(tEnabledState); oFrame:Enable(true);
        fCheck(oBrowser.BackButton.Control:IsThisEnabled() == oBrowser.canGoBack()
            and oBrowser.ForwardButton.Control:IsThisEnabled() == oBrowser.canGoForward(),
            "Restoring under a disabled ancestor retains each navigation button's own availability.");
        for _, nWidth in ipairs({200, 320, 440, 900}) do
            oBrowser.layout(0, 0, nWidth, 380);
            for _, oChild in ipairs({oBrowser.DirectoryField, oBrowser.FilterField, oBrowser.BrowserList, oBrowser.StatusLabel}) do
                local nX, nY = oChild.Control:GetPositionXY(); local nW, nH = oChild.Control:GetSizeWH();
                fCheck(nX >= 0 and nY >= 0 and nW > 0 and nH > 0 and nX + nW <= nWidth and nY + nH <= 380,
                    "Browser children fit supported narrow/wide layouts.");
            end
        end
        for nIndex = 1, 20 do
            assert(oBrowser.navigate("alpha")); assert(oBrowser.goBack());
        end
        fCheck(oBrowser.getDirectory() == sRoot, "Repeated navigation preserves stable history and listing state.");
        for nIndex = 1, 140 do assert(oBrowser.navigate(nIndex % 2 == 0 and sRoot or sAlpha)); end
        local nBack = 0;
        while (oBrowser.goBack()) do nBack = nBack + 1; assert(nBack <= 128, "History must be bounded."); end
        fCheck(nBack == 128, "Back history is bounded to 128 successful locations.");
        oBrowser.navigate(sEmpty);
        for nIndex = 1, 300 do fFile(sEmpty..string.format("entry-%03d.txt", nIndex), ("x"):rep(nIndex)); end
        oBrowser.reload(); oBrowser.sortBy("Size", "descending");
        fCheck(#oBrowser.getEntries() == 300 and oBrowser.getEntries()[1].Size == 300,
            "A larger directory sorts by numeric size without losing entries.");
        local oNative = oBrowser.BrowserList.TableControl;
        for nIndex = 1, 30 do oBrowser.setFilter(nIndex % 2 == 0 and "" or "entry-1"); end
        fCheck(#oBrowser.getEntries() == 300 and oBrowser.BrowserList.TableControl == oNative,
            "Repeated filtering reuses the original native report control.");
        oBrowser.destroy(); oBrowser.destroy();
        fCheck(oBrowser.Disposed and not pcall(oBrowser.reload), "Disposal is idempotent and blocks further reads.");
    end, debug.traceback);
    for nIndex = #tOwned, 1, -1 do if (not tOwned[nIndex].Disposed) then tOwned[nIndex].destroy(); end end
    oFrame:Destroy(); _wx.wxYield(); oLuma.Theme.destroy();
    for _, sPath in ipairs(tFiles) do os.remove(sPath); end
    for nIndex = #tDirectories, 1, -1 do _wx.wxRmdir(tDirectories[nIndex]); end
    _wx.wxGetApp():SetExitOnFrameDelete(bExit);
    assert(bOK, sError);
    print("File browser regression: "..nChecks.." checks passed.");
    return nChecks;
end

return FileBrowserRegression;
