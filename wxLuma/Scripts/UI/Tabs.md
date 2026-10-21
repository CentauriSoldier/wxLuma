# Tabs

`Controls.tabs(parent, options)` creates the skinned page container used by the
workbench. Each instance is an independent actual/decoy/metatable object. It uses
standard dot-call methods, enabled/lifecycle events and containment policy.

```lua
local oTabs = Controls.tabs(oParent, {
    Skin = oSkin,
    LayoutMode = "wrap",
    Position = "top",
    Items = {
        {Id = "general", Text = "General"},
        {Id = "units", Text = "Units", Image = pUnitsIcon},
        {Id = "advanced", Text = "Advanced", Enabled = false},
    },
    OnChange = function(nIndex, oComponent)
        -- Page visibility and layout have already been updated.
    end,
});
oTabs.layout(16, 16, 700, 500);
local oGeneralParent = oTabs.getPage("general");
-- Create controls under oGeneralParent; nested Tabs instances work normally.
```

String captions remain supported. Each receives a generated stable ID, available
through `getItems()`. Descriptors accept unique nonempty `Id`, optional `Text`
(default Id), optional image file `Image`, and optional `Enabled` (default true).
IDs cannot be changed by a descriptor patch.

## Layout

Header widths are measured using this object's `Skin.Font`, with space reserved
for text padding and optional image. `MinTabWidth` defaults to 80 pixels and
`MaxTabWidth` to 240. Very long captions clip at that maximum; headers do not
shrink into equal widths merely because more tabs have been added.

`LayoutMode` is `wrap` (default) or `scroll`. Wrapping creates additional rows for
top/bottom headers or columns for left/right headers. If wrapping would consume
the page's usable space, the effective layout falls back to scrolling. Scroll
navigation buttons and the mouse wheel move the header viewport. Selection stays
unchanged while scrolling. Selecting a tab or resizing reveals its header.

`Position` is `top` (default), `bottom`, `left`, or `right`. Labels stay horizontal
on every edge. Pages always occupy the computed content rectangle. Applications
should lay out page children from that native page's client size or size event;
they should not assume a constant header height.

Runtime configuration:

- `getPosition()` / `setPosition(edge, bNotify)`.
- `getLayoutMode()` / `setLayoutMode(mode, bNotify)`.
- `scrollBy(signedPixels)` moves the scrolling viewport without selecting a page.
- `getLayout()` returns an independent snapshot: visible `Entries`, `Page`,
  `Viewport`, optional `Back`/`Forward` rectangles, effective `Mode`, `Offset`,
  `Maximum`, and `Vertical`. Each entry has `Index`, `Id`, visible X/Y/Width/Height,
  and full DrawX/DrawY/DrawWidth/DrawHeight. Hit testing uses the visible bounds.

## Selection and keyboard

`getValue()` returns the selected numeric index. `setValue(indexOrId, bNotify)`
selects an enabled tab and reveals its header. Setters are silent unless requested.
Repeated selection of an already fully visible tab does not repaint or notify.

An empty or all-disabled set has value 0 and no visible page. Zero can be set only
when no enabled tabs exist. An initial `Value` must identify an enabled numeric
index, or zero for an empty/all-disabled set. Disabled headers remain visible but
cannot be selected through pointer input, keyboard input or setValue.

Left/Right/Up/Down choose the previous/next enabled tab with wrapping. Home/End
choose the first/last enabled tab. Ctrl/Cmd+Tab and Ctrl/Cmd+Shift+Tab change pages
from the header or a child control; Ctrl/Cmd+Page Up/Page Down also switch pages.
Ordinary Tab retains native focus traversal.

Disabling the whole object disables its native pages and their controls. It does
not discard selected state. Re-enabling restores the existing page hierarchy.

## Runtime pages

- `getItems()` returns independent descriptor copies with stable IDs.
- `getPage(indexOrId)` returns the native content parent.
- `setItems(items, bNotify)` replaces the descriptor array atomically. Matching
  IDs retain their native pages and children. New IDs create pages; removed IDs
  destroy their native pages and children. Use descriptor IDs when preserving
  content; replacing with strings creates new generated IDs.
- `addItem(captionOrDescriptor, indexOrNil, bNotify)` inserts or appends a page.
- `removeItem(indexOrId, bNotify)` removes one page.
- `setItem(indexOrId, patch, bNotify)` updates text/image/enabled policy without
  changing page identity. Replace the descriptor array to clear optional fields.
- `moveItem(indexOrId, destinationIndex, bNotify)` reorders existing pages.

Selection follows its stable ID through insertion/reordering. If the selected
page is removed or disabled, an enabled neighbor is chosen starting at the old
index, wrapping through the remaining set. If none is enabled, selection becomes
0. A selected page's numeric index changing also counts as a selection change.

For compatibility, `.Items` mirrors captions and `.Pages` mirrors native page
parents in display order. Existing numeric-index code continues to work. Use the
methods for mutation rather than directly editing these compatibility arrays.

Page children follow native parent ownership. Removing a page runs their native
destruction callbacks; application component objects should use that lifecycle.
Destroying the Tabs object releases its own drawing resources once; the ordinary
native container and surviving pages remain parent-owned, matching other surfaces.

## Events and skins

In addition to standard pointer, mouse-button/right-click, key, focus, size,
enabled and lifecycle events:

- `valueChanged` and `selectionChanged`: Value, OldValue, Id, OldId. Id is nil for
  no selection. `OnChange(index, publicObject)` follows the same effective changes.
- `itemsChanged`: independent Items descriptors after a notifying mutation.
- `itemHovered` / `itemLeft`: Index and stable Id.
- `positionChanged`: Position.
- `layoutModeChanged`: configured LayoutMode.

All decoration comes from the object's own Skin. `Artwork` defaults to `Tabs`;
provide equivalent materials under another prefix to customize a single instance.
Files are `Control Tabs <part>.png`:

| Part | States |
| --- | --- |
| Surface | Normal, Disabled |
| Page | Normal, Disabled |
| Tab | Normal, Hover, Pressed, Disabled |
| Tab Selected | Normal, Hover, Pressed, Disabled |
| Navigation | Normal, Hover, Pressed, Disabled |
| Text | Normal, Disabled |
| Focus | Single material |

Text, page backgrounds and focus colors come from skin materials; there are no
fixed native page-background colors. Images retain their own alpha. Header/page
materials are drawn in the supplied bounds, and borrowed skin bitmaps remain
owned by Skin.

The workbench now uses measured wrapping for its eleven readable categories.
The **Tabs** category contains a nested example with wrap/scroll, edge changes,
adding, removing, renaming and moving pages. Earlier category indices are retained.
