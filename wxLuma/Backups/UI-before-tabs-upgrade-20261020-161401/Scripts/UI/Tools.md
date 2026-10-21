# Toolbar, StatusBar and ColorPicker

Factories are `Controls.toolbar`, `Controls.statusBar`, and `Controls.colorPicker`.
All return independent actual/decoy/metatable objects with the standard dot-call
surface, enabled, lifecycle, containment and `on`/`off` APIs. Every object accepts
its own `Skin` and optional `Artwork` prefix. Native window ownership remains with
the parent; owned popup resources are released by `destroy()`.

The **Tools** workbench category demonstrates all three objects, including command
mutation, independent toggle state, overflow, status-hosted progress, and alpha.

## Toolbar

```lua
local oTools = Controls.toolbar(oParent, {
    Skin = oSkin,
    Items = {
        {Id = "attack", Text = "Attack", Image = pSword, Tooltip = "Attack target"},
        {Id = "separator", Kind = "separator"},
        {Id = "auto", Text = "Auto-cast", Kind = "toggle", Selected = true},
    },
    OnActivate = function(sId, oComponent)
        -- Dispatch the command.
    end,
});
oTools.layout(16, 16, 600, 48);
```

Descriptors use unique nonempty string IDs (the `__` prefix is reserved):

- `Kind`: `button` (default), `toggle`, or `separator`.
- `Text`: defaults to Id. `Image`: optional file path, contained in its icon box.
- `Width`: positive integer pixels, at least 8; default 112, separator default 12.
- `Enabled`: true by default. Disabled items still display their descriptions.
- `Selected`: boolean, false by default; applies to toggles.
- `Tooltip`: optional text, shown after a 500ms hover delay in a skinned,
  nonactivating popup subject to this toolbar's containment policy.

Commands keep their widths. A final More button exposes the remaining commands in
order, with Back/More navigation if the overflow menu needs additional pages.
Separators do not appear in overflow. Toggle state and disabled policy are shared
between the strip and overflow. The existing ContextMenu engine handles navigation,
outside dismissal and containment; toolbar-specific rendering supplies all its
visible colors, text, row artwork and icons.

APIs:

- `getItems()` returns independent descriptor copies.
- `setItems(items, bNotify)` atomically replaces the strip.
- `setItem(id, patch, bNotify)` updates one descriptor; Id stays stable.
- `addItem(item, indexOrNil, bNotify)` inserts, or appends when index is nil.
- `removeItem(id, bNotify)` removes an existing command.
- `getSelected()` always returns an independent display-order array of selected
  toggle IDs. `setSelected(ids, bNotify)` atomically replaces that set.
- `activateItem(id)` returns whether an enabled nonseparator command activated.
  It toggles persistent state when appropriate and invokes OnActivate.
- `getValue()` returns the last activated command ID (nil initially).
- `getLayout()` returns independent `Entries` rectangles and `Overflow` IDs.
- `openOverflow()` returns whether the overflow menu opened.
- `OverflowMenu` exposes the shared menu instance for subscriptions/inspection.

Left/Right/Home/End navigate visible enabled commands, including More; Enter/Space
activates the focused command. Mouse activation follows capture/cancel rules.
Additional events: `itemsChanged`, `selectionChanged`, `toolActivated`,
`itemHovered`, `itemLeft`, `itemFocused`, plus standard pointer/right-click/key/
focus/lifecycle events. `toolActivated` includes Id and Selected; selectionChanged
includes a fresh Selected array. Mutating setters notify only when requested.

Optional fields can be cleared by replacing descriptors with `setItems`.
The toolbar is horizontal; applications choose its bounds explicitly.

## StatusBar

```lua
local oStatus = Controls.statusBar(oParent, {
    Skin = oSkin,
    Items = {
        {Id = "message", Text = "Ready", Weight = 2},
        {Id = "position", Text = "0, 0", Weight = 1},
        {Id = "meter", Width = 180},
    },
});
local oMeterParent = oStatus.getSection("meter");
-- Create application controls under oMeterParent and respond to its size event.
```

Each descriptor has a unique nonempty `Id`, optional `Text`, optional `Image`, and
optional fixed `Width`. Without Width it receives a share of remaining pixels by
positive `Weight` (default 1). Fixed sections are allocated first. Excess fixed
widths clip in order; flexible sections may receive zero width, with no negative
native geometry. Fractional allocation accounts for every available pixel.

`getItems`, `setItems`, `setItem`, `addItem`, and `removeItem` match Toolbar's
signatures. `getLayout()` returns independent Id/X/Y/Width/Height rectangles.
`activateItem(id)` emits `sectionActivated` and optional `OnActivate(id, component)`.
Left/Right navigate sections; Enter/Space activates the focused section. Standard
pointer/button/right-click/key/focus/lifecycle events are available as usual.

`getSection(id)` lazily returns a stable native host. Parent arbitrary application
controls there. Hosted content replaces the section's built-in text/image drawing.
Hosts follow section size, disable with the StatusBar, and hide when too narrow.
A descriptor update retains hosts with matching IDs. Removing an ID destroys its
host and hosted native children; application controls should use their ordinary
parent-destruction lifecycle. The StatusBar does not create or own application
component objects. Its own resources follow standard surface disposal.

Section text/images are individually clipped. Extra events: `itemsChanged` and
`sectionActivated`. Descriptor mutation is atomic; optional fields can be cleared
by replacing the descriptor array.

## ColorPicker

```lua
local oColor = Controls.colorPicker(oParent, {
    Skin = oSkin,
    Value = {R = 65, G = 140, B = 210, A = 190},
    OnChange = function(tRGBA, oComponent)
        -- tRGBA is an independent committed-color copy.
    end,
});
oColor.layout(16, 16, 280, 48);
```

RGBA channels are integers in 0-255; omitted alpha means 255. Value defaults to
opaque white. The swatch shows alpha over skin-defined checker colors.

- `getValue()` / `setValue(rgba, bNotify)` copy and validate committed color.
  Identical RGBA values do not repaint or notify. Bindings work while disabled.
- `getHSV()` / `setHSV(hsv, bNotify)` use H degrees, S/V percentages 0-100, and
  optional A byte. Hue wraps modulo 360; setHSV preserves existing alpha when
  omitted. Conversions round to RGB bytes. The open editor retains hue while
  editing black/gray, where RGB alone cannot preserve it.
- `getSwatches()` / `setSwatches(array, bNotify)` copy up to ten RGBA swatches.
  Defaults are eight common colors, including transparent black. These are
  selectable data values, not decorative skin colors.
- `open()` returns whether the popup opened. It refuses disabled, hidden or
  already-open controls. `isOpen()` reports editor state.
- `getPreview()` returns an independent preview while open, otherwise committed
  color. Dragging and keyboard editing do not modify the committed color.
- `close(commitOrNil, restoreFocusOrNil)` applies only when commit is true;
  all cancellation paths preserve committed color. Focus restores unless false.
- `Popup` exposes the native floating window; `Editor` is its drawing/input surface.

Pointer sliders link R/G/B, H/S/V and A immediately. Up/Down/Tab select channels;
Shift+Tab reverses. Left/Right change one unit, Page Up/Down ten, Home/End select
limits. Clicking a swatch changes preview. Apply/Enter commits. Cancel/Escape,
outside native deactivation, owner hiding or native popup hiding cancels.
A new opening starts from committed color. Authoritative setValue updates also
replace an open preview.

The popup is 360×360 client pixels. Containment shifts only overflowing position
axes, preserving its size and contents. Oversized behavior inherits the existing
`hide` default or explicit `allow` policy. Ordinary owner layout is unaffected.

Events: `opened`, `closed` (Committed flag), `previewChanged` (Value), `committed`
(Value), `cancelled` (Value), `swatchesChanged` (Swatches), standard `valueChanged`
(Value/OldValue), and generic pointer/button/right-click/key/focus/lifecycle events.
`OnChange(color, component)` runs for committed changes when notification is enabled.

## Skin materials

All new decoration comes from `Images/UI/Controls/Control <prefix> <part>.png`.
The default prefixes and required parts are:

| Prefix | Parts |
| --- | --- |
| Toolbar | Surface Normal/Disabled; Item Normal/Hover/Pressed/Disabled; Toggle On Normal/Hover/Pressed/Disabled; Text Normal/Disabled; Separator; Focus; Hint |
| Status Bar | Surface Normal/Disabled; Section Normal/Disabled; Text Normal/Disabled; Separator; Focus |
| Color Picker | Surface Normal/Hover/Pressed/Disabled; Text Normal/Disabled; Popup; Track; Fill; Thumb; Focus; Swatch; Check Light/Dark; Action Normal/Hover/Pressed |

Text, checker, focus and separator colors are sampled from their material's first
pixel. Text uses `Skin.Font`; images use alpha-aware containment. The toolbar's
hint and overflow also use its own materials. Status hosts derive their native
background from Section artwork. The ColorPicker editor is entirely drawn, with
no fixed native text-editor colors. Only represented color values are generated
from RGBA/HSV; their checker decoration is still selected by the skin.

Change `Skin` at object creation, and use `Artwork` to select a matching alternate
material prefix. Do not mutate or delete borrowed Skin bitmaps. New components own
only their decoded/scaled application images, palette colors and popup resources.
