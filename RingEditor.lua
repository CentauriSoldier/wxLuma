--[[!
    @fqxn Examples.RingEditor
    @desc Standalone wxLuma affix editor. Ring extends CoGObject directly; its
    inherited AffixSystem owns applications while ring callbacks own stat effects.
    Modifier names are inspired by action RPGs; values and rules are test data.
    The host supplies wxLua and LuaEx on package.path before requiring this file.
!]]
local _wx        = require("wx");
local _Framework = require("wxLuma")();
local _Controls  = _Framework.Controls;

if (not LUAEX_INIT) then
    -- LuaEx geometry expects the two-argument angle alias on Lua 5.4 hosts.
    math.atan2 = math.atan2 or function(nY, nX) return math.atan(nY, nX); end;
    require("LuaEx.load")();
end

local RingEditor = {};
local _eTier     = luaex.cog.config.TIER;
local _tStats    = {
    {key = "life", label = "Maximum life"},
    {key = "mana", label = "Maximum mana"},
    {key = "shield", label = "Energy shield"},
    {key = "physicalMin", label = "Minimum physical damage"},
    {key = "physicalMax", label = "Maximum physical damage"},
    {key = "rarity", label = "Item rarity (%)"},
    {key = "fire", label = "Fire resistance (%)"},
    {key = "cold", label = "Cold resistance (%)"},
    {key = "lightning", label = "Lightning resistance (%)"},
    {key = "strength", label = "Strength"},
    {key = "dexterity", label = "Dexterity"},
    {key = "accuracy", label = "Accuracy rating"},
};
local _tBases = {
    {name = "Coral Ring", implicit = "+25 to maximum life", stats = {life = 25}, gem = "#CB6262"},
    {name = "Iron Ring", implicit = "Adds 1 to 4 physical damage", stats = {physicalMin = 1, physicalMax = 4}, gem = "#B4BDC8"},
    {name = "Prismatic Ring", implicit = "+8% to all elemental resistances", stats = {fire = 8, cold = 8, lightning = 8}, gem = "#62C4BA"},
    {name = "Gold Ring", implicit = "15% increased rarity of items found", stats = {rarity = 15}, gem = "#D6B35C"},
};
local _tDefinitions = {
    {id = "ring.life", name = "Healthy", kind = "PREFIX", stats = {"life"}, label = "maximum life", start = 12, step = 8, range = 9},
    {id = "ring.mana", name = "Savant's", kind = "PREFIX", stats = {"mana"}, label = "maximum mana", start = 10, step = 7, range = 8},
    {id = "ring.shield", name = "Glimmering", kind = "PREFIX", stats = {"shield"}, label = "energy shield", start = 4, step = 5, range = 6},
    {id = "ring.damage", name = "Glinting", kind = "PREFIX", stats = {"physicalMin", "physicalMax"}, label = "physical damage", start = 1, step = 1, range = 3},
    {id = "ring.rarity", name = "Glittering", kind = "PREFIX", stats = {"rarity"}, label = "item rarity (%)", start = 4, step = 3, range = 4},
    {id = "ring.accuracy", name = "Precise", kind = "PREFIX", stats = {"accuracy"}, label = "accuracy rating", start = 30, step = 45, range = 40},
    {id = "ring.fire", name = "of Embers", kind = "SUFFIX", stats = {"fire"}, label = "fire resistance (%)", start = 8, step = 5, range = 6},
    {id = "ring.cold", name = "of Frost", kind = "SUFFIX", stats = {"cold"}, label = "cold resistance (%)", start = 8, step = 5, range = 6},
    {id = "ring.lightning", name = "of Sparks", kind = "SUFFIX", stats = {"lightning"}, label = "lightning resistance (%)", start = 8, step = 5, range = 6},
    {id = "ring.allRes", name = "of the Prism", kind = "SUFFIX", stats = {"fire", "cold", "lightning"}, label = "all elemental resistances (%)", start = 3, step = 2, range = 3},
    {id = "ring.strength", name = "of the Bear", kind = "SUFFIX", stats = {"strength"}, label = "strength", start = 6, step = 4, range = 5},
    {id = "ring.dexterity", name = "of the Fox", kind = "SUFFIX", stats = {"dexterity"}, label = "dexterity", start = 6, step = 4, range = 5},
};
--[[!
    @fqxn Examples.RingEditor.roll
    @desc Interprets the selected tier's generic data as repeatable stat rolls.
    @param table tValues Generic payload copied from the affix's selected tier.
    @param number nQuality Roll quality from zero through one hundred.
    @ret table tChanges Ordered stat/amount pairs for the application journal.
!]]
local function roll(tValues, nQuality)
    assert(rawtype(nQuality) == "number" and nQuality >= 0 and nQuality <= 100, "Roll quality must be between 0 and 100.");
    local nAmount = tValues.base + math.floor(tValues.range * nQuality / 100);
    local tChanges = {};
    for nIndex, sStat in ipairs(tValues.stats) do
        -- Physical damage has a separate maximum; all-resistance mods add equally.
        tChanges[nIndex] = {stat = sStat, amount = nAmount + (sStat == "physicalMax" and tValues.physicalMaxBonus or 0)};
    end
    return tChanges;
end

--[[!
    @fqxn Examples.RingEditor.describe
    @desc Describes the exact rolled values shown in the catalogue and item card.
    @param table tValues Selected tier's generic test payload.
    @param number nQuality Roll quality percentage.
    @ret string sDescription Human-readable modifier text.
!]]
local function describe(tValues, nQuality)
    local tChanges = roll(tValues, nQuality);
    if (tValues.damageRange) then
        return "Adds "..tChanges[1].amount.." to "..tChanges[2].amount.." physical damage";
    end
    return "+"..tChanges[1].amount.." to "..tValues.label;
end

--[[!
    @fqxn Examples.RingEditor.onAdd
    @desc Implements the host's affix effect. Records exact changes before applying
    them so removal reverses this application rather than recalculating a new roll.
    @param AffixSystemEntry oAffix Applied entry, providing its owner and tier.
    @param table tJournal Application-owned journal.
    @param number nQuality Original roll quality, retained by AffixSystem.
!]]
local function onAdd(oAffix, tJournal, nQuality)
    local tValues = oAffix.getValues();
    tJournal.changes = {};
    tJournal.quality = nQuality;
    tJournal.description = describe(tValues, nQuality);
    for _, tChange in ipairs(roll(tValues, nQuality)) do
        oAffix.getOwner().adjustStat(tChange.stat, tChange.amount);
        tJournal.changes[#tJournal.changes + 1] = tChange;
    end
end

--[[!
    @fqxn Examples.RingEditor.onRemove
    @desc Reverses the exact stat deltas recorded by the add callback.
    @param AffixSystemEntry oAffix Entry whose owner still exists during removal.
    @param table tJournal Saved application journal.
!]]
local function onRemove(oAffix, tJournal)
    for _, tChange in ipairs(tJournal.changes or {}) do
        oAffix.getOwner().adjustStat(tChange.stat, -tChange.amount);
    end
end

-- Ring is global so LuaEx can resolve the declared class when restoring saves.
Ring = class("Ring", {}, {}, {
    baseIndex = 1,
    stats = {},
}, {}, {
    --[[!
        @fqxn Examples.Ring.Methods.Ring
        @pulsarlua function Ring
        @desc Creates a CoGObject with independent stat Proteans and implicit base
        values. Affix lifecycle callbacks are supplied by this example's host.
        @param number nBase Index of the example ring base.
        @param Rarity.LEVEL eRarity CoG rarity governing affix eligibility.
    !]]
    Ring = function(this, cdat, super, nBase, eRarity)
        local tBase = assert(_tBases[nBase], "Unknown ring base.");
        super(tBase.name, "An experimental ring for testing CoG affixes.", eRarity);
        cdat.pri.baseIndex = nBase;
        for _, tStat in ipairs(_tStats) do
            cdat.pri.stats[tStat.key] = Protean(tBase.stats[tStat.key] or 0);
        end
        this.getAffixSystem().setOnAddCallback(onAdd).setOnRemoveCallback(onRemove);
    end,

    --[[!
        @fqxn Examples.Ring.Methods.getBaseIndex
        @pulsarlua function Ring.getBaseIndex
        @desc Identifies the base and its separate implicit modifier.
        @ret number nBase Base index.
    !]]
    getBaseIndex__FNL = function(this, cdat)
        return cdat.pri.baseIndex;
    end,

    --[[!
        @fqxn Examples.Ring.Methods.getStat
        @pulsarlua function Ring.getStat
        @desc Returns the owned stat Protean, or its selected numeric value. The
        caller can adjust the Protean but cannot replace the ring's reference.
        @param string sStat Stat key from the example catalogue.
        @param number|nil nType Optional Protean value category.
        @ret Protean|number vStat Owned Protean or numeric value.
    !]]
    getStat__FNL = function(this, cdat, sStat, nType)
        local oStat = assert(cdat.pri.stats[sStat], "Unknown ring stat.");
        return nType == nil and oStat or oStat.getValue(nType);
    end,

    --[[!
        @fqxn Examples.Ring.Methods.adjustStat
        @pulsarlua function Ring.adjustStat
        @desc Adds a host-defined affix delta to BASE_BONUS, leaving implicit BASE
        values separate. Multiple effects on the same stat stack independently.
        @param string sStat Stat key.
        @param number nAmount Finite signed delta.
        @ret Ring this This ring.
    !]]
    adjustStat__FNL = function(this, cdat, sStat, nAmount)
        assert(rawtype(nAmount) == "number" and nAmount == nAmount and math.abs(nAmount) < math.huge, "Expected a finite stat delta.");
        local oStat = this.getStat(sStat);
        oStat.setValue(Protean.BASE_BONUS, oStat.getValue(Protean.BASE_BONUS) + nAmount);
        return this;
    end,

    --[[!
        @fqxn Examples.Ring.Methods.getDisplayName
        @pulsarlua function Ring.getDisplayName
        @desc Composes the affixed name without overriding CoGObject's base getter.
        @ret string sName AffixSystem's deterministic display name.
    !]]
    getDisplayName__FNL = function(this, cdat)
        return this.getAffixSystem().getName(this.getName());
    end,
}, CoGObject, false, nil);
RingEditor.Ring = Ring;

-- All tier keys are explicit enum members. IDs are opaque catalogue identities.
local _tPatterns = {};
for _, tDefinition in ipairs(_tDefinitions) do
    local tTiers = {};
    for nTier = 1, AffixSystem.MAX_TIER.id do
        tTiers[_eTier[nTier]] = {
            stats = tDefinition.stats,
            base = tDefinition.start + (nTier - 1) * tDefinition.step,
            range = tDefinition.range,
            label = tDefinition.label,
            physicalMaxBonus = nTier + 2,
            damageRange = tDefinition.id == "ring.damage",
        };
    end
    _tPatterns[tDefinition.id] = {
        type = AffixSystem.TYPE[tDefinition.kind], name = tDefinition.name,
        classes = {Ring}, tiers = tTiers, description = tDefinition.label,
    };
end
AffixSystem.registerDefinitions(_tPatterns);

--[[!
    @fqxn Examples.RingEditor.createAffix
    @pulsarlua function RingEditor.createAffix
    @desc Creates an independent ring-compatible entry. Definition IDs identify
    modifier families, so a different tier/roll cannot bypass duplicate rejection.
    @param number nDefinition Catalogue index.
    @param number nTier CoG tier ordinal.
    @ret AffixSystemEntry oAffix New entry; pass roll quality to applyAffix.
!]]
function RingEditor.createAffix(nDefinition, nTier)
    local tDefinition = assert(_tDefinitions[nDefinition], "Unknown ring modifier.");
    local eTier = assert(_eTier[nTier], "Unknown CoG tier.");
    return AffixSystem.createAffix(tDefinition.id, eTier);
end

--[[!
    @fqxn Examples.RingEditor.createDemo
    @pulsarlua function RingEditor.createDemo
    @desc Creates the standalone skinned editor. Call Frame:Show and run the wx
    event loop in the host. Controls and native drawing resources dispose on close.
    @ret table oDemo Frame, Controls, getRing, refresh and dispose test/host access.
!]]
function RingEditor.createDemo()
    local oFrame  = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "CoG Ring Editor", _wx.wxDefaultPosition, _wx.wxSize(1340, 930));
    local oSkin   = _Controls.loadSkin();
    local oWindow = _Framework.Window.create(oFrame, {Title = "THE RING WORKSHOP", Subtitle = "CoGObject / AffixSystem / wxLuma"});
    local oParent = oWindow.Control;
    local tControls, tOwned, tApplied = {}, {}, {};
    local oRing = Ring(1, Rarity.LEVEL.RARE);
    local bDisposed = false;
    local fRefresh;
    oFrame:SetMinClientSize(_wx.wxSize(1180, 850));

    --[[!
        @fqxn Examples.RingEditor.createDemo.widget
        @desc Constructs a skinned control and records disposal ownership.
        @param string sKey Public demo control key.
        @param string sFactory Controls factory name.
        @param table tOptions Control options without the shared skin.
        @ret table oControl Created component.
    !]]
    local function fWidget(sKey, sFactory, tOptions)
        tOptions.Skin = oSkin;
        local oControl = _Controls[sFactory](oParent, tOptions);
        tControls[sKey] = oControl;
        tOwned[#tOwned + 1] = oControl;
        return oControl;
    end

    --[[!
        @fqxn Examples.RingEditor.createDemo.status
        @desc Shows action results and the framework's actual rejection messages.
        @param string sText User-facing result.
    !]]
    local function fStatus(sText)
        tControls.Status.setValue(sText);
    end

    fWidget("BaseHeading", "label", {Value = "NEW RING BASE"});
    fWidget("Base", "dropdown", {Items = {"Coral Ring", "Iron Ring", "Prismatic Ring", "Gold Ring"}, Value = 1, Rows = 4});
    fWidget("RarityHeading", "label", {Value = "CURRENT RARITY"});
    local tRarities, tRarityNames = {}, {};
    for nIndex = 1, #luaex.cog.config.Rarity.LEVEL do
        tRarities[nIndex] = Rarity.LEVEL[nIndex];
        tRarityNames[nIndex] = luaex.cog.config.Rarity.LEVEL[nIndex];
    end
    fWidget("Rarity", "dropdown", {Items = tRarityNames, Value = Rarity.LEVEL.RARE.id, Rows = 6,
        OnChange = function(nIndex)
            local _, bChanged, _, sReason = oRing.setRarity(tRarities[nIndex]);
            fRefresh();
            fStatus(bChanged and "Rarity changed; existing affixes were preserved." or sReason);
        end,
    });
    fWidget("New", "button", {Text = "New ring", OnClick = function()
        oRing = Ring(tControls.Base.getValue(), tRarities[tControls.Rarity.getValue()]);
        fRefresh();
        fStatus("Created a clean "..oRing.getName()..". Its implicit does not occupy an affix slot.");
    end});
    fWidget("RingName", "label", {Value = "", Wrap = true});
    fWidget("Implicit", "label", {Value = "", Wrap = true});
    fWidget("StatsHeading", "label", {Value = "TOTAL RING STATS"});
    fWidget("Stats", "label", {Value = "", Wrap = false});
    fWidget("AvailableHeading", "label", {Value = "AFFIX CATALOGUE"});
    local tCatalogue = {};
    for nIndex, tDefinition in ipairs(_tDefinitions) do
        tCatalogue[nIndex] = (tDefinition.kind == "PREFIX" and "P  " or "S  ")..tDefinition.name;
    end
    fWidget("Available", "list", {Items = tCatalogue, Value = 1, RowHeight = 28, OnChange = function() fRefresh(); end});
    fWidget("TierHeading", "label", {Value = "TIER"});
    local tTierNames = {};
    for nIndex = 1, AffixSystem.MAX_TIER.id do
        tTierNames[nIndex] = _eTier[nIndex].name;
    end
    fWidget("Tier", "dropdown", {Items = tTierNames, Value = 3, Rows = #tTierNames, OnChange = function() fRefresh(); end});
    fWidget("RollHeading", "label", {Value = "ROLL QUALITY (%)"});
    fWidget("Roll", "numericField", {Min = 0, Max = 100, Value = 75, Precision = 0, Step = 5, OnChange = function() fRefresh(); end});
    fWidget("Candidate", "label", {Value = "", Wrap = true});
    fWidget("Add", "button", {Text = "Add selected affix", OnClick = function()
        local oAffix = RingEditor.createAffix(tControls.Available.getValue(), tControls.Tier.getValue());
        local _, bApplied, _, sReason = oRing.getAffixSystem().applyAffix(oAffix, tControls.Roll.getValue());
        fRefresh();
        fStatus(bApplied and ("Added "..oAffix.getName()..". Host callback applied its stat modifiers.") or sReason);
    end});
    fWidget("AppliedHeading", "label", {Value = "APPLIED AFFIXES"});
    fWidget("Limits", "label", {Value = "", Wrap = true});
    fWidget("Applied", "list", {Items = {}, RowHeight = 32, OnChange = function() fRefresh(); end});
    fWidget("AppliedDetail", "label", {Value = "", Wrap = true});
    fWidget("Remove", "button", {Text = "Remove selected", OnClick = function()
        local oAffix = tApplied[tControls.Applied.getValue()];
        if (not oAffix) then
            return;
        end
        local _, bRemoved, _, sReason = oRing.getAffixSystem().removeAffix(oAffix);
        fRefresh();
        fStatus(bRemoved and ("Removed "..oAffix.getName()..". Its recorded modifiers were reversed.") or sReason);
    end});
    fWidget("Clear", "button", {Text = "Remove all affixes", OnClick = function()
        for _, oAffix in oRing.getAffixSystem().eachAffix() do
            local _, bRemoved, _, sReason = oRing.getAffixSystem().removeAffix(oAffix);
            if (not bRemoved) then
                fRefresh();
                fStatus(sReason);
                return;
            end
        end
        fRefresh();
        fStatus("All explicit affixes removed. Base implicit and base stats remain.");
    end});
    fWidget("Status", "label", {Value = "", Wrap = true});
    fWidget("Hint", "label", {Value = "Test data inspired by Path of Exile. Uses CoG's configured rarity limits; higher tier ordinals are stronger here.", Wrap = true});

    -- The preview is application drawing; all editing controls use wxLuma.
    local oPreview = _wx.wxPanel(oParent, _wx.wxID_ANY);
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oBand       = _wx.wxBrush(_wx.wxColour(166, 120, 51));
    local oEdge       = _wx.wxPen(_wx.wxColour(225, 190, 106), 3, _wx.wxPENSTYLE_SOLID);
    local oHighlight  = _wx.wxBrush(_wx.wxColour(236, 230, 197));
    local oGem = _wx.wxBrush(_wx.wxColour(_tBases[1].gem));
    oPreview:Connect(_wx.wxEVT_PAINT, function()
        if (bDisposed) then
            return;
        end
        local oDC = _wx.wxPaintDC(oPreview);
        local nWidth = oPreview:GetClientSizeWH();
        local nX = math.floor(nWidth / 2);
        oDC:SetBackground(oBackground);
        oDC:Clear();
        oDC:SetPen(oEdge);
        oDC:SetBrush(oBand);
        oDC:DrawEllipse(nX - 53, 35, 106, 100);
        oDC:SetBrush(oBackground);
        oDC:DrawEllipse(nX - 35, 50, 70, 68);
        oDC:SetBrush(oGem);
        oDC:DrawCircle(nX, 38, 24);
        oDC:SetBrush(oHighlight);
        oDC:DrawCircle(nX - 7, 30, 5);
        oDC:delete();
    end);

    --[[!
        @fqxn Examples.RingEditor.createDemo.refresh
        @desc Rebuilds UI values from the real ring/component. Preflight uses the
        same canApplyAffix rules as mutation, so rejected candidates cannot apply.
    !]]
    fRefresh = function()
        if (bDisposed) then
            return;
        end
        local oSystem = oRing.getAffixSystem();
        tControls.RingName.setValue(oRing.getDisplayName());
        tControls.Implicit.setValue("IMPLICIT\n".._tBases[oRing.getBaseIndex()].implicit);
        tControls.Rarity.setValue(oRing.getRarity().id);
        local tLines = {};
        for _, tStat in ipairs(_tStats) do
            tLines[#tLines + 1] = string.format("%s: %d", tStat.label, oRing.getStat(tStat.key, Protean.VALUE_FINAL));
        end
        tControls.Stats.setValue(table.concat(tLines, "\n"));
        tControls.Limits.setValue(string.format("Prefixes %d / %d   |   Suffixes %d / %d\nMaximum tier: %s",
            oSystem.getPrefixCount(), oSystem.getMaxPrefixes(), oSystem.getSuffixCount(), oSystem.getMaxSuffixes(), Rarity.getMaxAffixTier(oRing.getRarity()).name));

        local tItems = {};
        local oSelected = tApplied[tControls.Applied.getValue()];
        local nSelected = 0;
        tApplied = {};
        for nIndex, oAffix in oSystem.eachAffix() do
            tApplied[nIndex] = oAffix;
            tItems[nIndex] = (oAffix.isPrefix() and "P  " or "S  ")..oAffix.getName().."  ["..oAffix.getTier().name.."]";
            if (rawequal(oSelected, oAffix)) then
                nSelected = nIndex;
            end
        end
        tControls.Applied.setItems(tItems);
        tControls.Applied.setValue(nSelected > 0 and nSelected or (#tItems > 0 and 1 or 0));
        oSelected = tApplied[tControls.Applied.getValue()];
        tControls.AppliedDetail.setValue(oSelected and ((oSelected.getJournal().description or oSelected.getDescription()).."\nRoll quality: "..oSelected.getJournal().quality.."%") or "No explicit affixes.\nThe base implicit stays on the ring.");
        tControls.Remove.setEnabled(oSelected ~= nil);
        tControls.Clear.setEnabled(#tItems > 0);

        local oCandidate = RingEditor.createAffix(tControls.Available.getValue(), tControls.Tier.getValue());
        local bAllowed, sReason = oSystem.canApplyAffix(oCandidate);
        tControls.Candidate.setValue(describe(oCandidate.getValues(), tControls.Roll.getValue()).."\n"..(bAllowed and "Ready to apply." or sReason));
        tControls.Add.setEnabled(bAllowed);
        oGem:delete();
        oGem = _wx.wxBrush(_wx.wxColour(_tBases[oRing.getBaseIndex()].gem));
        oPreview:Refresh(false);
    end

    --[[!
        @fqxn Examples.RingEditor.createDemo.layout
        @desc Keeps three editor columns and the status area within client bounds.
        @param wxEvent|nil jEvent Optional native resize event.
    !]]
    local function fLayout(jEvent)
        if (not bDisposed) then
            local nWidth, nHeight = oFrame:GetClientSizeWH();
            oParent:SetSize(0, 0, nWidth, nHeight);
            local tRect = oWindow.getGeometry().Content;
            local nX, nY = tRect.x, tRect.y;
            local nLeft = 294;
            local nMiddle = math.floor((tRect.width - nLeft - 40) * 0.51);
            local nRight = tRect.width - nLeft - nMiddle - 40;
            local nMidX, nRightX = nX + nLeft + 20, nX + nLeft + nMiddle + 40;
            tControls.BaseHeading.layout(nX, nY, nLeft, 24);
            tControls.Base.layout(nX, nY + 27, nLeft, 36);
            tControls.RarityHeading.layout(nX, nY + 72, 170, 24);
            tControls.Rarity.layout(nX, nY + 99, 172, 36);
            tControls.New.layout(nX + 182, nY + 99, nLeft - 182, 36);
            oPreview:SetSize(nX, nY + 140, nLeft, 140);
            tControls.RingName.layout(nX, nY + 285, nLeft, 50);
            tControls.Implicit.layout(nX, nY + 338, nLeft, 60);
            tControls.StatsHeading.layout(nX, nY + 400, nLeft, 24);
            tControls.Stats.layout(nX, nY + 427, nLeft, 222);
            tControls.AvailableHeading.layout(nMidX, nY, nMiddle, 24);
            tControls.Available.layout(nMidX, nY + 32, nMiddle, 344);
            tControls.TierHeading.layout(nMidX, nY + 385, 95, 24);
            tControls.Tier.layout(nMidX, nY + 412, 95, 36);
            tControls.RollHeading.layout(nMidX + 110, nY + 385, nMiddle - 110, 24);
            tControls.Roll.layout(nMidX + 110, nY + 412, nMiddle - 110, 36);
            tControls.Candidate.layout(nMidX, nY + 458, nMiddle, 90);
            tControls.Add.layout(nMidX, nY + 561, nMiddle, 38);
            tControls.AppliedHeading.layout(nRightX, nY, nRight, 24);
            tControls.Limits.layout(nRightX, nY + 32, nRight, 65);
            tControls.Applied.layout(nRightX, nY + 111, nRight, 265);
            tControls.AppliedDetail.layout(nRightX, nY + 390, nRight, 110);
            tControls.Remove.layout(nRightX, nY + 513, nRight, 38);
            tControls.Clear.layout(nRightX, nY + 561, nRight, 38);
            tControls.Status.layout(nMidX, nY + 608, nMiddle + nRight + 20, 40);
            tControls.Hint.layout(nX, nY + tRect.height - 34, tRect.width, 34);
        end
        if (jEvent) then
            jEvent:Skip();
        end
    end

    --[[!
        @fqxn Examples.RingEditor.createDemo.dispose
        @desc Releases controls before shared skin and deletes application drawing
        resources once. Native child windows remain owned by their frame.
    !]]
    local function fDispose()
        if (bDisposed) then
            return;
        end
        bDisposed = true;
        for nIndex = #tOwned, 1, -1 do
            tOwned[nIndex].destroy();
        end
        oWindow.destroy();
        oSkin.destroy();
        oGem:delete();
        oHighlight:delete();
        oEdge:delete();
        oBand:delete();
        oBackground:delete();
    end

    oFrame:Connect(_wx.wxEVT_SIZE, fLayout);
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(jEvent)
        fDispose();
        jEvent:Skip();
    end);
    for _, nDefinition in ipairs({1, 7}) do
        local _, bApplied, _, sReason = oRing.getAffixSystem().applyAffix(RingEditor.createAffix(nDefinition, 3), 75);
        assert(bApplied, sReason);
    end
    fLayout();
    fRefresh();
    fStatus("Select a modifier, tier and roll quality. Add it, then remove it to inspect the exact reversal.");
    oFrame:Centre();

    return {
        Frame = oFrame, Controls = tControls, refresh = fRefresh, dispose = fDispose,
        --[[!
            @fqxn Examples.RingEditor.createDemo.getRing
            @desc Returns the current real CoG ring for host inspection/tests.
            @ret Ring oRing Current ring.
        !]]
        getRing = function() return oRing; end,
    };
end

return RingEditor;
