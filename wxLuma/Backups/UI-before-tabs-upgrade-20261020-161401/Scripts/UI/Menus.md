# ContextMenu and RadialMenu

Create `Controls.contextMenu(parent, options)` or `Controls.radialMenu(parent, options)`. The parent is a native window or visual component defining lifetime and inherited containment. Each menu is an independent actual/decoy/metatable object. Menus share the skin, event and containment APIs without inheriting from another visual object.

## Items

Each record needs a unique string `Id`. IDs are unique throughout the hierarchy; the `__` prefix is reserved for automatic navigation controls. Optional fields are:

| Field | Meaning |
| --- | --- |
| Text | Caption; defaults to Id unless an image is supplied. |
| Image | Image file path; can accompany Text. |
| Value | Application data, returned with its original identity. |
| Items | Child descriptors; selecting opens that submenu. Empty submenus still have Back. |
| Enabled | Defaults to true; disabled items cannot activate. |
| Shape | Radial circle, diamond or square; overrides the menu default. |
| Width / Height | Host/container dimensions; defaults to menu ItemWidth/ItemHeight. Circle uses the smaller dimension as diameter. |
| ImageWidth / ImageHeight | Image display dimensions, defaulting to the radial host size or 24px context icon. |
| ClipImage | Defaults to true. False permits a radial image outside its host; that larger footprint participates in spacing/containment. Images outside hosts are decorative, not hit targets. |
| Artwork | Optional material prefix override for the item. |

`getItems()` returns independent descriptor structure. `setItems(items, notify)` validates the entire hierarchy atomically before replacing it; `setItem(id, patch, notify)` updates one descriptor. These dismiss open pages and clear artwork caches. Replace the descriptor tree to remove optional fields. Image load failures emit imageError and leave the host/caption available.

## Opening and selection

- `showAt(screenX, screenY)` opens programmatically. The point is the context popup's top-left or the radial ring's virtual center.
- `showAtObject(target)` opens at a native/visual target's center.
- `attach(target)` adds native right-click/context-key opening. Target must belong to the menu's lifetime parent. Reattaching is idempotent; `detach(target)` or `detach()` disables attachments. Attachments and programmatic opening can coexist.
- `setAnchor(x, y)` changes the requested screen anchor without resetting navigation. `getAnchor()` returns its effective position after minimal containment adjustment.
- `close(reason)` dismisses and resets navigation to the root, as do outside clicks, deactivation, target loss and disabling. `isOpen()` reports state.
- `activateItem(id)` activates an enabled visible item and returns true plus a selection snapshot for an action. Back/More/submenu entries navigate without completing a selection.

Menu opening is asynchronous; it does not block the wx event loop. Selecting an action closes the menu and resets navigation **before** delivering `OnSelect(selection, menu)` and `selected`. The snapshot contains Id, Text, application Value and a Path of real item IDs. Back/More never appear in Path. `getSelection()` returns an independent completed snapshot and `getValue()` its Id. A new opening clears the previous result; cancelling that opening leaves no selection. A completed action result remains readable after closing. Listener-driven reopening cannot replace the result delivered to the original callback.

## Radial layout

Defaults: Direction CW, StartAngle 0 (top), Shape circle, Spacing 12px, MinRadius 64px, MaxRadius 160px, ItemWidth/ItemHeight 64px. Angles are clock-face degrees: 90 right, 180 bottom, 270 left. Negative/fractional angles are allowed and normalize modulo 360.

Item centers disperse evenly around the virtual ring. Radius measures item centers; popup bounds account for complete item footprints. The solver chooses a fitting radius in the configured range, checks every pair of conservative rectangular footprints, and preserves minimum edge-to-edge spacing. Item dimensions are never reduced to make a page fit. Explicitly overflowing images enlarge footprints. Native coordinates round to pixels.

Runtime methods are `get/setDirection(CW|CCW, notify)`, `get/setStartAngle(degrees, notify)`, `get/setSpacing(pixels, notify)`, `getRadiusRange()` and `setRadiusRange(min, max, notify)`. `get/setShape(shape, notify)` controls inherited shapes; explicit item shapes remain unchanged. Shape changes reopen at the root. Other policies recompute the current page. Setters return the menu, are silent by default and notify only when changed.

Items that cannot fit move behind the final More button. Every nested submenu and overflow page begins with Back, restoring the immediately preceding page. Overflow pages can overflow again. All overflow pages are checked for forward progress before opening that branch. If even the required navigation plus a real choice cannot fit, opening/navigation returns false and a clear reason, without shrinking or losing items. A failed submenu opening leaves the current page available. Runtime settings that cannot fit dismiss with layoutFailed.

## Context layout and input

Context defaults: Width 240px, ItemWidth 232px, ItemHeight 40px, Spacing 2px. Rows retain configured dimensions; excess rows paginate through the same Back/More mechanism. Context submenus replace the current page and include Back, following the requested shared navigation model.

Mouse activation uses host-shape hit testing. Arrows and Tab traverse enabled choices; Enter/Space activates. In a context menu, Right opens the focused submenu/More and Left goes back. Escape goes back, then closes at root. Clicking outside dismisses and resets to the first menu. `getFocusedItem()` and independent `getLayout()` geometry snapshots support tooling and integration.

## Containment, rendering and skins

Default boundary is the topmost parent client area, intersected with visible ancestors and display work area. Popup position and its effective anchor move only the minimum needed on each overflowing axis; item sizes never change. Explicit Containment/ContainmentOverflow overrides use the shared APIs. The default hide policy paginates to fit the boundary. Explicit allow lifts containment size limits while retaining the configured radial maximum and item dimensions; placement follows shared leading-edge behavior for oversized popups.

Each menu accepts its own Skin and Artwork prefix (default Menu). Material files are `Control Menu <Circle|Diamond|Square|Row> <Normal|Hover|Pressed|Disabled>.png`. Item Artwork overrides select alternate material prefixes. Source images and rendered states have bounded caches; shape/image clips are supersampled into alpha-aware bitmaps. Radial popups use native shaped frames where supported, with a rectangular fallback. No optional graphics-context backend is needed. Dispose menus before their shared skin.

Menus expose standard on/off mouse, keyboard, focus, enabled, size and lifecycle subscriptions plus opened, closed, selected, pageChanged, itemsChanged, itemHovered, itemLeft, itemFocused, layoutFailed, imageError and runtime-policy events. Selection and item snapshots preserve application Value identity.

The Menus workbench category demonstrates both opening methods, mixed shapes, images plus text, clipping/overlap, disabled actions, multi-level submenus, nested overflow and runtime direction/angle/spacing/radius controls.
