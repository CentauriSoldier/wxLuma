local _wx       = require("wx");
local _Controls = require("wxLuma.Controls");
local _Artwork  = require("wxLuma.Core.ControlArtwork");
local _Catalog  = require("Win.Tests.DemoCatalog");
local DemoGallery = {};

--[[!
@fqxn wxLuma.Tests.DemoGallery.getTitles
@desc Returns category titles in the same order as the workbench tab pages.
@ret table tTitles Independent ordered title array.
!]]
function DemoGallery.getTitles()
    local tTitles = {};
    for nIndex, tCategory in ipairs(_Catalog) do tTitles[nIndex] = tCategory.Title; end
    return tTitles;
end

--[[!
@fqxn wxLuma.Tests.DemoGallery.create
@desc Creates scrollable category pages and individually documented sample
    containers before widget construction. Primary objects and their helper
    actions therefore receive their final native parents and containment chains.
@param table oTabs Workbench Tabs component with matching pages.
@param table oSkin Caller-owned shared skin.
@ret table oGallery Demo-only parent, binding, layout, navigation and disposal helpers.
!]]
function DemoGallery.create(oTabs, oSkin)
    local tArt = _Artwork.create(oSkin, "Property Grid");
    local oHeadingFont = _wx.wxFont(oSkin.Font:GetPointSize() + 1, _wx.wxFONTFAMILY_DEFAULT,
        _wx.wxFONTSTYLE_NORMAL, _wx.wxFONTWEIGHT_BOLD);
    local tCategories, tCards, tParents, tByKey = {}, {}, {}, {};
    local tWidgets;
    local bDisposed, bLayout = false, false;
    local oGallery = {Categories = tCategories, Cards = tCards};

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.fPanel
    @desc Creates a clipped native parent whose background follows the skin.
    !]]
    local function fPanel(oParent)
        local oPanel = _wx.wxPanel(oParent, _wx.wxID_ANY, _wx.wxDefaultPosition,
            _wx.wxDefaultSize, _wx.wxBORDER_NONE + _wx.wxTAB_TRAVERSAL + _wx.wxCLIP_CHILDREN);
        oPanel:SetBackgroundColour(tArt.color("Surface Normal"));
        return oPanel;
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.fText
    @desc Creates nonfocusable documentation text using the shared skin font.
    !]]
    local function fText(oParent, sText, bMuted)
        local oText = _wx.wxStaticText(oParent, _wx.wxID_ANY, sText);
        oText:SetFont(oSkin.Font);
        oText:SetForegroundColour(tArt.color(bMuted and "Text Disabled" or "Text Normal"));
        return oText;
    end

    for nIndex, tSpec in ipairs(_Catalog) do
        local oScroll = _Controls.scrollContainer(oTabs.Pages[nIndex], {Skin = oSkin, Step = 40});
        oScroll.Content:SetBackgroundColour(tArt.color("Surface Normal"));
        local tCategory = {Id = tSpec.Id, Title = tSpec.Title, Index = nIndex, Scroll = oScroll, Cards = {}};
        tCategories[nIndex] = tCategory;

        for _, tCardSpec in ipairs(tSpec.Cards) do
            assert(not tCards[tCardSpec.Id], "Duplicate demo card: "..tCardSpec.Id);
            local oCard = fPanel(oScroll.Content);
            oCard:SetBackgroundStyle(_wx.wxBG_STYLE_PAINT);
            local tCard = {Id = tCardSpec.Id, Spec = tCardSpec, Category = tCategory, Control = oCard,
                Preview = fPanel(oCard), Actions = fPanel(oCard), ActionLabels = {}};
            tCard.Description = fText(oCard, tCardSpec.Description, false);
            tCard.Usage = fText(oCard, "Usage: "..tCardSpec.Usage.."\nAPI: "..tCardSpec.API, true);
            tCards[tCard.Id], tCategory.Cards[#tCategory.Cards + 1] = tCard, tCard;
            for _, sGroup in ipairs({"Primary", "Logical", "Actions"}) do
                for _, sKey in ipairs(tCardSpec[sGroup] or {}) do
                    assert(not tByKey[sKey], "Demo object belongs to two cards: "..sKey);
                    tByKey[sKey] = tCard;
                    tParents[sKey] = sGroup == "Actions" and tCard.Actions or tCard.Preview;
                end
            end
            oCard:Connect(_wx.wxEVT_PAINT, function()
                local oDC = _wx.wxAutoBufferedPaintDC(oCard);
                if (not bDisposed) then
                    local nWidth, nHeight = oCard:GetClientSizeWH();
                    tArt.part(oDC, "Surface Normal", 0, 0, nWidth, nHeight);
                    oSkin.draw(oDC, "Toolbar Item Normal", 0, 0, nWidth, 42);
                    tArt.part(oDC, "Separator", 0, nHeight - 1, nWidth, 1);
                    tArt.part(oDC, "Separator", 0, 0, 1, nHeight);
                    tArt.part(oDC, "Separator", nWidth - 1, 0, 1, nHeight);
                    oDC:SetFont(oHeadingFont); oDC:SetTextForeground(tArt.color("Text Normal"));
                    oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
                    oDC:SetClippingRegion(16, 0, math.max(1, nWidth - 32), 42);
                    oDC:DrawText(tCardSpec.Title, 16, 10); oDC:DestroyClippingRegion();
                end
                oDC:delete();
            end);
        end
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.parent
    @desc Returns an object's final native sample/action parent, or the fallback
        for nested application children and lifetime-owned top-level dialogs.
    @param string sKey Registered demo widget key.
    @param wxWindow oFallback Original native parent.
    @ret wxWindow oParent Native parent for creation.
    !]]
    function oGallery.parent(sKey, oFallback) return tParents[sKey] or oFallback; end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.fWrap
    @desc Measures native wrapped documentation after restoring its unwrapped
        source. Repeated resizes cannot accumulate inserted line breaks.
    !]]
    local function fWrap(oText, sText, nX, nY, nWidth)
        oText:SetLabel(sText); oText:Wrap(nWidth);
        local oSize = oText:GetBestSize(); local nHeight = oSize:GetHeight(); oSize:delete();
        oText:SetSize(nX, nY, nWidth, math.max(1, nHeight));
        return nHeight;
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.fPreview
    @desc Fits live samples while preserving their widget-specific shape and
        native ownership. User-resized panels retain their size within bounds.
    !]]
    local function fPreview(tCard, nWidth, nHeight)
        local tKeys = tCard.Spec.Primary;
        for nIndex, sKey in ipairs(tKeys) do
            local oWidget = assert(tWidgets[sKey], "Missing demo sample: "..sKey);
            local nX, nY, nW, nH = 0, 0, nWidth, nHeight;
            local sMode = tCard.Spec.Mode;
            if (sMode == "meters") then
                local nLinearWidth = math.max(1, nWidth - 220);
                if (sKey == "CircularProgress") then
                    nW, nH = math.min(200, nWidth), math.min(200, nHeight);
                    nX = nWidth - nW;
                elseif (sKey == "DirectionalProgress") then
                    nY = 150;
                    nW = oWidget.getOrientation() == "vertical" and 54 or math.min(300, nLinearWidth);
                    nH = oWidget.getOrientation() == "vertical" and 160 or 40;
                else nW, nH, nY = nLinearWidth, 36, (nIndex - 1) * 44; end
            elseif (sMode == "sliders") then
                nW, nH = nIndex == 1 and nWidth or 44, nIndex == 1 and 44 or 180;
                nY = nIndex == 1 and 0 or 56;
            elseif (sMode == "columns" or sMode == "orbs") then
                local nColumn = math.floor((nWidth - (#tKeys - 1) * 12) / #tKeys);
                nW, nX = nColumn, (nIndex - 1) * (nColumn + 12);
                if (sMode == "orbs") then
                    nW, nH = math.min(220, nColumn), math.min(220, nColumn);
                    nX = nX + math.floor((nColumn - nW) / 2);
                end
            elseif (sMode == "imageButton") then nW = math.min(200, nWidth);
            elseif (sMode == "panel") then
                nW, nH = oWidget.Control:GetSizeWH();
                if (nW <= 20 or nH <= 20) then nW, nH = 440, 220; end
                nW, nH = math.min(nW, nWidth), math.min(nH, nHeight);
            elseif (sMode == "disclosure") then nH = math.min(nHeight, oWidget.getBestHeight());
            else
                nH = math.floor((nHeight - (#tKeys - 1) * 8) / #tKeys);
                nY = (nIndex - 1) * (nH + 8);
                if (oWidget.Kind == "Button" or oWidget.Kind == "ToggleButton" or oWidget.Kind == "NumericField"
                    or oWidget.Kind == "ColorPicker") then nW = math.min(420, nWidth);
                elseif (oWidget.Kind == "Spinner") then nW = math.min(220, nWidth); end
            end
            if (not oWidget.isFloating or not oWidget.isFloating()) then
                oWidget.layout(nX, nY, math.max(1, nW), math.max(1, nH));
            end
            if (sMode == "panel") then oWidget.resize(nW, nH); end
        end
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.fCardLayout
    @desc Measures documentation, reserves an unclipped preview and arranges
        sample actions into readable columns without shrinking controls to fit.
    @ret number nHeight Complete card height in client pixels.
    !]]
    local function fCardLayout(tCard, nWidth)
        local tSpec = tCard.Spec;
        local nInner = math.max(1, nWidth - 32);
        if (tCard.LayoutWidth == nWidth) then
            fPreview(tCard, nInner, tSpec.Height);
            return tCard.LayoutHeight;
        end
        local nY = 54;
        nY = nY + fWrap(tCard.Description, tSpec.Description, 16, nY, nInner) + 10;
        nY = nY + fWrap(tCard.Usage, "Usage: "..tSpec.Usage.."\nAPI: "..tSpec.API, 16, nY, nInner) + 18;
        tCard.PreviewY = nY;
        tCard.Preview:SetSize(16, nY, nInner, tSpec.Height);
        fPreview(tCard, nInner, tSpec.Height);
        nY = nY + tSpec.Height;
        local tActions = tSpec.Actions or {};
        if (#tActions > 0) then
            local nColumns = math.max(1, math.min(3, math.floor((nInner + 12) / 260)));
            local nCell = math.floor((nInner - (nColumns - 1) * 12) / nColumns);
            local nRows = math.ceil(#tActions / nColumns);
            tCard.Actions:SetSize(16, nY + 14, nInner, nRows * 68);
            for nIndex, sKey in ipairs(tActions) do
                local oWidget = assert(tWidgets[sKey], "Missing demo action: "..sKey);
                local nX = ((nIndex - 1) % nColumns) * (nCell + 12);
                local nTop = math.floor((nIndex - 1) / nColumns) * 68;
                local oLabel = tCard.ActionLabels[sKey];
                if (oLabel) then oLabel:SetSize(nX, nTop, nCell, 22); end
                local nActionHeight = oWidget.Kind == "Checkbox" and 36 or oWidget.Kind == "Label" and 56 or 40;
                oWidget.layout(nX, nTop + (oLabel and 24 or 0), nCell, nActionHeight);
            end
            nY = nY + 14 + nRows * 68;
            tCard.Actions:Show(true);
        else tCard.Actions:Hide(); end
        tCard.LayoutWidth, tCard.LayoutHeight = nWidth, nY + 18;
        return tCard.LayoutHeight;
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.layout
    @desc Reflows all categories. A second pass accounts for scrollbar width;
        content extents keep every card reachable at the minimum window size.
    !]]
    function oGallery.layout()
        if (bDisposed or bLayout or not tWidgets) then return; end
        bLayout = true;
        for _, tCategory in ipairs(tCategories) do
            local nWidth, nHeight = oTabs.Pages[tCategory.Index]:GetClientSizeWH();
            tCategory.Scroll.layout(0, 0, math.max(1, nWidth), math.max(1, nHeight));
            for nPass = 1, 2 do
                local nView = tCategory.Scroll.getViewportSize();
                local nCardWidth = math.max(1, nView - 32);
                local nY = 16;
                for _, tCard in ipairs(tCategory.Cards) do
                    local nCardHeight = fCardLayout(tCard, nCardWidth);
                    tCard.Y, tCard.Height = nY, nCardHeight;
                    tCard.Control:SetSize(16, nY, nCardWidth, nCardHeight);
                    nY = nY + nCardHeight + 18;
                end
                tCategory.Scroll.setContentSize(0, nY);
            end
        end
        bLayout = false;
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.bind
    @desc Binds live example objects after their constructors have completed.
        Small numeric/slider actions receive explicit captions beside their demos.
    @param table tSamples Widget registry owned by UI.lua.
    !]]
    function oGallery.bind(tSamples)
        assert(not tWidgets, "Demo gallery is already bound.");
        tWidgets = tSamples;
        for _, tCard in pairs(tCards) do
            for _, sKey in ipairs(tCard.Spec.Actions or {}) do
                local oWidget = assert(tWidgets[sKey], "Missing demo action: "..sKey);
                if (oWidget.Kind == "Slider" or oWidget.Kind == "Spinner") then
                    tCard.ActionLabels[sKey] = fText(tCard.Actions, sKey:gsub("(%l)(%u)", "%1 %2"), false);
                end
            end
        end
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.layoutCard
    @desc Reflows after an example changes its geometry policy.
    @param string sKey Card ID or registered widget key.
    !]]
    function oGallery.layoutCard(sKey)
        assert(tCards[sKey] or tByKey[sKey], "Unknown demo card.");
        oGallery.layout();
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.getCategoryIndex
    @desc Resolves a category ID, card ID or widget key to its tab index.
    @ret number nIndex Category tab index.
    !]]
    function oGallery.getCategoryIndex(sKey)
        local tCard = tByKey[sKey] or tCards[sKey];
        if (tCard) then return tCard.Category.Index; end
        for _, tCategory in ipairs(tCategories) do if (tCategory.Id == sKey) then return tCategory.Index; end end
        error("Unknown demo category: "..tostring(sKey));
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.focusCategory
    @desc Gives page scrolling its navigation keys without jumping to a sample
        that may be outside the current viewport. Sample controls retain Tab focus.
    !]]
    function oGallery.focusCategory(nIndex)
        if (not bDisposed and tCategories[nIndex]) then tCategories[nIndex].Scroll.Control:SetFocus(); end
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.show
    @desc Selects an object's category and scrolls to its documentation or live
        preview. Useful for cross-category demo actions and regression fixtures.
    @param string sKey Card ID or widget key.
    @param boolean|nil bPreview Scroll directly to the live preview when true.
    @ret table tCard Demo container record.
    !]]
    function oGallery.show(sKey, bPreview)
        local tCard = assert(tByKey[sKey] or tCards[sKey], "Unknown demo object: "..tostring(sKey));
        oTabs.setValue(tCard.Category.Index, true);
        oGallery.layout();
        local nOffset = 0;
        if (bPreview) then
            nOffset = tCard.PreviewY;
            local oWidget = tWidgets[sKey];
            local oParent = tParents[sKey];
            if (oWidget and (oParent == tCard.Preview or oParent == tCard.Actions)
                and oWidget.Control:GetParent():GetId() == oParent:GetId()) then
                local nUnused, nParentY = oParent:GetPositionXY();
                local nChildY; nUnused, nChildY = oWidget.Control:GetPositionXY();
                nOffset = nParentY + nChildY;
            end
        end
        tCard.Category.Scroll.scrollTo(0, tCard.Y + nOffset);
        return tCard;
    end

    --[[!
    @fqxn wxLuma.Tests.DemoGallery.destroy
    @desc Disposes demo scaffolding once. Native card/text ownership stays with
        the workbench frame; caller disposes samples before the shared skin.
    !]]
    function oGallery.destroy()
        if (bDisposed) then return; end
        bDisposed = true;
        for _, tCategory in ipairs(tCategories) do tCategory.Scroll.destroy(); end
        oHeadingFont:delete(); tArt.destroy();
    end
    return oGallery;
end

return DemoGallery;
