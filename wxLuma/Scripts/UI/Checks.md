# Item checkboxes

ListEx and TreeEx provide optional per-item checkboxes. `Checkboxes` defaults to
`false` on both; every item starts unchecked unless initial `Checked` references
are supplied. Check state is separate from row selection, typed boolean cells,
application data, and activation.

```lua
local oList = Controls.listEx(oParent, {
    Skin = oSkin,
    Columns = {{Key = "Name", Type = "text"}},
    Items = {{Name = "Faramir"}, {Name = "Gandalf"}},
    Checkboxes = true,
    Checked = {1},
});
oList.on("checkChanged", function(oSource, tEvent)
    -- ListEx: Index, optional row Id, Item snapshot, Checked and OldChecked.
end);
```

The same public API applies to both objects:

| API | Behavior |
| --- | --- |
| `isCheckboxesEnabled()` | Reports checkbox presentation/input policy. |
| `setCheckboxesEnabled(boolean, bNotify)` | Shows/hides checkboxes without clearing checks or selection. |
| `getChecked()` | Returns an independent data-order array, even when empty or only one item is checked. |
| `isChecked(item)` | Returns an existing item's boolean check state. |
| `getCheckState(item)` | Returns `checked` or `unchecked`. |
| `setChecked(item, boolean, bNotify)` | Changes one item; TreeEx cascades by default as described below. |
| `setCheckedItems(array, bNotify)` | Replaces checked membership atomically after validating every reference. |

References are **row indices for ListEx** and **stable node IDs for TreeEx**.
Setters are silent unless `bNotify` is true. Programmatic check state can change
while checkboxes are hidden or the object is disabled. Identical states do not
notify or repaint. Duplicate IDs/indices in bulk membership behave like a set.

Clicking a checkbox toggles its check state without selecting or activating its
row. Plain Space toggles the focused checkbox; holding it does not repeatedly
toggle. Ctrl/Cmd+Space retains normal multi-selection behavior. Shift/Ctrl/Cmd
selection gestures on row content are unchanged. Disabled controls ignore checkbox
input. A cancelled press, or releasing outside the original checkbox, does not
change its state.

ListEx check state follows surviving rows when an item is removed. Replacing a
row or cell retains that position's check state. `setItems` preserves surviving
checks by index and drops references beyond the new row count, matching ListEx's
index-based API. Structural removal is reported by item events, not as a checkbox
toggle. `CheckboxArtwork` optionally chooses a separate ListEx checkbox prefix;
otherwise it is `<Artwork> Check`.

Events:

- `checkChanged`: Checked, OldChecked, State and OldState. ListEx also includes
  Index, an optional application row Id, and an independent Item snapshot.
  TreeEx includes stable Id and its current visible Index (nil when collapsed).
- `checkboxesChanged`: Enabled, after a notifying presentation-policy change.
- Optional `OnCheckChange(itemReference, checked, publicComponent)` receives the
  same effective changes when notification is enabled.

## Tree propagation

TreeEx defaults to **downward propagation enabled**, including all collapsed
and expanded descendants. Checking or unchecking a branch applies the same state
to that node and everything below it. Selection and expansion stay unchanged.
The entire new membership is installed before notifications, followed by one
`checkChanged` event for each effective node change in tree order. Repeating a
checked parent action still repairs any descendants whose states differ.

```lua
local oTree = Controls.treeEx(oParent, {
    Skin = oSkin,
    Checkboxes = true,
    CheckPropagation = false, -- Opt out at creation for independent node checks.
    Items = {{Id = "army", Text = "Army", Children = {
        {Id = "unit", Text = "Unit"},
    }}},
});
oTree.setCheckPropagationEnabled(true, true);
oTree.setChecked("army", true, true); -- Checks army and unit.
```

`isCheckPropagationEnabled()` reports the current policy.
`setCheckPropagationEnabled(boolean, bNotify)` changes future behavior and emits
`checkPropagationChanged` (Enabled) when requested. Changing policy does not
retroactively change existing checks.

With propagation on, `setCheckedItems({branchIds...})` includes their descendants;
all other nodes become unchecked. With propagation off, it replaces the exact
specified ID set. Initial `Checked` follows the same policy.

Collapsed nodes remain in `getChecked()` and can be queried/updated by ID.
Removing a subtree prunes every removed check identity. Data replacement preserves
checks for surviving IDs. Newly added nodes start unchecked; a subsequent parent
check/uncheck action includes them. Checks do not automatically propagate upward,
and there is no automatic tri-state aggregation.

Checkbox, selection, focus, row and scrollbar artwork are skinnable. The **TreeEx**
workbench category demonstrates both objects with checkboxes initially off and
an explicit cascade toggle initially on.
