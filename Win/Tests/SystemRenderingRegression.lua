local _wx = require("wx");
local _load = require("wxLuma");
local _SystemArtwork = require("wxLuma.Core.SystemArtwork");
local _Theme = require("wxLuma.Core.ControlTheme");
local SystemRenderingRegression = {};

--[[!
@fqxn wxLuma.Tests.SystemRenderingRegression.run
@desc Checks reported System rendering defects with memory DCs: opaque neutral
    backgrounds, complete-word glyphs, native checkbox geometry, compact sliders
    and paired selection colors. Does not launch a gallery or inspect images.
@ret number nChecks Successful assertions.
!]]
function SystemRenderingRegression.run()
    local nChecks = 0;
    local oLuma = _load();
    local oTheme = oLuma.Theme;
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "System rendering regression");
    local tOwned = {};

    --[[!
    @fqxn wxLuma.Tests.SystemRenderingRegression.fCheck
    @desc Counts successful checks and reports the violated rendering contract.
    !]]
    local function fCheck(bPassed, sMessage)
        assert(bPassed, sMessage); nChecks = nChecks + 1;
    end

    --[[!
    @fqxn wxLuma.Tests.SystemRenderingRegression.fRender
    @desc Starts from an unmistakable background, renders into memory and returns
        RGB bytes. Unpainted areas therefore cannot accidentally pass as System.
    !]]
    local function fRender(fDraw, nWidth, nHeight)
        local oBitmap = _wx.wxBitmap(nWidth, nHeight);
        local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        local oBrush = _wx.wxBrush(_wx.wxColour(197, 17, 131));
        oDC:SetBackground(oBrush); oDC:Clear();
        fDraw(oDC, nWidth, nHeight);
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBrush:delete();
        local oImage = oBitmap:ConvertToImage(); local sPixels = oImage:GetData();
        oImage:delete(); oBitmap:delete(); return sPixels;
    end

    --[[!
    @fqxn wxLuma.Tests.SystemRenderingRegression.fRGB
    @desc Encodes a borrowed theme color as one RGB pixel.
    !]]
    local function fRGB(sRole)
        local oColor = oTheme.color(sRole);
        return string.char(oColor:Red(), oColor:Green(), oColor:Blue());
    end

    local bOK, sError = xpcall(function()
        oTheme.setName("System");
        local sBackground = fRGB("Background");
        for _, sName in ipairs({"Log Viewer Game Background", "Iris Progress Background"}) do
            local sPixels = fRender(function(oDC, nW, nH) oTheme.draw(oDC, sName, 0, 0, nW, nH); end, 80, 60);
            fCheck(sPixels == sBackground:rep(80 * 60), sName.." must fill its bounds without drawing an arrow.");
        end
        local sArrow = fRender(function(oDC, nW, nH)
            oTheme.fill(oDC, "Background", 0, 0, nW, nH);
            oTheme.drawFor(oFrame, oDC, "Breadcrumb Back Normal", 0, 0, nW, nH);
        end, 30, 30);
        fCheck(sArrow ~= sBackground:rep(30 * 30), "The actual Back glyph remains visible.");
        local oParent = _wx.wxPanel(oFrame, _wx.wxID_ANY);
        oParent:SetBackgroundColour(_wx.wxColour(210, 225, 235));
        local oSwitch = oLuma.Controls.switch(oParent, {Value = true});
        tOwned[#tOwned + 1] = oSwitch;
        local sSwitch = fRender(oSwitch.draw, 100, 50);
        fCheck(sSwitch:sub(1, 3) == string.char(210, 225, 235), "System switch corners blend into the actual parent instead of a rectangular skin surface.");
        fCheck((oSwitch.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE,
            "Standalone switches default to a borderless native host.");
        local sSwitchTrack = fRender(function(oDC)
            oTheme.drawFor(oSwitch.Control, oDC, "Switch Horizontal Off Normal", 0, 0, 112, 48);
        end, 112, 48);
        local nTrackByte = (24 * 112 + 56) * 3 + 1;
        fCheck(sSwitchTrack:sub(nTrackByte, nTrackByte + 2) == fRGB("Border"),
            "Switch pill uses a contrasting system track instead of the parent face.");
        local tSwitchOptions = {Value = true, Border = _wx.wxBORDER_SIMPLE};
        local oBorderedSwitch = oLuma.Controls.switch(oParent, tSwitchOptions); tOwned[#tOwned + 1] = oBorderedSwitch;
        fCheck((oBorderedSwitch.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_SIMPLE
            and tSwitchOptions.Border == _wx.wxBORDER_SIMPLE, "Explicit switch borders are honored without changing caller options.");

        for sPart, sRole in pairs({Surface = "Editor", Row = "Editor", Category = "Background", Separator = "Border",
            ["Editor Fill"] = "Editor", ["Editor Surface"] = "Editor", Text = "Text"}) do
            fCheck(_SystemArtwork.describe("Property Grid "..sPart.." Normal") == sRole,
                "Property grid resolves the explicit role for "..sPart..".");
        end
        fCheck(_SystemArtwork.describe("Chart Grid Normal") == "Border", "Actual chart grid lines retain their grid-line role.");
        local oProperties = oLuma.Controls.propertyGrid(oFrame, {Properties = {
            {Id = "general", Text = "General", Type = "category"}, {Id = "name", Text = "Name", Value = "Release"}}});
        tOwned[#tOwned + 1] = oProperties; oProperties.layout(0, 0, 300, 180);
        fCheck(fRender(oProperties.draw, 240, 100) == fRGB("Editor"):rep(240 * 100),
            "Standalone property grid paints the sheet background instead of the grid-line color.");
        local oSection = oLuma.Controls.collapsiblePanel(oFrame, {Text = "Delivery notes", Expanded = true, ContentHeight = 90});
        tOwned[#tOwned + 1] = oSection; oSection.layout(0, 0, 300, 140);
        local oSectionLabel = oLuma.Controls.label(oSection.Content, {Value = "Review before delivery"});
        tOwned[#tOwned + 1] = oSectionLabel; oSectionLabel.layout(4, 4, 220, 44);
        local sSection = fRender(oSection.draw, 240, 140);
        local nHeaderByte, nBodyByte = (18 * 240 + 220) * 3 + 1, (60 * 240 + 220) * 3 + 1;
        fCheck(sSection:sub(nHeaderByte, nHeaderByte + 2) == fRGB("Background")
            and sSection:sub(nBodyByte, nBodyByte + 2) == fRGB("Editor"), "Notes panel separates header and content using OS roles.");
        fCheck((oSectionLabel.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE,
            "Text labels do not add an unexpected outer rectangle.");
        local oEditorColor = oTheme.color("Editor");
        _Theme.sync(oProperties.Scroll, oTheme); _Theme.sync(oSection, oTheme);
        fCheck(oProperties.Scroll.Content:GetBackgroundColour():GetAsString() == oEditorColor:GetAsString()
            and oSection.Content:GetBackgroundColour():GetAsString() == oEditorColor:GetAsString(),
            "Ancestor refreshes preserve explicit content background roles.");
        fCheck(fRender(oSectionLabel.draw, 220, 44):sub(1, 3) == fRGB("Editor"),
            "Nested labels blend with the notes body instead of caching the window background.");

        local oCheck = oLuma.Controls.checkbox(oFrame, {Text = "", Selected = true});
        tOwned[#tOwned + 1] = oCheck;
        oCheck.layout(0, 0, 240, 60);
        local nCheckW, nCheckH = oTheme.indicatorSize(oCheck.Control);
        fCheck(nCheckW > 0 and nCheckH > 0 and nCheckH < oCheck.Control:FromDIP(32), "Checkbox uses compact native dimensions.");
        local sCheck = fRender(oCheck.draw, 240, 60);
        local sNative = fRender(function(oDC, nW, nH)
            local oBackdrop = _wx.wxBrush(oFrame:GetBackgroundColour());
            oDC:SetBackground(oBackdrop); oDC:Clear(); oBackdrop:delete();
            _wx.wxRendererNative.Get():DrawCheckBox(oCheck.Control, oDC,
                _wx.wxRect(0, math.floor((nH - nCheckH) / 2), nCheckW, nCheckH), _wx.wxCONTROL_CHECKED);
        end, 240, 60);
        fCheck(sCheck == sNative, "System checkbox matches the native renderer without a dark bar.");

        local nDropdownChanges = 0;
        local oDropdown = oLuma.Controls.dropdown(oFrame, {Items = {"Planning", "Review"}, Value = 2,
            OnChange = function() nDropdownChanges = nDropdownChanges + 1; end});
        tOwned[#tOwned + 1] = oDropdown; oDropdown.layout(0, 0, 240, 40);
        local oCombo = oLuma.Controls.comboBox(oFrame, {Items = {"Alex", "Sam"}, Value = "Alex"});
        tOwned[#tOwned + 1] = oCombo; oCombo.layout(0, 0, 240, 40);
        for _, oChoice in ipairs({oDropdown, oCombo}) do
            local fIsOpen = oChoice.isOpen;
            local nButtonWidth = _wx.wxSystemSettings.GetMetric(_wx.wxSYS_VSCROLL_X, oChoice.Control);
            if (nButtonWidth <= 0) then nButtonWidth = oChoice.Control:FromDIP(17); end
            for _, tState in ipairs({{"Normal", 0}, {"Hover", _wx.wxCONTROL_CURRENT},
                {"Pressed", _wx.wxCONTROL_PRESSED}, {"Disabled", _wx.wxCONTROL_DISABLED}, {"Open", _wx.wxCONTROL_PRESSED}}) do
                oChoice.setEnabled(tState[1] ~= "Disabled");
                oChoice.Hover, oChoice.Pressed = tState[1] == "Hover", tState[1] == "Pressed";
                oChoice.isOpen = function() return tState[1] == "Open"; end;
                local sActual = fRender(oChoice.draw, 240, 40);
                local sReference = fRender(function(oDC, nW, nH)
                    oTheme.fill(oDC, oChoice == oCombo and tState[1] == "Hover" and "Hover" or "Background", 0, 0, nW, nH);
                    if (oChoice == oDropdown) then
                        _wx.wxRendererNative.Get():DrawPushButton(oChoice.Control, oDC,
                            _wx.wxRect(0, 0, nW, nH), tState[2]);
                    end
                    _wx.wxRendererNative.Get():DrawComboBoxDropButton(oChoice.Control, oDC,
                        _wx.wxRect(nW - nButtonWidth, 0, nButtonWidth, nH), tState[2]);
                end, 240, 40);
                if (oChoice == oDropdown) then
                    local nFaceByte = (20 * 240 + 180) * 3 + 1;
                    fCheck(sActual:sub(nFaceByte, nFaceByte + 2) == sReference:sub(nFaceByte, nFaceByte + 2),
                        "Closed dropdown face follows the native button in "..tState[1].." state.");
                end
                local bSame = true;
                for nY = 0, 39 do
                    local nStart = (nY * 240 + 240 - nButtonWidth) * 3 + 1;
                    bSame = bSame and sActual:sub(nStart, nStart + nButtonWidth * 3 - 1)
                        == sReference:sub(nStart, nStart + nButtonWidth * 3 - 1);
                end
                fCheck(bSame, oChoice.Kind.." button matches the native renderer in "..tState[1].." state.");
            end
            oChoice.isOpen = fIsOpen; oChoice.setEnabled(true); oChoice.Hover, oChoice.Pressed = false, false;
        end
        fCheck(oDropdown.getValue() == 2 and oCombo.getValue() == "Alex" and nDropdownChanges == 0,
            "Arrow rendering does not change choice values or emit callbacks.");

        for _, bVertical in ipairs({false, true}) do
            local oSlider = oLuma.Controls.slider(oFrame, {Min = 0, Max = 100, Step = 1, Value = 50, Vertical = bVertical});
            tOwned[#tOwned + 1] = oSlider;
            local nW, nH = bVertical and 60 or 240, bVertical and 240 or 60;
            oSlider.layout(0, 0, nW, nH);
            local sPixels = fRender(oSlider.draw, nW, nH);
            fCheck(sPixels:sub(1, nW * 3) == sBackground:rep(nW), "Slider top margin uses the System background.");
            fCheck(sPixels:sub(-nW * 3) == sBackground:rep(nW), "Slider bottom margin uses the System background.");
            local nX, nY = math.floor(nW / 2), math.floor(nH / 2);
            local nByte = (nY * nW + nX) * 3 + 1;
            fCheck(sPixels:sub(nByte, nByte + 2) == fRGB("Fill"), "Compact slider thumb uses the system accent.");
            local nOffset = oSlider.Control:FromDIP(12);
            nX, nY = bVertical and nX + nOffset or nX, bVertical and nY or nY + nOffset;
            nByte = (nY * nW + nX) * 3 + 1;
            fCheck(sPixels:sub(nByte, nByte + 2) == sBackground, "Slider thumb does not retain the oversized skin bounds.");
        end

        local oLog = oLuma.Controls.logViewer(oFrame, {Entries = {{Id = "entry", Text = "Selected entry"}}});
        tOwned[#tOwned + 1] = oLog; oLog.layout(0, 0, 240, 100);
        oLog.setSelected({"entry"});
        local sSelected = fRender(oLog.draw, 240, 100);
        fCheck(sSelected:find(fRGB("Selection"), 1, true) ~= nil, "Selected log row uses the OS highlight.");
        fCheck(sSelected:find(fRGB("SelectionText"), 1, true) ~= nil, "Selected log text uses the OS highlight text.");
        oLog.setSelected({}); oLog.setTextSelection({Id = "entry", Start = 0, Finish = 8});
        local sTextSelection = fRender(oLog.draw, 240, 100);
        fCheck(sTextSelection:find(fRGB("Selection"), 1, true) ~= nil
            and sTextSelection:find(fRGB("SelectionText"), 1, true) ~= nil, "Substring selection uses paired OS colors.");

        local oMultiline = oLuma.Controls.multilineText(oFrame, {Value = "Retained notes"});
        tOwned[#tOwned + 1] = oMultiline; oMultiline.layout(0, 0, 240, 100);
        local nEditorX, nEditorY = oMultiline.TextControl:GetPositionXY();
        fCheck(nEditorX == 2 and nEditorY == 2, "System multiline editor has a compact surround.");
        local sEditor = fRender(oMultiline.draw, 240, 100);
        local nEditorByte = (50 * 240 + 5) * 3 + 1;
        fCheck(sEditor:sub(nEditorByte, nEditorByte + 2) == fRGB("Editor"), "Multiline surround uses the editor palette instead of the text color.");

        for _, bSelected in ipairs({false, true}) do
            local sIcon = fRender(function(oDC, nW, nH)
                oTheme.fill(oDC, bSelected and "Selection" or "Background", 0, 0, nW, nH);
                oTheme.draw(oDC, "Log Viewer Icon "..(bSelected and "Selected" or "Normal"), 0, 0, nW, nH);
            end, 20, 20);
            fCheck(sIcon:find(fRGB(bSelected and "SelectionText" or "Text"), 1, true) ~= nil,
                "Document icon uses a contrasting foreground in both selection states.");
        end
        oLog.clearTextSelection();
        oLog.setEntries({{Id = "entry", Text = "Skinned icon", IconArtwork = "Icon Normal"}});
        fRender(oLog.draw, 240, 100);
        fCheck(oLog.getEntries()[1].IconArtwork == "Icon Normal", "Log entries retain semantic icon parts.");
        oLog.setTextSelection({Id = "entry", Start = 0, Finish = 8});

        local oList = oLuma.Controls.list(oFrame, {Items = {"First entry", "Second entry", "Third entry"}, RowHeight = 36});
        tOwned[#tOwned + 1] = oList; oList.layout(0, 0, 240, 150);
        local sNormalList = fRender(oList.draw, 240, 150);
        fCheck(sNormalList:sub(1, 3) == fRGB("Editor"), "System list viewport uses the OS window background.");
        local nPlainRowByte = (20 * 240 + 180) * 3 + 1;
        fCheck(sNormalList:sub(nPlainRowByte, nPlainRowByte + 2) == fRGB("Editor"),
            "Unselected list rows share the OS list background.");
        oList.setHover(2);
        local sHoverList = fRender(oList.draw, 240, 150);
        local nTopByte, nBottomByte = (43 * 240 + 180) * 3 + 1, (72 * 240 + 180) * 3 + 1;
        fCheck(sHoverList:sub(nTopByte, nTopByte + 2) == fRGB("Hover")
            and sHoverList:sub(nBottomByte, nBottomByte + 2) == fRGB("Hover"), "Plain System list hover is a flat system color, not the legacy gradient.");
        oList.setHover(0);
        fCheck(fRender(oList.draw, 240, 150) == sNormalList, "Leaving a row restores the original list pixels.");
        oList.setValue(2);
        local sSelectedList = fRender(oList.draw, 240, 150);
        fCheck(sSelectedList:sub(nTopByte, nTopByte + 2) == fRGB("Selection")
            and sSelectedList:find(fRGB("SelectionText"), 1, true) ~= nil, "Plain lists pair OS selection background and text colors.");
        local oListEx = oLuma.Controls.listEx(oFrame, {Items = {{Name = "Selected row"}}, Columns = {{Key = "Name"}}, Value = 1, RowHeight = 36});
        tOwned[#tOwned + 1] = oListEx; oListEx.layout(0, 0, 240, 100);
        fCheck(fRender(oListEx.draw, 240, 100):find(fRGB("SelectionText"), 1, true) ~= nil,
            "Typed list cells use contrasting selected text too.");

        local oSpinner = oLuma.Controls.spinner(oFrame, {Min = 0, Max = 10, Step = 1, Value = 5});
        tOwned[#tOwned + 1] = oSpinner; oSpinner.layout(0, 0, 200, 40);
        local oNumber = oLuma.Controls.numericField(oFrame, {Min = 0, Max = 10, Step = 0.5, Value = 5, StepButtons = true});
        tOwned[#tOwned + 1] = oNumber; oNumber.layout(0, 0, 200, 40);
        local oVertical = oLuma.Controls.scrollbar(oFrame, {Min = 0, Max = 100, Page = 10, Value = 50});
        tOwned[#tOwned + 1] = oVertical; oVertical.layout(0, 0, 22, 140);
        local oHorizontal = oLuma.Controls.scrollbar(oFrame, {Min = 0, Max = 100, Page = 10, Value = 50, Vertical = false});
        tOwned[#tOwned + 1] = oHorizontal; oHorizontal.layout(0, 0, 200, 22);
        local tArrowCalls, fArrowButton = {}, oTheme.arrowButton;
        oTheme.arrowButton = function(oControl, oDC, sDirection, nX, nY, nW, nH, sState)
            tArrowCalls[oControl] = tArrowCalls[oControl] or {};
            tArrowCalls[oControl][sDirection] = sState;
            return fArrowButton(oControl, oDC, sDirection, nX, nY, nW, nH, sState);
        end;
        local bArrowsOK, sArrowError = xpcall(function()
            fRender(oSpinner.draw, 200, 40); fRender(oNumber.draw, 200, 40);
            fRender(oVertical.draw, 22, 140); fRender(oHorizontal.draw, 200, 22);
            for _, oOwner in ipairs({oDropdown.List, oCombo.List, oList, oListEx}) do
                oOwner.Scrollbar.layout(0, 0, 22, 140); fRender(oOwner.Scrollbar.draw, 22, 140);
            end
            oNumber.setReadOnly(true); fRender(oNumber.draw, 200, 40);
            oSpinner.setValue(0); fRender(oSpinner.draw, 200, 40);
            oVertical.setValue(0); fRender(oVertical.draw, 22, 140);
        end, debug.traceback);
        oTheme.arrowButton = fArrowButton; assert(bArrowsOK, sArrowError);
        for _, oOwner in ipairs({oSpinner, oNumber, oVertical, oDropdown.List.Scrollbar, oCombo.List.Scrollbar, oList.Scrollbar, oListEx.Scrollbar}) do
            fCheck(tArrowCalls[oOwner] and tArrowCalls[oOwner].Up and tArrowCalls[oOwner].Down,
                oOwner.Kind.." spinner/list/dropdown arrows use the shared native renderer.");
        end
        fCheck(tArrowCalls[oHorizontal].Left and tArrowCalls[oHorizontal].Right, "Horizontal scroll arrows use native rendering too.");
        fCheck(tArrowCalls[oNumber].Up == "Disabled" and tArrowCalls[oNumber].Down == "Disabled", "Read-only numeric steppers render disabled native buttons.");
        fCheck(tArrowCalls[oSpinner].Down == "Disabled" and tArrowCalls[oSpinner].Up == "Normal", "Spinner range limits disable only the exhausted direction.");
        fCheck(tArrowCalls[oVertical].Up == "Disabled" and tArrowCalls[oVertical].Down == "Normal", "Scroll range limits disable only the exhausted direction.");
        oNumber.setReadOnly(false);
        oSpinner.setValue(5);
        local sSpinner = fRender(oSpinner.draw, 200, 40);
        local sSpinnerReference = fRender(function(oDC, nW, nH)
            oTheme.fill(oDC, "Background", 0, 0, nW, nH);
            _wx.wxRendererNative.Get():DrawPushButton(oSpinner.Control, oDC, _wx.wxRect(nW - 26, 20, 24, 18), 0);
            _wx.wxRendererNative.Get():DrawDropArrow(oSpinner.Control, oDC, _wx.wxRect(nW - 20, 23, 12, 12), 0);
        end, 200, 40);
        local bNativeSpinner = true;
        for nY = 20, 37 do
            local nStart = (nY * 200 + 174) * 3 + 1;
            bNativeSpinner = bNativeSpinner and sSpinner:sub(nStart, nStart + 24 * 3 - 1)
                == sSpinnerReference:sub(nStart, nStart + 24 * 3 - 1);
        end
        fCheck(bNativeSpinner, "Spinner down button matches native button and arrow output, not a text V.");

        local oTabs = oLuma.Controls.tabs(oFrame, {Items = {"Work", "Planning"}, MinTabWidth = 150, MaxTabWidth = 150});
        tOwned[#tOwned + 1] = oTabs; oTabs.layout(0, 0, 400, 150);
        local oTabBitmap = _wx.wxBitmap(400, 150); local oTabDC = _wx.wxMemoryDC(); oTabDC:SelectObject(oTabBitmap);
        local fTabText, tTabText = oTabDC.DrawText, {};
        oTabDC.DrawText = function(oDC, sText, nX, nY)
            tTabText[sText] = {X = nX, Y = nY}; return fTabText(oDC, sText, nX, nY);
        end;
        oTabs.draw(oTabDC, 400, 150);
        for nIndex, sText in ipairs({"Work", "Planning"}) do
            local tEntry = oTabs.getLayout().Entries[nIndex]; oTabDC:SetFont(oTheme.Font);
            local nTextW, nTextH = oTabDC:GetTextExtent(sText);
            fCheck(math.abs(tTabText[sText].X - (tEntry.DrawX + (tEntry.DrawWidth - nTextW) / 2)) <= 1
                and math.abs(tTabText[sText].Y - (tEntry.DrawY + (tEntry.DrawHeight - nTextH) / 2)) <= 1,
                "Tab captions are horizontally and vertically centered by default.");
        end
        oTabDC.DrawText = fTabText; oTabDC:SelectObject(_wx.wxNullBitmap); oTabDC:delete(); oTabBitmap:delete();
        local oLeftTabs = oLuma.Controls.tabs(oFrame, {Items = {"Work", "Planning"}, TextAlign = "left", MinTabWidth = 150, MaxTabWidth = 150});
        tOwned[#tOwned + 1] = oLeftTabs; oLeftTabs.layout(0, 0, 400, 150);
        local sCenteredTabs, sLeftTabs = fRender(oTabs.draw, 400, 150), fRender(oLeftTabs.draw, 400, 150);
        fCheck(sCenteredTabs ~= sLeftTabs, "Tab alignment remains explicitly configurable.");
        local nFocusParts = 0; local fTabPart = oTheme.draw;
        oTheme.draw = function(oDC, sPart, ...)
            if (sPart == "Tabs Focus") then nFocusParts = nFocusParts + 1; end
            return fTabPart(oDC, sPart, ...);
        end;
        local fHasFocus = oTabs.Control.HasFocus;
        oTabs.Control.HasFocus = function() return true; end;
        local sFocusedTabs = fRender(oTabs.draw, 400, 150);
        oTabs.Control.HasFocus = fHasFocus; oTheme.draw = fTabPart;
        fCheck(nFocusParts == 0, "Tab selection does not draw the old underline material.");
        fCheck(sFocusedTabs == sCenteredTabs, "Tab focus adds no outline or replacement decoration.");
        for _, sFactory in ipairs({"progress", "circularProgress", "globeProgress", "radialProgress", "irisProgress"}) do
            local tPixels = {};
            for nMode = 1, 3 do
                local tOptions = {Min = 0, Max = 100, Value = 53, Text = "53%", Appearance = "skin"};
                if (nMode == 2) then tOptions.Outline = false; end
                if (nMode == 3) then tOptions.OutlineColour = {R = 235, G = 40, B = 90}; tOptions.OutlineWidth = 3; end
                local oMeter = oLuma.Controls[sFactory](oFrame, tOptions);
                tOwned[#tOwned + 1] = oMeter; oMeter.layout(0, 0, 120, 100);
                tPixels[nMode] = fRender(oMeter.draw, 120, 100);
                if (nMode == 1 and sFactory ~= "progress") then
                    local nEdgeByte = (50 * 120 + 107) * 3 + 1;
                    local sEdge = tPixels[nMode]:sub(nEdgeByte, nEdgeByte + 2);
                    fCheck(sEdge ~= fRGB("Editor") and sEdge ~= fRGB("Fill"),
                        sFactory.." default outline is visible at the showcase fill and appearance.");
                end
                fCheck((oMeter.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE,
                    sFactory.." shape outline does not add a rectangular native frame.");
                local fFocus = oMeter.Control.HasFocus;
                oMeter.Control.HasFocus = function() return true; end;
                fCheck(fRender(oMeter.draw, 120, 100) == tPixels[nMode], sFactory.." outline stays stable on focus.");
                oMeter.Control.HasFocus = fFocus;
            end
            fCheck(tPixels[1] ~= tPixels[2], sFactory.." has a visible default shape edge that can be disabled.");
            fCheck(tPixels[3] ~= tPixels[1] and tPixels[3] ~= tPixels[2], sFactory.." honors custom outline color and width.");
        end

        local oSingleLook = oLuma.Controls.slider(oFrame, {Min = 0, Max = 100, Step = 1, Value = 50});
        local oRangeLook = oLuma.Controls.rangeSlider(oFrame, {Min = 0, Max = 100, Step = 1, Value = {Low = 50, High = 50}});
        tOwned[#tOwned + 1] = oSingleLook; tOwned[#tOwned + 1] = oRangeLook;
        oSingleLook.layout(0, 0, 240, 50); oRangeLook.layout(0, 0, 240, 50);
        for _, sProvider in ipairs({"System", "Obsidian"}) do
            oTheme.setName(sProvider);
            fCheck(fRender(oSingleLook.draw, 240, 50) == fRender(oRangeLook.draw, 240, 50),
                "Overlapping range thumbs exactly match the normal slider in "..sProvider..".");
        end
        oTheme.setName("System");

        for _, sFactory in ipairs({"checkbox", "radio"}) do
            for _, nBorder in ipairs({false, _wx.wxBORDER_SIMPLE}) do
                local tOptions = {Text = "Option"};
                if (sFactory == "radio") then tOptions.Group = oLuma.Controls.radioGroup(); tOptions.Value = "option"; end
                if (nBorder ~= false) then tOptions.Border = nBorder; end
                local oIndicator = oLuma.Controls[sFactory](oFrame, tOptions);
                tOwned[#tOwned + 1] = oIndicator;
                fCheck((oIndicator.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK)
                    == (nBorder == false and _wx.wxBORDER_NONE or nBorder),
                    sFactory.." defaults to no outer box and honors explicit borders.");
            end
        end

        local oParentColor = oFrame:GetBackgroundColour();
        oFrame:SetBackgroundColour(_wx.wxWHITE);
        local oCheckBackground = oLuma.Controls.checkbox(oFrame, {Text = ""});
        tOwned[#tOwned + 1] = oCheckBackground; oCheckBackground.layout(0, 0, 200, 40);
        local sCheckBackground = fRender(oCheckBackground.draw, 200, 40);
        fCheck(sCheckBackground:sub(1, 3) == string.char(255, 255, 255),
            "System checkbox inherits its parent's white background.");
        oFrame:SetBackgroundColour(oParentColor);

        for _, sFactory in ipairs({"button", "toggleButton", "imageButton"}) do
            local tOptions = {Text = "Action", Image = oLuma.Config.ImagePath.."/Menu/Command Shield.png"};
            local oButton = oLuma.Controls[sFactory](oFrame, tOptions); tOwned[#tOwned + 1] = oButton;
            oButton.layout(0, 0, 200, 80);
            fCheck((oButton.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE,
                sFactory.." has no outer border by default.");
            local fFocus = oButton.Control.HasFocus;
            oButton.Control.HasFocus = function() return false; end;
            local sPlain = fRender(oButton.draw, 200, 80);
            oButton.Control.HasFocus = function() return true; end;
            local sFocused = fRender(oButton.draw, 200, 80);
            oButton.Control.HasFocus = fFocus;
            fCheck(sPlain == sFocused, sFactory.." adds no focus outline.");
            fCheck(sPlain:sub(1, 200 * 3) == fRGB("Background"):rep(200), sFactory.." paints no replacement frame along its top edge.");
            tOptions.Border = _wx.wxBORDER_SIMPLE;
            local oFramedButton = oLuma.Controls[sFactory](oFrame, tOptions); tOwned[#tOwned + 1] = oFramedButton;
            fCheck((oFramedButton.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_SIMPLE,
                sFactory.." still honors an explicit border.");
        end
        local oKnob = oLuma.Controls.knob(oFrame, {Min = 0, Max = 100, Value = 50, Rate = 5});
        tOwned[#tOwned + 1] = oKnob; oKnob.layout(0, 0, 160, 160);
        local sKnobNormal = fRender(oKnob.draw, 160, 160);
        oKnob.Hover = true;
        fCheck(fRender(oKnob.draw, 160, 160):sub(1, 3) == sKnobNormal:sub(1, 3), "Knob hover does not change its rectangular background.");
        oKnob.Pressed = true;
        fCheck(fRender(oKnob.draw, 160, 160):sub(1, 3) == sKnobNormal:sub(1, 3), "Dragging does not switch the knob background either.");
        oKnob.Hover, oKnob.Pressed = false, false;
        local fKnobFocus = oKnob.Control.HasFocus;
        oKnob.Control.HasFocus = function() return true; end;
        local sKnobFocused = fRender(oKnob.draw, 160, 160);
        oKnob.Control.HasFocus = fKnobFocus;
        fCheck(sKnobFocused == sKnobNormal, "Focused knob adds no border or replacement outline.");
        oKnob.handleKey("down", _wx.WXK_RIGHT);
        fCheck(oKnob.getValue() == 55, "Removing focus decoration retains keyboard value control.");
        for _, sFactory in ipairs({"slider", "rangeSlider"}) do
            for _, bFocusBorder in ipairs({false, true}) do
                local tOptions = {Min = 0, Max = 100, Step = 1,
                    Value = sFactory == "slider" and 50 or {Low = 20, High = 80}};
                if (bFocusBorder) then tOptions.FocusBorder = true; end
                local oSlider = oLuma.Controls[sFactory](oFrame, tOptions); tOwned[#tOwned + 1] = oSlider;
                oSlider.layout(0, 0, 240, 50);
                local fFocus = oSlider.Control.HasFocus;
                oSlider.Control.HasFocus = function() return false; end;
                local sUnfocused = fRender(oSlider.draw, 240, 50);
                oSlider.Control.HasFocus = function() return true; end;
                local sFocused = fRender(oSlider.draw, 240, 50);
                oSlider.Control.HasFocus = fFocus;
                fCheck(sFocused == sUnfocused,
                    "Slider focus never draws a decorative outline, including legacy opt-in.");
            end
        end
        fCheck(oKnob.hitTest(80, 69) and not oKnob.hitTest(0, 0) and not oKnob.hitTest(80, 150),
            "Knob hit geometry includes the dial but excludes corners and caption.");
        local oKnobControl = oKnob.Control;
        local fCapture, fRelease, fCaptured, fFocus = oKnobControl.CaptureMouse, oKnobControl.ReleaseMouse,
            oKnobControl.HasCapture, oKnobControl.SetFocus;
        local bCaptured, nFocusCalls, nKnobClicks = false, 0, 0;
        oKnobControl.CaptureMouse = function() bCaptured = true; end;
        oKnobControl.ReleaseMouse = function() bCaptured = false; end;
        oKnobControl.HasCapture = function() return bCaptured; end;
        oKnobControl.SetFocus = function() nFocusCalls = nFocusCalls + 1; end;
        oKnob.on("leftClick", function() nKnobClicks = nKnobClicks + 1; end);
        --[[!
        @fqxn wxLuma.Tests.SystemRenderingRegression.fKnobMouse
        @desc Dispatches a native mouse event without showing or capturing a window.
        !]]
        local function fKnobMouse(nType, nX, nY)
            local oEvent = _wx.wxMouseEvent(nType);
            oEvent.GetX = function() return nX; end; oEvent.GetY = function() return nY; end;
            oEvent.GetWheelRotation = function() return 120; end; oEvent.GetWheelDelta = function() return 120; end;
            oEvent:SetId(oKnobControl:GetId()); oEvent:SetEventObject(oKnobControl);
            oKnobControl:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
        end
        fKnobMouse(_wx.wxEVT_LEFT_DOWN, 0, 0); fKnobMouse(_wx.wxEVT_MOTION, 80, 40); fKnobMouse(_wx.wxEVT_LEFT_UP, 0, 0);
        fKnobMouse(_wx.wxEVT_MOUSEWHEEL, 80, 150);
        fCheck(oKnob.getValue() == 55 and nFocusCalls == 0 and not bCaptured and nKnobClicks == 0,
            "Outside clicks and caption wheel input do not focus, capture, click or change the knob.");
        fKnobMouse(_wx.wxEVT_LEFT_DOWN, 80, 69); fKnobMouse(_wx.wxEVT_MOTION, 80, 20); fKnobMouse(_wx.wxEVT_LEFT_UP, 80, 69);
        fCheck(oKnob.getValue() > 55 and nFocusCalls == 1 and not bCaptured and nKnobClicks == 1,
            "A drag beginning inside the dial still changes the value and releases capture.");
        oKnobControl.CaptureMouse, oKnobControl.ReleaseMouse, oKnobControl.HasCapture, oKnobControl.SetFocus = fCapture, fRelease, fCaptured, fFocus;

        local pShield = oLuma.Config.ImagePath.."/Menu/Command Shield.png";
        local oImageButton = oLuma.Controls.imageButton(oFrame, {Image = pShield, Text = "Review release"});
        tOwned[#tOwned + 1] = oImageButton; oImageButton.layout(0, 0, 200, 110);
        local sImageButton = fRender(oImageButton.draw, 200, 110);
        fCheck(sImageButton:sub(1, 3) == fRGB("Background"), "Image button corners use the system background.");
        local tCaption = oImageButton.getTextOptions();
        fCheck(string.char(tCaption.TextColour.R, tCaption.TextColour.G, tCaption.TextColour.B) == fRGB("Text"),
            "Inherited image-button caption uses the system foreground.");
        local oStyledImage = oLuma.Controls.imageButton(oFrame, {Image = pShield, Text = "Custom caption", FontSize = 14,
            TextColour = {R = 200, G = 30, B = 40, A = 255}, Background = function(oDC)
                local oBrush = _wx.wxBrush(_wx.wxColour(20, 90, 60)); oDC:SetBackground(oBrush); oDC:Clear(); oBrush:delete();
            end});
        tOwned[#tOwned + 1] = oStyledImage; oStyledImage.layout(0, 0, 200, 110);
        fCheck(fRender(oStyledImage.draw, 200, 110):sub(1, 3) == string.char(20, 90, 60), "Explicit application background painters remain in control.");

        local oBarMaterial = oTheme.getBitmap("Chart Bar Normal"):ConvertToImage();
        fCheck(oBarMaterial:GetRed(0, 0) == 255 and oBarMaterial:GetAlpha(0, 0) == 255,
            "Single-texel bar material is opaque and neutral for series tinting.");
        oBarMaterial:delete();
        for _, tVariant in ipairs({{false, "vertical"}, {true, "vertical"}, {false, "horizontal"}}) do
            local oBars = oLuma.Controls.barChart(oFrame, {Stacked = tVariant[1], Orientation = tVariant[2],
                Legend = false, Grid = false, TickLabels = false, XRange = {Min = 0, Max = 3}, YRange = {Min = 0, Max = 12},
                Series = {{Id = "a", Color = {R = 210, G = 40, B = 60, A = 255},
                    Points = {{Id = "p", X = 1, Y = 4}, {Id = "q", X = 2, Y = 6}}},
                    {Id = "b", Color = {R = 40, G = 100, B = 210, A = 255},
                    Points = {{Id = "p", X = 1, Y = 3}, {Id = "q", X = 2, Y = 5}}}}});
            tOwned[#tOwned + 1] = oBars; oBars.layout(0, 0, 420, 290);
            local sBars = fRender(oBars.draw, 420, 290);
            local nX, nY = oBars.getPointPosition("a", "p");
            local nByte = (math.floor(nY) * 420 + math.floor(nX)) * 3 + 1;
            fCheck(sBars:sub(nByte, nByte + 2) == string.char(210, 40, 60),
                "Grouped, stacked and horizontal bar interiors contain their series color.");
        end

        oTheme.setName("Obsidian");
        local fSkinDraw, sArrowPart = oTheme.drawOpaque;
        oTheme.drawOpaque = function(oDC, sPart, ...)
            sArrowPart = sPart; return fSkinDraw(oDC, sPart, ...);
        end;
        fRender(oDropdown.draw, 240, 40);
        oTheme.drawOpaque = fSkinDraw;
        fCheck(sArrowPart == "Dropdown Arrow Normal", "Skinned dropdowns request their own arrow artwork.");
        for _, oControl in ipairs(tOwned) do fRender(oControl.draw, 240, 100); end
        oTheme.setName("System");
        fCheck(fRender(oProperties.draw, 240, 100) == fRGB("Editor"):rep(240 * 100)
            and oProperties.getValue("name") == "Release", "Property grid roles and values survive provider switching.");
        fCheck(fRender(oSectionLabel.draw, 220, 44):sub(1, 3) == fRGB("Editor")
            and oSection.isExpanded(), "Notes body and child label remain consistent after provider switching.");
        fCheck((oSwitch.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_NONE
            and (oBorderedSwitch.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_SIMPLE,
            "Switch default and explicit border remain unchanged across providers.");
        local tStyled = oStyledImage.getTextOptions();
        fCheck(tStyled.FontSize == 14 and tStyled.TextColour.R == 200 and tStyled.TextColour.G == 30,
            "Provider changes preserve explicit image-button font and color choices.");
        tCaption = oImageButton.getTextOptions();
        fCheck(string.char(tCaption.TextColour.R, tCaption.TextColour.G, tCaption.TextColour.B) == fRGB("Text")
            and oImageButton.getImage() == pShield, "Inherited captions refresh while application images stay unchanged.");
        fCheck(fRender(oCheck.draw, 240, 60) == sCheck, "Returning from Obsidian restores native checkbox pixels.");
        fCheck(oLog.getTextSelection().Finish == 8, "Skin changes retain the selected text range.");
    end, debug.traceback);

    for _, oControl in ipairs(tOwned) do oControl.destroy(); end
    oFrame:Destroy(); _wx.wxYield();
    assert(bOK, sError);
    oTheme.destroy();
    print("System rendering regression: "..nChecks.." checks passed.");
    return nChecks;
end

return SystemRenderingRegression;
