# Ring editor example

From the wxLuma root:

```powershell
.\RunRingEditor.ps1
```

The launcher uses wxLuma's bundled Windows x64 wxLua runtime and the existing
LuaEx checkout at `../../Documents/GitHub/LuaEx`. For another installation:

```powershell
.\RunRingEditor.ps1 -LuaExRoot 'C:\path\to\LuaEx-repository'
```

Choose a catalogue entry, tier and roll quality, then add it. Select an applied
entry to inspect its actual roll and remove it. Stats, composed name, capacity
and eligibility update from the real CoG objects. Duplicate modifier families,
tiers above the rarity limit and full prefix/suffix groups disable the add
button and display the reason. Rejected rarity downgrades restore the selection.

The initial ring has two example affixes. **Remove all affixes** retains its
implicit; **New ring** creates a clean instance using the selected base and rarity.
Changing the base selector alone prepares the next ring; it does not mutate the
current ring's implicit.

`Ring` extends `CoGObject` directly. Its inherited `AffixSystem` owns all affix
applications. Host callbacks apply/remove journaled stat deltas using the ring's
owned Proteans. `ring.getStat(key)` returns the Protean; an optional Protean value
category returns a number. No widget is stored in or captured by the ring model.

Definitions register once through `AffixSystem.registerDefinitions`. The factory
takes only the opaque, case-insensitive ID and an explicit tier enum member:
`AffixSystem.createAffix("RING.DEXTERITY", luaex.cog.config.TIER.II)`.
The registry supplies that tier's generic data through `affix.getValues()`;
the host callback interprets it and rolls the requested quality at application.
Unknown IDs, non-enum tiers and tiers absent from a definition raise errors.

Four bases and twelve modifier families provide Path of Exile-inspired testing
data. These are illustrative values, not a reproduction of the game's crafting
rules. CoG's bundled rarity/tier configuration is used unchanged, so Rare has
two prefix and two suffix slots and higher tier ordinals are stronger here.

Run the model and native UI tests:

```powershell
.\RunRingEditor.ps1 -Check
.\RunRingEditor.ps1 -Smoke
```

The tests cover reversible effects, overlapping modifiers, duplicates, tier and
capacity limits, rejected rarity changes, 1,200 deterministic mutations,
formatted serialization/restoration, native add/remove/clear/new actions and
minimum-size layout. `-Smoke -CapturePath C:\path\preview.png` also saves a
client-area preview. These commands do not change LuaEx or wxLuma framework files.
