local _wx     = require("wx");
local _Editor = require("RingEditor");
local RingEditorTest = {};
local _nChecks = 0;
local _tKeys = {"life", "mana", "shield", "physicalMin", "physicalMax", "rarity", "fire", "cold", "lightning", "strength", "dexterity", "accuracy"};

--[[!
    @fqxn Examples.RingEditorTest.check
    @desc Counts assertions and provides a meaningful failing contract.
    @param boolean bPassed Whether the condition holds.
    @param string sMessage Expected behavior.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
    @fqxn Examples.RingEditorTest.verifyStats
    @desc Independently sums journal deltas over each base stat after mutations.
    @param Ring oRing Ring under test.
    @param table tBase Baseline final values before adding explicit affixes.
!]]
local function verifyStats(oRing, tBase)
    local tExpected = {};
    for _, sKey in ipairs(_tKeys) do
        tExpected[sKey] = tBase[sKey];
    end
    for _, oAffix in oRing.getAffixSystem().eachAffix() do
        check(rawequal(oAffix.getOwner(), oRing), "Affix owner is the actual ring.");
        for _, tChange in ipairs(oAffix.getJournal().changes) do
            tExpected[tChange.stat] = tExpected[tChange.stat] + tChange.amount;
        end
    end
    for _, sKey in ipairs(_tKeys) do
        check(oRing.getStat(sKey, Protean.VALUE_FINAL) == tExpected[sKey], "Exact accumulated value for "..sKey..".");
    end
end

--[[!
    @fqxn Examples.RingEditorTest.click
    @desc Exercises a skinned button through its native mouse handler chain.
    @param table oButton wxLuma button.
!]]
local function click(oButton)
    for _, nType in ipairs({_wx.wxEVT_LEFT_DOWN, _wx.wxEVT_LEFT_UP}) do
        local jEvent = _wx.wxMouseEvent(nType);
        jEvent.GetX = function() return 10; end;
        jEvent.GetY = function() return 10; end;
        jEvent:SetId(oButton.Control:GetId());
        jEvent:SetEventObject(oButton.Control);
        oButton.Control:GetEventHandler():ProcessEvent(jEvent);
        jEvent:delete();
    end
end

--[[!
    @fqxn Examples.RingEditorTest.runChecks
    @desc Tests direct CoGObject inheritance, implicit independence, exact effects,
    duplicate/tier/capacity rejection, rarity rejection, stress and persistence.
!]]
function RingEditorTest.runChecks()
    local oRing = Ring(3, Rarity.LEVEL.SINGULAR);
    check(class.getparent(Ring) == CoGObject, "Ring directly extends CoGObject.");
    local tBase = {};
    for _, sKey in ipairs(_tKeys) do
        tBase[sKey] = oRing.getStat(sKey, Protean.VALUE_FINAL);
    end
    check(tBase.fire == 8 and tBase.cold == 8 and tBase.lightning == 8, "Prismatic implicit is separate base data.");
    check(type.isProtean(oRing.getStat("life")), "Default stat getter returns the actual Protean.");

    local oFirst = _Editor.createAffix(1, 3);
    local _, bApplied = oRing.getAffixSystem().applyAffix(oFirst, 75);
    check(bApplied and oRing.getStat("life", Protean.VALUE_FINAL) == 34, "Tier III life roll applies exactly once.");
    local _, bDuplicate = oRing.getAffixSystem().applyAffix(_Editor.createAffix(1, 2), 0);
    check(not bDuplicate and oRing.getAffixSystem().getAffixCount() == 1, "Another tier of the same family rejects as a duplicate.");
    local _, bRarity = oRing.setRarity(Rarity.LEVEL.COMMON);
    check(not bRarity and oRing.getRarity() == Rarity.LEVEL.SINGULAR, "Invalid rarity downgrade leaves the ring unchanged.");
    local _, bRemoved = oRing.getAffixSystem().removeAffix(oFirst);
    check(bRemoved and oFirst.getOwner() == nil, "Removal releases affix ownership.");
    verifyStats(oRing, tBase);

    local oRare = Ring(1, Rarity.LEVEL.RARE);
    local _, bTooStrong = oRare.getAffixSystem().applyAffix(_Editor.createAffix(1, 6), 100);
    check(not bTooStrong and oRare.getStat("life", Protean.VALUE_FINAL) == 25, "Tier rejection preserves implicit values.");
    for nDefinition = 1, 3 do
        local _, bAdded = oRare.getAffixSystem().applyAffix(_Editor.createAffix(nDefinition, 1), 50);
        check(bAdded == (nDefinition <= 2), "Rare prefix cap comes from CoG configuration.");
    end

    -- Use a local deterministic generator so the example never reseeds host RNG.
    local nState = 137;
    for nOperation = 1, 1200 do
        nState = (nState * 48271) % 2147483647;
        local nDefinition = nState % 12 + 1;
        local nTier = nState % 6 + 1;
        local nQuality = nState % 101;
        if (nOperation % 3 == 0) then
            local oExisting;
            for _, oAffix in oRing.getAffixSystem().eachAffix() do
                oExisting = oAffix;
                break;
            end
            if (oExisting) then
                local _, bDeleted = oRing.getAffixSystem().removeAffix(oExisting);
                check(bDeleted, "Stress removal succeeds.");
            end
        else
            oRing.getAffixSystem().applyAffix(_Editor.createAffix(nDefinition, nTier), nQuality);
        end
        verifyStats(oRing, tBase);
    end

    check(oRing.getAffixSystem().getAffixCount() > 0, "Snapshot includes live applications and their callbacks.");
    local sSaved = assert(prettyLua(serialize(oRing)));
    local oRestored = deserialize(sSaved);
    check(class.of(oRestored) == Ring and not rawequal(oRestored, oRing), "Formatted save restores a distinct Ring instance.");
    check(rawequal(oRestored.getAffixSystem().getOwner(), oRestored), "Restored component is immediately bound to its ring.");
    verifyStats(oRestored, tBase);
    for _, oAffix in oRestored.getAffixSystem().eachAffix() do
        local _, bDeleted, _, sReason = oRestored.getAffixSystem().removeAffix(oAffix);
        check(bDeleted, "Restored callback removes its own saved effect: "..tostring(sReason));
    end
    verifyStats(oRestored, tBase);
    verifyStats(oRing, tBase);
    print("Ring model: ".._nChecks.." checks passed, including 1200 mutations and formatted serialization.");
end

--[[!
    @fqxn Examples.RingEditorTest.runInputChecks
    @desc Tests actual skinned button activation, model-driven updates, preflight
    disablement, rarity rejection, clean bases and resizing on a shown editor.
    @param table oDemo Live editor returned by createDemo.
!]]
function RingEditorTest.runInputChecks(oDemo)
    local tControls = oDemo.Controls;
    check(oDemo.Frame:IsShown() and tControls.Available.Control:IsShownOnScreen(), "The editor and its catalogue are visible.");
    click(tControls.Clear);
    check(oDemo.getRing().getAffixSystem().getAffixCount() == 0, "Native clear action removes seeded affixes.");
    check(oDemo.getRing().getStat("life", Protean.VALUE_FINAL) == 25, "Native clear retains the Coral implicit.");
    tControls.Available.setValue(1, true);
    tControls.Tier.setValue(3, true);
    tControls.Roll.setValue(100, true);
    click(tControls.Add);
    check(oDemo.getRing().getStat("life", Protean.VALUE_FINAL) == 62, "Native add applies selected tier and roll.");
    check(not tControls.Add.isEnabled(), "Duplicate preflight disables add.");
    tControls.Rarity.setValue(Rarity.LEVEL.COMMON.id, true);
    check(oDemo.getRing().getRarity() == Rarity.LEVEL.RARE and tControls.Rarity.getValue() == Rarity.LEVEL.RARE.id, "Rejected rarity rolls UI selection back.");
    click(tControls.Remove);
    check(oDemo.getRing().getStat("life", Protean.VALUE_FINAL) == 25, "Native remove reverses the recorded effect.");
    tControls.Available.setValue(7, true);
    click(tControls.Add);
    tControls.Available.setValue(10, true);
    click(tControls.Add);
    check(oDemo.getRing().getStat("fire", Protean.VALUE_FINAL) == 34, "Overlapping elemental effects stack.");
    tControls.Applied.setValue(1, true);
    click(tControls.Remove);
    check(oDemo.getRing().getStat("fire", Protean.VALUE_FINAL) == 10, "Removing one overlapping effect retains the other.");
    tControls.Base.setValue(2);
    click(tControls.New);
    check(oDemo.getRing().getName() == "Iron Ring" and oDemo.getRing().getStat("physicalMax", Protean.VALUE_FINAL) == 4, "New base creates a clean, independent ring.");
    oDemo.Frame:SetClientSize(1180, 850);
    _wx.wxGetApp():Yield();
    for sKey, oControl in pairs(tControls) do
        local nX, nY = oControl.Control:GetPositionXY();
        local nWidth, nHeight = oControl.Control:GetSizeWH();
        local nParentWidth, nParentHeight = oControl.Control:GetParent():GetClientSizeWH();
        check(nX >= 0 and nY >= 0 and nX + nWidth <= nParentWidth and nY + nHeight <= nParentHeight, "Minimum-size control stays inside the window: "..sKey);
    end
    oDemo.Frame:SetClientSize(1340, 930);
    _wx.wxGetApp():Yield();
    print("Ring editor: native add/remove/clear/new, rarity rollback, overlapping effects and resize checks passed.");
end

return RingEditorTest;
