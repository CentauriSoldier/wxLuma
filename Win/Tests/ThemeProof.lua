local _wx = require("wx");
local _load = require("wxLuma");
local _Theme = require("wxLuma.Core.ControlTheme");
local ThemeProof = {};

--[[!
@fqxn wxLuma.Tests.ThemeProof.create
@desc Opens a native comparison window using production wxLuma controls. The
    left column takes its default from configuration; the right shows Obsidian.
    Switching providers updates existing objects without resetting their values.
@ret table tDemo Frame, controls and actions for interactive and regression use.
!]]
function ThemeProof.create()
    local tLuma = _load();
    local Controls = tLuma.Controls;
    local oReferenceTheme = _Theme.create("Obsidian", tLuma.Config.SkinPath);
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "wxLuma - System / Obsidian proof",
        _wx.wxDefaultPosition, _wx.wxDefaultSize);
    oFrame:SetClientSize(1000, 740); oFrame:SetMinClientSize(_wx.wxSize(920, 700));
    local oRoot = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local tOwned, tColumns = {}, {};
    local nClicks = 0;
    local oTitle = _wx.wxStaticText(oRoot, _wx.wxID_ANY, "One control implementation. Two rendering providers.");
    local oExplanation = _wx.wxStaticText(oRoot, _wx.wxID_ANY,
        "Change the left provider, edit its text, and move the iris slider. Values survive switching.");
    local oChoice = _wx.wxChoice(oRoot, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, {"System", "Obsidian"});
    local oSlider = _wx.wxSlider(oRoot, _wx.wxID_ANY, 55, 0, 100);
    local oSliderLabel = _wx.wxStaticText(oRoot, _wx.wxID_ANY, "Iris opening: 55%");
    local oStatus = _wx.wxStaticText(oRoot, _wx.wxID_ANY, "Ready. Left controls were created without Skin or Theme arguments.");
    local oNativeLabel = _wx.wxStaticText(oRoot, _wx.wxID_ANY, "Native wxWidgets references:");
    local oNativeButton = _wx.wxButton(oRoot, _wx.wxID_ANY, "Native button");
    local oNativeText = _wx.wxTextCtrl(oRoot, _wx.wxID_ANY, "Native editor");

    -- Each column uses the same factories, including the disabled-state samples.
    for nColumn, sHeading in ipairs({"Configured provider", "Obsidian reference"}) do
        local oPanel = _wx.wxPanel(oRoot, _wx.wxID_ANY);
        local oTheme = nColumn == 1 and tLuma.Theme or oReferenceTheme;
        local tColumn = {Panel = oPanel, Theme = oTheme, Labels = {}, Controls = {}};
        tColumns[nColumn] = tColumn;
        for nIndex, sText in ipairs({sHeading, "Button", "Native text editor", "Custom iris geometry", "Disabled states"}) do
            tColumn.Labels[nIndex] = _wx.wxStaticText(oPanel, _wx.wxID_ANY, sText);
        end
        for _, bEnabled in ipairs({true, false}) do
            local tOptions = {Enabled = bEnabled};
            if (nColumn == 2) then tOptions.Theme = oTheme; end
            local tButtonOptions, tTextOptions, tIrisOptions = {}, {}, {};
            for sKey, vValue in pairs(tOptions) do
                tButtonOptions[sKey], tTextOptions[sKey], tIrisOptions[sKey] = vValue, vValue, vValue;
            end
            tButtonOptions.Text = bEnabled and "Activate" or "Disabled button";
            tButtonOptions.OnClick = function()
                nClicks = nClicks + 1; oStatus:SetLabel("Button activations: "..nClicks..". Switching does not replace callbacks.");
            end;
            tTextOptions.Value = bEnabled and "Edit me; then switch providers" or "Disabled editor";
            tIrisOptions.Min, tIrisOptions.Max, tIrisOptions.Value = 0, 100, 55;
            tIrisOptions.Text = "%v%";
            local tRow = {Button = Controls.button(oPanel, tButtonOptions),
                Editor = Controls.textfield(oPanel, tTextOptions), Iris = Controls.irisProgress(oPanel, tIrisOptions)};
            tColumn.Controls[bEnabled and "Enabled" or "Disabled"] = tRow;
            for _, oControl in pairs(tRow) do tOwned[#tOwned + 1] = oControl; end
        end
    end

    -- Recolor application-owned panel/label hosts; widget updates come from Theme.
    local function fHosts()
        for nColumn, tColumn in ipairs(tColumns) do
            tColumn.Panel:SetBackgroundColour(tColumn.Theme.color("Background"));
            tColumn.Labels[1]:SetLabel(nColumn == 1 and "Configured provider: "..tLuma.Theme.getName() or "Obsidian reference");
            for _, oLabel in ipairs(tColumn.Labels) do
                oLabel:SetFont(tColumn.Theme.Font); oLabel:SetForegroundColour(tColumn.Theme.color("Text"));
            end
            tColumn.Panel:Refresh(false);
        end
    end

    --[[!
    @fqxn wxLuma.Tests.ThemeProof.setTheme
    @desc Switches the live left context while retaining all control identities.
    !]]
    local function fSetTheme(sName)
        tLuma.Theme.setName(sName); oChoice:SetSelection(sName == "System" and 0 or 1);
        fHosts(); oStatus:SetLabel("Left provider: "..sName..". Existing text, selection and iris values retained.");
    end

    -- Responsive bounds keep native comparison controls separate from the proof.
    local function fLayout()
        local nWidth, nHeight = oRoot:GetClientSizeWH();
        oTitle:SetSize(24, 16, nWidth - 48, 26);
        oExplanation:SetSize(24, 46, nWidth - 48, 24);
        oChoice:SetSize(24, 82, 180, 30);
        oSliderLabel:SetSize(228, 86, 150, 24); oSlider:SetSize(380, 78, nWidth - 404, 36);
        local nColumnWidth = math.floor((nWidth - 64) / 2);
        for nColumn, tColumn in ipairs(tColumns) do
            tColumn.Panel:SetSize(24 + (nColumn - 1) * (nColumnWidth + 16), 130, nColumnWidth, nHeight - 254);
            local tEnabled, tDisabled = tColumn.Controls.Enabled, tColumn.Controls.Disabled;
            local tY = {12, 46, 124, 208, 400};
            for nIndex, oLabel in ipairs(tColumn.Labels) do oLabel:SetSize(16, tY[nIndex], nColumnWidth - 32, 24); end
            tEnabled.Button.layout(16, 72, nColumnWidth - 32, 38);
            tEnabled.Editor.layout(16, 152, nColumnWidth - 32, 38);
            tEnabled.Iris.layout(math.floor((nColumnWidth - 156) / 2), 238, 156, 156);
            tDisabled.Button.layout(16, 428, 166, 36);
            tDisabled.Editor.layout(194, 428, math.max(1, nColumnWidth - 210), 36);
            tDisabled.Iris.layout(nColumnWidth - 80, 334, 64, 64);
        end
        oNativeLabel:SetSize(24, nHeight - 104, 240, 24);
        oNativeButton:SetSize(270, nHeight - 110, 170, 34);
        oNativeText:SetSize(460, nHeight - 110, math.max(1, nWidth - 484), 34);
        oStatus:SetSize(24, nHeight - 54, nWidth - 48, 34);
    end
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL); oSizer:Add(oRoot, 1, _wx.wxEXPAND); oFrame:SetSizer(oSizer);
    oRoot:Connect(_wx.wxEVT_SIZE, function(oEvent) fLayout(); oEvent:Skip(); end);
    oChoice:Connect(_wx.wxEVT_COMMAND_CHOICE_SELECTED, function() fSetTheme(oChoice:GetStringSelection()); end);
    oSlider:Connect(_wx.wxEVT_COMMAND_SLIDER_UPDATED, function()
        local nValue = oSlider:GetValue(); oSliderLabel:SetLabel("Iris opening: "..nValue.."%");
        for _, tColumn in ipairs(tColumns) do
            tColumn.Controls.Enabled.Iris.setValue(nValue); tColumn.Controls.Disabled.Iris.setValue(nValue);
        end
    end);
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        for _, oControl in ipairs(tOwned) do oControl.destroy(); end
        tLuma.Theme.destroy(); oReferenceTheme.destroy(); oEvent:Skip();
    end);
    oChoice:SetSelection(tLuma.Theme.getName() == "System" and 0 or 1);
    fHosts(); oFrame:Layout(); fLayout(); oFrame:Centre();
    return {Frame = oFrame, Root = oRoot, Columns = tColumns, Theme = tLuma.Theme,
        SetTheme = fSetTheme, Slider = oSlider, Choice = oChoice};
end

return ThemeProof;
