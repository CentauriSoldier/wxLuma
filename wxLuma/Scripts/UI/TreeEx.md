# TreeEx

`Controls.treeEx(parent, options)` combines ListEx's typed columns with a custom
painted hierarchy. It uses an actual/decoy/metatable public object and virtual
visible rows rather than creating native controls for every cell or checkbox.
Existing `Controls.tree` remains available for native tree behavior.

```lua
local oTree = Controls.treeEx(oParent, {
    Skin = oSkin,
    Columns = {
        {Key = "Name", Type = "text", Weight = 2, Title = "Name"},
        {Key = "Class", Type = "text", Width = 100, Title = "Class"},
    },
    HierarchyColumn = 1,
    Checkboxes = true,
    Items = {{Id = "gondor", Name = "Gondor", Class = "Faction", Expanded = true,
        Children = {{Id = "faramir", Name = "Faramir", Class = "Ranger", Image = pPortrait}},
    }},
});
oTree.layout(16, 16, 700, 400);
```

Columns have the same fixed creation-time Key, Type, Width/Weight, Align and Format
rules as ListEx, with optional header `Title` (defaults to Key). Supported types
are text, image, number and boolean; nil cells are blank. Types remain fixed while
data changes. The hierarchy inset affects only `HierarchyColumn` (default first),
so later column starts stay aligned at all depths. Column overflow clips to the
viewport; horizontal scrolling is not provided.

If Columns is omitted, one text column displays `Text`. Every node needs a unique
nonempty string `Id`. `Text` defaults to Id. Optional `Image` is the node icon directly before its
hierarchy label, following its indentation: expander, checkbox (when enabled),
image, text. Ordinary image columns remain available for independent data.
Other typed fields are application row data. Optional `Value` is application data, `Expanded` controls branches, and
`Children` contains nested descriptors. Cycles/shared child arrays, duplicate IDs,
sparse arrays, and invalid cell types are rejected before replacing live data.
Default RowHeight is 32 pixels, Indent 18, HierarchyColumn 1. Column headers are 28
pixels high. Leaves stay collapsed.

## Selection and hierarchy

- `getValue()` / `setValue(idOrNil, bNotify)` use a stable primary node ID. Setting
  a hidden node reveals its ancestors; nil clears selection.
- `getSelected()` always returns an independent display-order array of IDs.
  `setSelected(ids, bNotify)` validates atomically and reveals requested nodes.
- `isMultiSelectEnabled()` / `setMultiSelectEnabled(boolean, bNotify)` match the
  existing selection API. MultiSelect defaults false. Disabling retains primary.
- `setExpanded(id, boolean, bNotify)` expands/collapses a branch. Collapsing removes
  now-hidden selections; if none remain, the collapsed node becomes selected.
  Checks on hidden descendants are retained.
- `getVisible()` returns expanded visible IDs in display order.
- `getNode(id)` / `getItem(id)` returns a snapshot with data, Parent, Depth,
  Expanded and an independent array of child IDs; absent IDs return nil.
- `getChildren(parentOrNil)` returns ordered child IDs; nil selects roots.
- `getItems()` returns independent nested descriptors with current expansion.
  Application Value and other nested data fields are shallow references, as with
  ListEx's row/cell API.

Up/Down/Home/End/Page keys and Shift/Ctrl/Cmd selection use the shared list engine.
Left collapses a branch or selects its parent. Right expands a branch or enters
its first child. Enter activates the focused node through `itemActivated` and
optional `OnActivate(id, component)`. Checkbox and branch-button clicks preserve
row selection unless collapse necessarily hides selected descendants. Standard
pointer, button/right-click, key, focus and lifecycle events are provided.

Check presentation defaults off. Downward check propagation defaults on, with a
creation/runtime opt-out. See [Checks.md](Checks.md) for the shared checkbox API,
per-item events, modifier keys and propagation rules.

## Mutable data

- `setItems(nestedItems, bNotify)` replaces hierarchy atomically. Checks/selection
  use surviving stable IDs. Omitted Expanded preserves existing expansion by ID;
  explicitly supplied Expanded wins.
- `addNode(parentOrNil, descriptor, bNotify)` appends a node/subtree. The item-first
  alias is `addItem(descriptor, parentOrNil, bNotify)`.
- `removeNode(id, bNotify)` / `removeItem(id, bNotify)` removes the entire subtree.
- `setItem(id, patch, bNotify)` updates data without altering Id/Children/Expanded.
- `setNodeImage(id, imagePathOrNil, bNotify)` changes or clears the inline node
  icon. `getNode(id).Image` and nested `getItems()` snapshots expose its path.
  Invalid images preserve the live tree. A successful notifying load emits
  imageLoaded (Id, Path), alongside itemChanged/itemsChanged.
- `getCell(id, columnIndex)` / `setCell(id, columnIndex, value, bNotify)` access
  typed cells. Structural Id/Children/Expanded fields cannot be edited as cells.
- `getColumns()` returns independent creation-time column definitions.

Setters are silent by default. Data mutations emit itemsChanged, itemAdded,
itemRemoved, itemChanged or cellChanged when requested. Expansion emits
itemExpanded/itemCollapsed. Selection emits valueChanged only when primary ID
changes, and selectionChanged for effective membership/primary changes. Selection
payloads include Value, OldValue, Selected and OldSelected (ID arrays). Optional
OnChange receives `(primaryId, publicComponent, selectedIds)`.

`Rows` exposes the shared typed row component for advanced native integration and
testing. Its indices address only expanded visible rows; use TreeEx's ID methods
for persistent application state. The public `Control` hosts headers and `Rows`.
Layout and input resources follow ordinary parent ownership; destroy releases
owned skin palette/renderer caches and the row component once.

## Skins

ListEx now uses dedicated artwork by default (`Artwork = "ListEx"`), and TreeEx
uses `Artwork = "TreeEx"`. Each accepts its own Skin; text palettes, surfaces,
rows, focus, checkboxes and scrollbars all use that object's skin resources.

Required materials are `Control <Artwork> <part>.png`:

- Surface Normal/Disabled.
- Row Normal, Hover, Selected, Disabled, Selected Disabled.
- Text Normal/Disabled; Focus.
- Scroll Track; Scroll Thumb Normal/Hover/Pressed/Disabled.
- Check On/Off Normal/Hover/Pressed/Disabled when checkboxes are used.
- TreeEx additionally uses Header and Branch Open/Closed
  Normal/Hover/Pressed/Disabled.

The typed renderer's optional per-column inset leaves other column origins
unchanged. Only visible dirty rows render. Scaled thumbnails use the existing
bounded cache. Cascaded checkbox updates batch repaint requests, including trees
with 10,000 descendants. No timers or automatic redraw loops are added.
