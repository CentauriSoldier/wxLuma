# wxLuma

wxLuma extends wxLua with skinnable controls, containers, menus, editors, progress displays, and shared event and containment APIs.

The inner `wxLuma/` folder is the framework. `Win/` contains the Windows demo, tests, native launcher, and runtime DLLs. Documentation, Git files, and test scaffolding sit outside the framework.

## Contents

- [Getting started](#getting-started)
- [Image configuration](#image-configuration)
- [Repository layout](#repository-layout)
- [Available components](#available-components)
- [Windows demo and tests](#windows-demo-and-tests)
- [Skinning controls](#skinning-controls)
- [Progress controls](#progress-controls)
- [List and Table selection](#list-and-table-selection)
- [TreeEx](#treeex)
- [Item checkboxes](#item-checkboxes)
- [Tabs](#tabs)
- [ContextMenu and RadialMenu](#contextmenu-and-radialmenu)
- [Editors and dialogs](#editors-and-dialogs)
- [Toolbar, StatusBar and ColorPicker](#toolbar-statusbar-and-colorpicker)
- [Historical measurements and export notes](#historical-measurements-and-export-notes)

## Getting started

Make wxLua available as `require("wx")`, and put the directory containing the framework folder on Lua's module search path. Include both `?.lua` and `?/init.lua` patterns: the first locates individual modules; the second locates `wxLuma/init.lua`.

```lua
local wx = require("wx");
local loadwxLuma = require("wxLuma");
local wxLuma = loadwxLuma();
local Controls = wxLuma.Controls;
```

`require("wxLuma")` returns the loader function. Call it without an argument to use the included configuration, or pass a Lua configuration file path:

```lua
local loadwxLuma = require("wxLuma");
local wxLuma = loadwxLuma();                    -- Included config.
local wxLumaCustom = loadwxLuma("path/to/config.lua"); -- Custom config.
```

A relative configuration-file path is relative to the caller's current working directory. An omitted path selects the framework's own `config.lua`, independently of that working directory. Each loader call returns its own `wxLuma` table, configuration table, and default-artwork wrappers; loading a custom configuration does not replace an earlier instance's image defaults. Widget implementations remain shared Lua modules.

The loader loads configuration, control factories, and the window module. Its returned table contains:

| Field | Purpose |
| --- | --- |
| `wxLuma.Controls` | Control factories and shared helpers listed below. |
| `wxLuma.Window` | Decorated window surface module, including `create` and `geometry`. |
| `wxLuma.Path` | Framework directory resolved when loaded. |
| `wxLuma.Config` | Loaded configuration, including the resolved `ImagePath`. |

Neither requiring the loader nor calling it opens a demo window or starts the wx event loop. The calling application owns its windows, skins, and event loop. The framework does not require the Windows launcher's `APP_PATH` global.

Minimal application, with wxLua already available:

```lua
local wx = require("wx");
local loadwxLuma = require("wxLuma");
local wxLuma = loadwxLuma();
local Controls = wxLuma.Controls;
local oFrame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "wxLuma", wx.wxDefaultPosition, wx.wxSize(480, 240));
local oSkin = Controls.loadSkin();
local oButton = Controls.button(oFrame, {Skin = oSkin, Text = "Hello"});
oButton.layout(24, 24, 180, 40);
oFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
    oButton.destroy();
    oSkin.destroy();
    oEvent:Skip();
end);
oFrame:Show(true);
wx.wxGetApp():MainLoop();
```

The examples in the reference sections use `Controls = wxLuma.Controls`, an application-owned native `oParent`, and a shared `oSkin`. Methods use dot-call syntax unless a native wx object is being called.

## Image configuration

The loader returned by `wxLuma/init.lua` loads `wxLuma/config.lua` by default. Edit its setting to choose the artwork package:

```lua
local Config = {
    ImagePath = "Images",
};
```

A custom configuration is a Lua file returning a table, for example:

```lua
return {
    ImagePath = "Images",
};
```

The loader validates that the file returns a table with a nonempty string `ImagePath`. File, syntax, and configuration errors are reported to the caller. Custom configuration files execute as Lua code and should come from the application.

Relative image paths resolve against the framework folder, including paths supplied by a custom configuration. The default therefore selects `wxLuma/Images/`, containing `Controls/`, `Window/`, and `Menu/`. Absolute paths can select an external image package. The loaded `wxLuma.Config.ImagePath` is resolved to a full directory path.

Control skins default to `<ImagePath>/Controls/`; decorated windows default to `<ImagePath>/Window/`. Window ornament source PNGs are 256 by 256 pixels and display within 32-pixel corner bounds. The demo and tests use the same configured image package for their sample images. Explicit `Controls.loadSkin(pathWithTrailingSlash)` and window `AssetPath` options still override the defaults.

Load the framework through normal file-based Lua modules; configuration resolves its location from the Lua source filename using wxFileName. The caller remains responsible for making wxLua and the framework discoverable.

## Repository layout

```text
Repository/
├── README.md                 Framework reference and retained historical notes
├── LICENSE
├── wxLuma/                   Complete framework
│   ├── init.lua              Loader returning the framework table
│   ├── config.lua            Image package configuration
│   ├── Controls.lua          Factory facade and shared helpers
│   ├── Core/                 Shared object, event, rendering, and policy code
│   ├── Containers/           Window, Panel, Tabs, Dialog, Scroll/Split containers
│   ├── Widgets/              Individual widget implementations
│   └── Images/
│       ├── Controls/
│       ├── Menu/
│       └── Window/
└── Win/                      Windows test/demo host
    ├── test.exe
    ├── init.lua
    ├── Bin/                  Runtime DLLs
    ├── Source/               Native launcher, build script, and export records
    └── Tests/                Controls workbench, regressions, and benchmark data
```

## Available components

| Group | Factories on `wxLuma.Controls` |
| --- | --- |
| Input and actions | `checkbox`, `radio`, `slider`, `spinner`, `button`, `toggleButton`, `scrollbar`, `dropdown`, `textfield`, `numericField`, `colorPicker` |
| Display and data | `label`, `image`, `list`, `listEx`, `tree`, `treeEx`, `table`, `tooltip` |
| Progress | `progress`, `circularProgress`, `globeProgress`, `radialProgress`, `irisProgress` |
| Containers and dialogs | `panel`, `tabs`, `scrollContainer`, `splitContainer`, `dialog` |
| Menus and tools | `contextMenu`, `radialMenu`, `toolbar`, `statusBar` |

Shared helpers are `loadSkin`, `radioGroup`, `setDefaultContainmentOverflow`, and `getDefaultContainmentOverflow`. The decorated window surface is `wxLuma.Window.create`.

Instances use the framework's actual-storage/decoy/metatable pattern. Factories create independent instance state. Controls expose shared notification and containment APIs where applicable; setters are generally silent unless their optional notify argument is true. Each component's reference below describes its specific behavior and ownership rules. Dispose component-owned drawing resources before their shared skin; native window ownership ordinarily remains with the parent, with owned dialogs and popups documented separately.

## Windows demo and tests

Run `Win/test.exe` for the example window demonstrating all twelve categories of controls. Keep `Win/` beside `wxLuma/`, with the runtime DLLs under `Win/Bin/`. The launcher finds `Win/init.lua` from its executable directory; the loader searches upward for the framework and locally for `Tests.UI`. The launcher has been smoke-tested from an unrelated working directory.

Live resizing is supported. Close the window or press Escape to exit; Escape first dismisses an open dropdown or cancels a panel/split-container drag. Samples use isolated values, without original application startup, databases, mods, or preferences.

From the repository root in PowerShell:

```powershell
& .\Win\test.exe --smoke
```

The automatic check starts the workbench, changes tabs/list selection, resizes the live panel, closes, and collects garbage. Success writes `Win/smoke-result.txt`. Startup errors display a dialog and append to `Win/test-error.log`.

The runtime package contains 18 DLLs: the Lua/wxLua/wxWidgets dependency closure plus three app-local Microsoft C/C++ runtime DLLs. Windows supplies system DLLs and the Universal C Runtime. The demo does not use WebView or media features. The native host is Windows x64; no clean second-workstation validation is claimed.

### Rebuilding the test launcher

Use an x64 Visual Studio Developer Command Prompt with Lua 5.4 headers and a matching `lua54.lib`. From `Win/Source/`:

```bat
build.cmd "path to Lua include folder" "path to lua54.lib"
```

For the local development SDK, user-directory references can use `%USERPROFILE%`:

```bat
build.cmd "%USERPROFILE%\Sync\Projects\Wx Builder\lua-5.4.9\src" "%USERPROFILE%\Sync\Projects\Wx Builder\build-lua\lua54.lib"
```

The build writes `Win/test.exe` and `Win/Source/test.obj`. Development headers and libraries are not needed to run the packaged host. The launcher is compiled from `Win/Source/test.c`; it is not a renamed application executable.

### LuaEx and optional plugins

LuaEx is not included, initialized, or required by the framework demo. The host reserves `Win/Plugins/LuaEx/load.lua` for a future explicitly added integration. Its loader includes `Win/Plugins/?.lua` and `Win/Plugins/?/init.lua`; merely placing LuaEx there does not initialize it. The host uses no junction or external absolute plugin path.

### Verification and retained records

During the layout/configuration update on October 20, 2026, all 78 Lua files passed syntax loading; the entry point and default artwork worked without `APP_PATH`; the demo smoke check passed through the bundled Lua DLL; and the rebuilt executable's smoke check exited 0 from outside the repository. Tabs, Tools, and Checkbox/TreeEx regressions passed 209, 294, and 100 checks respectively. These are workstation-local results, not a claim that every regression or a clean-machine deployment was retested.

Historical copy/runtime hash records and validation notes remain under `Win/Source/`. They describe the original export; old counts, names, paths, and hashes must not be treated as a manifest of this reorganized tree. Historical benchmark procedures and numbers are retained below. The referenced baseline `Backups/` trees are absent from this checkout, so old-versus-new comparisons need those snapshots restored before reproduction. This documentation consolidation did not rerun benchmarks.

## Skinning controls

New visual controls must accept the shared `Skin` object. When a control needs artwork that does not yet exist, add named PNG assets under `Images/Controls` and exercise them in the workbench. Colour options remain available where useful.

Progress and CircularProgress accept `Appearance = "skin"` or `"colour"`. Both expose `getAppearance()` and `setAppearance(mode, notify)` for runtime switching. Progress retains its original colour-gradient default. CircularProgress defaults to skin unless an explicit `Colour` is supplied. Switching appearance preserves value, range, size and direction.

The shared skin loader accepts an artwork root: `Controls.loadSkin(pathWithTrailingSlash)`. Each PNG is named `Control <artwork name>.png`. The optional `Artwork` prefix selects alternate progress materials within that root.

| Control | Default material names |
| --- | --- |
| Progress | Progress Track Normal, Progress Fill Normal, Progress Track Disabled, Progress Fill Disabled |
| CircularProgress | Circular Progress Track Normal, Circular Progress Fill Normal, Circular Progress Track Disabled, Circular Progress Fill Disabled |

These are opaque RGB material images, rather than fixed screenshots of a particular progress value. The circle masks square materials into its ring and sector; `Thickness` still determines the hole. Linear progress clips full-width materials so their texture stays stationary as the fill changes. The supplied circle materials are 256 x 256; linear materials are 256 x 64. Other source dimensions are scaled by the skin cache.

CircularProgress renders its geometry at four times the target resolution, then downsamples with wxImage high-quality scaling. This antialiases both circular edges and sector boundaries in colour and skin modes using core wx facilities. Each control retains one final raster and rebuilds it only when diameter, value, direction, enabled state or appearance changes. The shared skin caches its latest scaled material size per name, as for other controls.

`Skin.getBitmap(name, width, height, vertical)` returns borrowed cached artwork for custom renderers. Do not modify or delete the bitmap. The next scaled size for that name may replace it. Destroy controls before their shared skin.

The Resources & panel workbench page provides separate skin toggles for the linear meters and circular meter.

GlobeProgress and RadialProgress also use dedicated 256 x 256 opaque material images. Their default prefixes are Globe Progress and Radial Progress, respectively, with Track Normal, Fill Normal, Track Disabled and Fill Disabled variants. The shared renderer masks these into the circular geometry and supersamples the fill boundary. Artwork can be replaced through the same skin root/Artwork options as other progress controls.


## Progress controls

### Progress geometry

The existing Progress object handles horizontal and vertical bars. No new object is required. Options `Orientation = "horizontal" | "vertical"` and `Origin = "left" | "right" | "top" | "bottom"` can be supplied at creation. The default is horizontal from the left. An explicitly vertical bar defaults to the bottom, filling upward. Origin alone infers the axis; conflicting explicit creation options are rejected before creating a native control.

`getOrientation()` and `setOrientation(axis, notify)` read/change the axis. Changing orientation maps forward origins left/bottom and reverse origins right/top. `getOrigin()` and `setOrigin(edge, notify)` read/change the starting edge; setOrigin automatically changes orientation to match. Neither setter changes value, layout dimensions or appearance. Call layout explicitly if the surrounding layout should change.

Both colour and skin modes support all four origins. Vertical skin materials rotate clockwise, then retain their full extent while the fill clips from the chosen edge. Center text stays horizontal and clips to the available interior; choose shorter text or an empty Text string for narrow bars.

CircularProgress accepts `StartAngle` at creation and exposes `getStartAngle()`/`setStartAngle(degrees, notify)` at runtime. Angles use clock-face coordinates: 0 top, 90 right, 180 bottom, 270 left. CW/CCW independently controls the sweep from that angle. Finite fractional and negative degrees are supported and normalize to [0, 360). The default remains 0, preserving the original twelve-o'clock start. Equivalent wrapped angles are no-ops.

All setters return the component, are silent by default, and notify only on effective changes when requested. Events are `orientationChanged` (Orientation/OldOrientation), `originChanged` (Origin/OldOrigin) and `startAngleChanged` (StartAngle/OldStartAngle). Geometry changes do not emit valueChanged or OnChange.

The Resources & panel workbench includes a directional progress meter with an origin button cycling bottom, top, right and left. The shared slider changes its value too. A separate circle-start button advances by 45 degrees without changing CW/CCW or progress.

### GlobeProgress and RadialProgress

Create with `Controls.globeProgress(parent, options)` or `Controls.radialProgress(parent, options)`. Both use independent public objects and the existing `Min`/`Max`/`Value`, `getValue()`, `setValue(value, notify)`, appearance, skin, input-event and containment APIs. No timers run. Non-square bounds preserve a centered circle. Geometry is antialiased in both skin and colour modes and caches one raster per object.

GlobeProgress represents a straight liquid level inside a circular silhouette. Default is `Origin = "bottom"` and `Orientation = "vertical"`. All four origins are available through `getOrigin()`/`setOrigin(edge, notify)`; origin also sets the matching axis. `getOrientation()`/`setOrientation(axis, notify)` follow Progress's left/bottom forward and right/top reverse mapping. Progress measures level distance across the diameter, not filled circular area. The globe does not distort when the axis changes.

RadialProgress uses `Direction = "outward"` (default, center to rim) or `"inward"` (rim to center). Change it through `getDirection()`/`setDirection(direction, notify)`. Both directions are empty at Min and full at Max. Progress measures radial distance: 50% outward is a filled disc of half the outer radius; 50% inward is a filled ring surrounding a track disc of half the outer radius. This is not an angular sweep and has no starting-angle setting.

Both accept `Text` (%v/current, %m/max), `Colour = {R, G, B}`, `Appearance = "skin" | "colour"` and `Artwork`. Default appearance is skin unless Colour is supplied. Dedicated material prefixes are Globe Progress and Radial Progress, each with Track/Fill Normal/Disabled PNGs under the shared skin root. Materials stay stationary while the filled region changes. The skin owns its cached bitmaps; destroy controls before their shared skin.

Setters validate before changing state, preserve value when changing geometry or appearance, and return the public component. Notification defaults to false. User observers use `valueChanged` and `appearanceChanged` plus globe `orientationChanged`/`originChanged` or radial `directionChanged`. Shared on/off mouse, keyboard, hover, focus, enabled, size and lifecycle events are available as for the other progress controls.

The Orb meters workbench category demonstrates both objects with runtime direction buttons, independent skin toggles and a shared progress slider.


### Reserved capacity (all progress controls)

`Reserved` defaults to `0` and is an amount in the same units as `Value`.
It must be finite and within `0 .. Max - Min`. All controls expose
`getReserved()`, `setReserved(amount, notify)`, `getEffectiveMax()` and `isFull()`.
Effective maximum is `Max - Reserved`. Changing reserve preserves current value;
rendering saturates at effective maximum. An entirely reserved range displays
only reserve and has no usable capacity. Invalid setters leave state unchanged.

Current, empty track, and reserved capacity are separate regions. Current fills
the usable path while skipping reserve; they never overlap. Geometric fractions
measure path distance (linear level, angle, or radius), not circular area.
Nonparallel reserve origins can make different path positions contain different
amounts of visible area. Tiny fractions are limited by raster resolution.
Zero reserve preserves the original rendering and progress geometry.

Linear bars and globes accept `ReserveOrigin = left/right/top/bottom` and
`getReserveOrigin()` / `setReserveOrigin(edgeOrNil, notify)`. This may be
perpendicular to the normal fill. Radial controls accept `ReserveDirection =
inward/outward` and matching get/set methods. Circular controls accept
`ReserveDirection = CW/CCW` and `ReserveStartAngle` in clock-face degrees,
with matching get/set methods. Finite angles wrap modulo 360.

Nil reserve geometry means automatic: reserve grows backwards from the full end
of the normal fill path. It follows later normal origin/direction/start changes.
Getters return nil while automatic; passing nil restores that policy.
An explicit angle or direction remains independent of normal geometry changes.

Changed-only, opt-in events: `reservedChanged`, `reserveOriginChanged`,
`reserveDirectionChanged`, `reserveStartAngleChanged`. Events include the new
property and `Old<Property>`; reservedChanged also supplies `EffectiveMax`.
These are notifications, not value changes; reserving does not call OnChange.

Each material prefix adds `Reserve Normal` and `Reserve Disabled` artwork.
The included reserve is purple with diagonal detail; each object's Skin/Artwork
can supply its own. Colour mode uses a distinct purple reserve as well.

These settings are independent of any resource framework. To display a CoG Pool,
pass its final MAX, CURRENT, and total RESERVED values to the control; the pool
continues to calculate flat/percentage reservations and modifiers. Applications
can supply equivalent values from any model. Update reserve/value together in
the same application update before yielding to the native event loop.

### Circular pie and radial bands

CircularProgress and RadialProgress accept `InnerRadius` and `OuterRadius`,
percentages of the available circle radius. Require `0 <= inner < outer <= 100`.
`InnerRadius = 0, OuterRadius = 100` makes circular progress a solid pie sector.
`75, 100` makes an outer ring; `25, 60` selects a band inside the circle.
Circular progress still sweeps CW/CCW from StartAngle; radial progress still
advances inward/outward through the selected band.

`getRadii()` returns inner/outer percentages; circular legacy mode returns nil
for inner, indicating the original pixel Thickness. `setRadii(inner, outer,
notify)` changes the band atomically and optionally emits `radiiChanged` with
old/new radius fields. `setRadii(nil, nil)` restores the original geometry.
Without radius options, circular Thickness remains 12 pixels by default and
radial progress remains a full disc. Text remains in the circular hole; a solid
pie has no hole and therefore does not draw center text.

The Orb meters workbench page includes current/reserve sliders and independent
reserve direction buttons. The solid pie toggle is beside the circular meter
on the Resources & panel page.


### IrisProgress

`Controls.irisProgress(parent, options)` creates a skinnable camera aperture.
`BladeCount` defaults to 6 (integer 3..32); `Rotation` is clock-face degrees.
`Direction` is `opening` (default, value opens the iris) or `closing` (value grows
blade coverage). Min/Max/Value, Text, Colour, Appearance, Artwork, Enabled and
containment follow the other progress controls. At maximum opening the entire
disc is uncovered; partial openings have the polygonal edges of an iris.
The control does not run a timer: applications animate by changing its value.

Runtime get/set pairs: `BladeCount`, `Rotation`, `Direction`, `Appearance`,
`BackgroundImage`, and `BackgroundImageFit`. Setters take an optional final notify
boolean, default false. Changed-only events use the corresponding camelCase
property followed by `Changed`; event snapshots include old/new property values.
Standard pointer, key, focus, enable, lifecycle and value events remain available.

`BackgroundImage` is an optional image path; nil clears it. The image appears
through the aperture and is always clipped to the opening and outer globe.
Blades and reserved capacity cover it. `BackgroundImageFit` is `cover` (default),
`contain`, or `stretch`, centered within the full globe. Transparent image pixels
composite against Track. Invalid image loads preserve the previous image.
Notifying successful loads also emit `imageLoaded` with path and dimensions.

Reserved capacity uses the shared get/setReserved, getEffectiveMax and isFull API.
`ReserveDirection` is `inward` or `outward`; nil automatically reserves from the
full end of the normal progress path. Reserve follows the iris polygon boundaries
and never overlaps current. Fractions measure blade-edge distance, not area.

Artwork prefix defaults to `Iris Progress`. Materials, each Normal/Disabled:
Background, Track, Fill, Blade, Blade Alternate, Reserve, Seam, Text. A per-object
Skin/Artwork can replace all visuals. The raster uses four-times supersampling
and caches unchanged geometry; decoded images and composed rasters are owned by
the object and released by destroy. Native window ownership remains with parent.

The Orb meters workbench category includes the iris, shared current/reserve
sliders, direction and blade/rotation buttons, and a clipped-picture toggle.


GlobeProgress, RadialProgress and IrisProgress accept `Supersampling = 2` or `4`
(default `4`), with `getSupersampling()` and `setSupersampling(scale, notify)`.
Both settings antialias the same geometry; 2 reduces raster work for groups of
frequently changing meters. Changed-only notifications use `supersamplingChanged`
with `Supersampling` and `OldSupersampling`. The Orb meters workbench examples
use 2 so dragging their shared slider does not rebuild three large 4x rasters.
Iris backgrounds are fitted once per source/size/fit/appearance/enabled state;
value, blade and reserve changes reuse that fitted image. Native bitmap masks
clip the fitted image to both the aperture and the globe.


## List and Table selection

List, ListEx and Table use the same selection API. Creation option `MultiSelect` defaults to `false`. Dropdowns retain their standard single-choice behavior.

| Method | Behavior |
| --- | --- |
| `getSelected()` | Independent array in display order; always a table, including zero or one selection. |
| `setSelected(tRows, bNotify)` | Replace selection atomically. Empty array clears. Multiple distinct rows require multi-select. Last requested row becomes primary/focused. |
| `isMultiSelectEnabled()` | Read the current mode. |
| `setMultiSelectEnabled(bEnabled, bNotify)` | Change mode at runtime. Disabling retains the primary selected row. |
| `getValue()` | Existing scalar primary row; zero for an empty List/ListEx, nil for an empty Table. |
| `setValue(vRow, bNotify)` | Replace selection with one row even in multi-select mode. Zero/nil clears as before. |

List/ListEx identifiers are one-based row indices; use `getItem(index)` for the selected data. Table identifiers are stable strings; use `getRow(id)` for row snapshots. Returned selection arrays can be edited without changing the control.

With multi-select enabled, plain click replaces selection, Shift+click selects an anchored range, Ctrl/Cmd+click toggles a row, and Ctrl/Cmd+Shift+click adds a range. Shift with arrows, Home/End or Page Up/Down extends selection. Ctrl/Cmd+arrows moves focus without clearing membership; Ctrl/Cmd+Space toggles the focused row. Ctrl/Cmd+A selects all. Table delegates its platform-specific gestures to the native wxListCtrl.

Setters are silent unless `bNotify` is true. User gestures notify automatically. `selectionChanged` includes `Selected` and `OldSelected` arrays plus compatible scalar `Value`/`OldValue` fields. `valueChanged` reports primary-row changes. `OnChange(primary, component, selected)` retains its original first two arguments and supplies the full array as a third. `multiSelectChanged` includes `Enabled`. Repeated unchanged selections remain silent. Native Table range changes are coalesced at idle; getters reflect native selection immediately.

List/ListEx removal shifts all surviving indices with their logical rows. Replacement retains valid selected positions; the existing single-selection clamp remains. Table sorting/replacement preserves surviving stable IDs. Removing a primary row retains the first surviving selection, or clears when none remain.

Workbench: Lists & text has a List multi-select checkbox. Data has separate Table and ListEx checkboxes. Each starts disabled, matching the default.


## TreeEx

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

### Selection and hierarchy

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
creation/runtime opt-out. See [Item checkboxes](#item-checkboxes) for the shared checkbox API,
per-item events, modifier keys and propagation rules.

### Mutable data

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

### Skins

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


## Item checkboxes

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

### Tree propagation

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


## Tabs

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

### Layout

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

### Selection and keyboard

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

### Runtime pages

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

### Events and skins

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

The workbench uses measured wrapping for its twelve readable categories.
The **Tabs** category contains a nested example with wrap/scroll, edge changes,
adding, removing, renaming and moving pages. Earlier category indices are retained.


## ContextMenu and RadialMenu

Create `Controls.contextMenu(parent, options)` or `Controls.radialMenu(parent, options)`. The parent is a native window or visual component defining lifetime and inherited containment. Each menu is an independent actual/decoy/metatable object. Menus share the skin, event and containment APIs without inheriting from another visual object.

### Items

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

### Opening and selection

- `showAt(screenX, screenY)` opens programmatically. The point is the context popup's top-left or the radial ring's virtual center.
- `showAtObject(target)` opens at a native/visual target's center.
- `attach(target)` adds native right-click/context-key opening. Target must belong to the menu's lifetime parent. Reattaching is idempotent; `detach(target)` or `detach()` disables attachments. Attachments and programmatic opening can coexist.
- `setAnchor(x, y)` changes the requested screen anchor without resetting navigation. `getAnchor()` returns its effective position after minimal containment adjustment.
- `close(reason)` dismisses and resets navigation to the root, as do outside clicks, deactivation, target loss and disabling. `isOpen()` reports state.
- `activateItem(id)` activates an enabled visible item and returns true plus a selection snapshot for an action. Back/More/submenu entries navigate without completing a selection.

Menu opening is asynchronous; it does not block the wx event loop. Selecting an action closes the menu and resets navigation **before** delivering `OnSelect(selection, menu)` and `selected`. The snapshot contains Id, Text, application Value and a Path of real item IDs. Back/More never appear in Path. `getSelection()` returns an independent completed snapshot and `getValue()` its Id. A new opening clears the previous result; cancelling that opening leaves no selection. A completed action result remains readable after closing. Listener-driven reopening cannot replace the result delivered to the original callback.

### Radial layout

Defaults: Direction CW, StartAngle 0 (top), Shape circle, Spacing 12px, MinRadius 64px, MaxRadius 160px, ItemWidth/ItemHeight 64px. Angles are clock-face degrees: 90 right, 180 bottom, 270 left. Negative/fractional angles are allowed and normalize modulo 360.

Item centers disperse evenly around the virtual ring. Radius measures item centers; popup bounds account for complete item footprints. The solver chooses a fitting radius in the configured range, checks every pair of conservative rectangular footprints, and preserves minimum edge-to-edge spacing. Item dimensions are never reduced to make a page fit. Explicitly overflowing images enlarge footprints. Native coordinates round to pixels.

Runtime methods are `get/setDirection(CW|CCW, notify)`, `get/setStartAngle(degrees, notify)`, `get/setSpacing(pixels, notify)`, `getRadiusRange()` and `setRadiusRange(min, max, notify)`. `get/setShape(shape, notify)` controls inherited shapes; explicit item shapes remain unchanged. Shape changes reopen at the root. Other policies recompute the current page. Setters return the menu, are silent by default and notify only when changed.

Items that cannot fit move behind the final More button. Every nested submenu and overflow page begins with Back, restoring the immediately preceding page. Overflow pages can overflow again. All overflow pages are checked for forward progress before opening that branch. If even the required navigation plus a real choice cannot fit, opening/navigation returns false and a clear reason, without shrinking or losing items. A failed submenu opening leaves the current page available. Runtime settings that cannot fit dismiss with layoutFailed.

### Context layout and input

Context defaults: Width 240px, ItemWidth 232px, ItemHeight 40px, Spacing 2px. Rows retain configured dimensions; excess rows paginate through the same Back/More mechanism. Context submenus replace the current page and include Back, following the requested shared navigation model.

Mouse activation uses host-shape hit testing. Arrows and Tab traverse enabled choices; Enter/Space activates. In a context menu, Right opens the focused submenu/More and Left goes back. Escape goes back, then closes at root. Clicking outside dismisses and resets to the first menu. `getFocusedItem()` and independent `getLayout()` geometry snapshots support tooling and integration.

### Containment, rendering and skins

Default boundary is the topmost parent client area, intersected with visible ancestors and display work area. Popup position and its effective anchor move only the minimum needed on each overflowing axis; item sizes never change. Explicit Containment/ContainmentOverflow overrides use the shared APIs. The default hide policy paginates to fit the boundary. Explicit allow lifts containment size limits while retaining the configured radial maximum and item dimensions; placement follows shared leading-edge behavior for oversized popups.

Each menu accepts its own Skin and Artwork prefix (default Menu). Material files are `Control Menu <Circle|Diamond|Square|Row> <Normal|Hover|Pressed|Disabled>.png`. Item Artwork overrides select alternate material prefixes. Source images and rendered states have bounded caches; shape/image clips are supersampled into alpha-aware bitmaps. Radial popups use native shaped frames where supported, with a rectangular fallback. No optional graphics-context backend is needed. Dispose menus before their shared skin.

Menus expose standard on/off mouse, keyboard, focus, enabled, size and lifecycle subscriptions plus opened, closed, selected, pageChanged, itemsChanged, itemHovered, itemLeft, itemFocused, layoutFailed, imageError and runtime-policy events. Selection and item snapshots preserve application Value identity.

The Menus workbench category demonstrates both opening methods, mixed shapes, images plus text, clipping/overlap, disabled actions, multi-level submenus, nested overflow and runtime direction/angle/spacing/radius controls.


## Editors and dialogs

All factories return independent actual/decoy objects, accept their own `Skin`,
and expose the usual `on`/`off`, enabled state, disposal, and containment methods.
Setters are silent unless `bNotify` is true. Dot-call methods match the other controls.

### ToggleButton

```lua
local oAutoCast = Controls.toggleButton(oParent, {
    Skin = oSkin,
    Text = "Auto-cast",
    Value = false,
    OnChange = function(bValue, oComponent)
        -- Apply persistent state.
    end,
});
oAutoCast.setValue(true, true);
```

`getValue()` always returns a boolean. Mouse, Enter, and Space activate on release;
key repeat and a cancelled press do not cause extra toggles. The persistent value
is independent of hover and press state. Disabled controls retain their value.

Artwork prefix defaults to `Toggle Button`. Its eight materials are
`Control Toggle Button {Off|On} {Normal|Hover|Pressed|Disabled}.png`.
A different `Artwork` prefix selects equivalent custom materials from this Skin.

### NumericField

```lua
local oAmount = Controls.numericField(oParent, {
    Skin = oSkin,
    Min = -100,
    Max = 100,
    Value = 12.5,
    Step = 0.25,
    Precision = 2,
    StepButtons = true,
});
oAmount.layout(16, 16, 220, 40);
```

Defaults: range 0–100, Value at Min, Step 1, Precision 2, step buttons on,
read-only off. `TextControl` exposes native caret, selection, clipboard and editing.

- `getValue()` / `setValue(number, bNotify)` use a finite number. Setters clamp
  to the range and round to Precision. Values are not snapped to Step.
- Typing and paste accept signed decimal text only. Letters, whitespace, repeated
  signs and repeated decimal points are rejected. An invalid paste is rejected
  as a whole. Empty text, a leading sign, and an unfinished decimal point remain
  editable until commit; scientific notation and hexadecimal text are not accepted.
- `commitText()` accepts complete finite in-range numeric text and returns true.
  Enter and focus loss commit. Invalid text restores the last committed value,
  emits `validationFailed`, and returns false.
- Up/Down step once; Page Up/Down step ten times. Pending edits commit before
  stepping; invalid edits restore before stepping. Left/Right/Home/End retain
  native text navigation. Escape restores uncommitted text.
- `getRange()` returns Min, Max; `setRange(min, max, bNotify)` validates atomically
  and clamps the current value.
- `getPrecision()` / `setPrecision(digits, bNotify)` support 0–10 decimal places.
  Ranges must contain at least one representable decimal, and their scaled
  magnitudes must remain below 2^52. Step must be at least one decimal unit.
- `getStep()` / `setStep(step, bNotify)` change the increment without snapping
  the current value. Each resulting value rounds to Precision.
- `isReadOnly()` / `setReadOnly(boolean, bNotify)` control user editing and
  stepping. Programmatic updates still work. `StepButtons=false` omits arrows.

Extra events: `textChanged`, `committed`, `validationFailed`, `rangeChanged`,
`precisionChanged`, `stepChanged`, `readOnlyChanged`, plus standard `valueChanged`
and pointer/button/keyboard/focus/lifecycle events on the frame and native editor.

Artwork prefix defaults to `Numeric Field`, with four state materials. Step arrows
use the existing skinnable Spinner Up/Down materials. The native text background
uses the framework's common charcoal, as existing text editors do.

### Dialog

```lua
local oPrompt = Controls.dialog(oParent, {
    Skin = oSkin,
    Title = "Confirm action",
    Message = "Apply these settings?",
    Buttons = {"yes", "no", "cancel"},
    DefaultResult = "yes",
    OnClose = function(sResult, oComponent)
        -- Modeless completion, or modal completion before showModal returns.
    end,
});
oPrompt.show();                 -- Modeless; boolean opening success.
-- local sResult = oPrompt.showModal(); -- Native blocking modal loop.
```

Standard results are `ok`, `cancel`, `yes`, `no`. Buttons default to `{ok,cancel}`;
one through four unique standard buttons are accepted. DefaultResult defaults to
the first button. CancelResult defaults to `cancel` and may be any standard result,
even when that result is not a displayed button.

- `Dialog` is the owned native dialog. `Control` is its skinned client surface.
  Parent application controls to `Content`, then lay out those children normally.
- `show()` returns false when already open or disabled. `showModal()` returns nil
  in those cases; otherwise it returns the completed result from the native modal
  invocation, even if its completion callback reopens the same object.
- `close(result)` completes once and hides for reuse. Omitted result, title close,
  and Escape use CancelResult. `isOpen()` reports visibility; `getValue()` returns
  the completed result. Each new opening clears the previous result.
- Enter on an action button activates that button on release. Elsewhere it chooses
  DefaultResult, except editors that process Enter or support multiline text retain
  their own Enter behavior.
- `opened` includes Modal; `closed` includes Result and Value. OnClose receives
  `(result, publicDialog)`. Generic pointer/focus/lifecycle events are available.
- `layout(screenX, screenY, clientWidth, clientHeight)` sets explicit bounds;
  minimum client size is 320×200. Opening centers on the owner. Defaults 480×300.
- Ordinary dialogs retain native title chrome, focus traversal and modal ownership.
  Their child popups inherit the dialog as their default containment window.
- `destroy()` ends an active modal loop and destroys the owned native dialog once;
  it does not call OnClose. Dispose dialogs before disposing their shared Skin.

Artwork defaults to `Dialog`, with Normal and Disabled materials. Standard action
buttons use the existing button skin. Application controls inside Content can each
choose their own Skin as usual.

The **Editors** workbench category demonstrates every new object,
including fields with/without step buttons and read-only editing, plus both dialog modes.


## Toolbar, StatusBar and ColorPicker

Factories are `Controls.toolbar`, `Controls.statusBar`, and `Controls.colorPicker`.
All return independent actual/decoy/metatable objects with the standard dot-call
surface, enabled, lifecycle, containment and `on`/`off` APIs. Every object accepts
its own `Skin` and optional `Artwork` prefix. Native window ownership remains with
the parent; owned popup resources are released by `destroy()`.

The **Tools** workbench category demonstrates all three objects, including command
mutation, independent toggle state, overflow, status-hosted progress, and alpha.

### Toolbar

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

### StatusBar

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

### ColorPicker

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

### Skin materials

All new decoration comes from `Images/Controls/Control <prefix> <part>.png`.
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


## Historical measurements and export notes

The following reports preserve the original methods, tables, fixes, limitations, and reproduction instructions. Their paths, backup availability, export counts, and validation claims refer to the recorded snapshots, not automatically to the current layout. Current setup instructions are above. The benchmark reports describe different workloads and must not be combined as directly comparable results.

<details>
<summary>Redraw optimization results — October 20, 2026</summary>

### wxLuma redraw optimization results

Measured October 20, 2026 on the current Windows workstation. All UI component instances retain the actual/decoy/metatable design.

#### Changes

- Unchanged generic, checkbox, radio and snapped numeric values avoid default-background invalidation.
- Pointer movement within the same drawn state/part and keyboard auto-repeat no longer repaint unchanged controls. Value changes during dragging still invalidate through their setters.
- Repeated enabled state and identical geometry avoid unnecessary native work. First layout and real size changes still lay out children.
- Radio groups invalidate members whose selected indicator changes; custom backgrounds retain their explicit refresh behavior.
- Stable native text bindings preserve caret and selection. Numeric editors still canonicalize input such as 004 to 4. Disabled text changes explicitly invalidate the surface that paints their text.
- Repeated identical dropdown layout no longer dismisses an open popup.

#### Native paint-count checks

RedrawRegression.lua exercises 100 repeated unchanged operations per case. Checkbox values, snapped slider values, spinner values, pointer motion, surface motion, enabled state, input layout and key repeat each fell from 100 paints to zero. Repeated radio selection fell from 200 paints to zero. Changed values, focus changes, custom backgrounds, native editing and real layouts remain covered by passing checks.

#### Fair active-game comparison

Three implementations ran in fresh processes with alternating order: original plain controls; the exact pre-optimization object snapshot; and optimized objects. Each implementation received the same workload, 120 warmup frames and 600 measured frames per trial, with two trials per workload.

The scene uses a separate native animated viewport alongside the HUD. Refreshing the decorated parent window can invalidate all its children, defeating dirty-control rendering. The viewport arrangement is identical for all three implementations, and its benefit is not attributed to the framework optimization.

- Target: 120 Hz; 8.333 ms budget. High-resolution 10 MHz monotonic clock.
- Client area: 1360 x 940. Each frame includes a 2 ms synthetic game-logic reservation.
- HUD: 22 wxLuma widgets, a 10,000-row scrolling list and 120 moving rectangles in the benchmark viewport.
- Heavy: 90 wxLuma widgets, four 10,000-row scrolling lists and 600 moving rectangles in the viewport.
- Model bindings are polled each frame. Most resource values change periodically; a quarter of meters animate continuously. Sliders step every six frames. Actions, native editor commits, continuous list scrolling and panel resizing remain active.
- The viewport redraws continuously. Unchanged child controls are not forcibly invalidated by the harness. Every dirty top-level control must finish its native paint without error before the frame completes.
- Rates count completed native UI paint batches, not monitor presentation or GPU game frames. There is no full game-world renderer in this benchmark.

| Workload | Implementation | Mean completed batches/s | Mean median UI ms | Mean median total work ms | Paint calls | Work frames over budget |
|---|---|---:|---:|---:|---:|---:|
| HUD | Original plain | 119.89 | 4.131 | 6.134 | 15020 | 52/1200 |
| HUD | Objects before optimization | 119.89 | 4.084 | 6.086 | 15020 | 62/1200 |
| HUD | Optimized objects | 119.90 | 2.477 | 4.479 | 7108 | 30/1200 |
| Heavy | Original plain | 91.71 | 8.214 | 10.216 | 54020 | 1200/1200 |
| Heavy | Objects before optimization | 91.20 | 8.285 | 10.287 | 54020 | 1200/1200 |
| Heavy | Optimized objects | 118.18 | 4.773 | 6.775 | 29432 | 353/1200 |

HUD: median UI work decreased 39.3% against the exact object snapshot; mean completion rate changed 0.0%.

Heavy: median UI work decreased 42.4% against the exact object snapshot; mean completion rate changed 29.6%.

The means above average two trial medians or rates, rather than computing pooled percentiles. All three implementations produced matching callback counts and final list selections. The optimized heavy workload approaches 120 batches/s on average, but 353 of 1,200 frames exceeded 8.333 ms; sustained deadline-perfect 120 Hz has not been established.

| Workload | Version | Round | Work p95 ms | Work p99 ms | UI p95 ms | UI p99 ms |
|---|---|---:|---:|---:|---:|---:|
| HUD | Old | 1 | 7.880 | 9.296 | 5.878 | 7.294 |
| HUD | Before | 1 | 8.242 | 10.448 | 6.238 | 8.446 |
| HUD | New | 1 | 7.229 | 8.987 | 5.228 | 6.984 |
| HUD | New | 2 | 7.762 | 8.733 | 5.755 | 6.731 |
| HUD | Before | 2 | 8.366 | 9.469 | 6.364 | 7.466 |
| HUD | Old | 2 | 8.225 | 9.429 | 6.224 | 7.428 |
| Heavy | Old | 1 | 13.431 | 17.617 | 11.428 | 15.615 |
| Heavy | Before | 1 | 13.224 | 16.905 | 11.222 | 14.902 |
| Heavy | New | 1 | 11.283 | 16.430 | 9.281 | 14.427 |
| Heavy | New | 2 | 11.232 | 16.468 | 9.230 | 14.466 |
| Heavy | Before | 2 | 14.203 | 17.263 | 12.201 | 15.260 |
| Heavy | Old | 2 | 14.589 | 18.269 | 12.588 | 16.267 |

The earlier forced-full-redraw results in GameStressResults.json remain historical data. They are not directly comparable to Game-mode results because their workload redraws the parent and every control continuously. The interrupted Dirty-mode diagnostic also animated the parent and masked child invalidation savings; it is not used for the comparison above.

#### Validation and backup

- ObjectRegression.lua passed 1,680,764 checks, including RGB parity, callbacks, cache churn and repeated disposal.
- RedrawRegression.lua passed 38 targeted native paint-count and behavior checks.
- ListStress.lua --integration-only passed native input capture, radio navigation, panel cancellation, resizing, popup positioning, commit/cancel and shutdown.
- The complete pre-optimization Scripts tree is preserved, with hashes verified, in Backups/UI-before-redraw-optimization/Scripts. That is the Before implementation measured above.

#### Repeat

Run GameStress.ps1 -Mode Game with PowerShell 7 for all twelve isolated trials. The aggregate result is GameStress-Game-Results.json; each trial also has its own JSON file. -Mode Full retains the forced-full-redraw workload. -Mode Dirty retains the parent-refresh diagnostic. Running a mode again replaces that mode's result files.

</details>


<details>
<summary>Forced full-redraw stress comparison — October 20, 2026</summary>

### wxLuma active UI stress comparison

Measured on the current Windows workstation on October 20, 2026. Values are native UI paint-batch completion rates, not monitor-presented or GPU game frame rates.

#### Method

- Target: 120 Hz, or 8.333 ms per logical frame.
- Fresh process for every trial; old/new order reversed in the second round.
- Each trial: 120 warmup frames and 600 measured frames; 1,200 measured frames per implementation per workload.
- Same 1360 x 940 client area, artwork, values, callbacks and scripted inputs.
- HUD: 22 top-level widget instances, one 10,000-row list and 120 moving background rectangles.
- Heavy: 90 top-level widget instances, four 10,000-row lists and 600 moving background rectangles. Native child controls add further work.
- Lists scroll continuously; meters, sliders and scrollbars change every frame. Scripted actions and text commits occur every 12 frames; the panel resizes every 30 frames.
- Every frame includes a fixed 2 ms synthetic CPU game-logic budget. This is a time reservation, not a full game simulation.
- The complete background and all top-level widgets are explicitly invalidated and synchronously painted every frame, including otherwise static controls. This is a demanding full-redraw workload.
- QueryPerformanceCounter-backed clock at 10 MHz. The benchmark temporarily requests 1 ms timer resolution and restores it on exit.
- Draw wrappers capture native paint errors. Each frame verifies every requested top-level control paint completed; callback counts and final selection match between versions.
- Old code comes from the separate pre-conversion backup, with ListPlain used for both ordinary and dropdown lists. New code uses the shared actual/decoy/metatable implementation and the corrected skin cache.

#### Results

| Workload | Old mean paint batches/s | New mean paint batches/s | New throughput change | Old mean median work ms | New mean median work ms |
|---|---:|---:|---:|---:|---:|
| HUD | 98.16 | 98.08 | -0.08% | 9.833 | 9.853 |
| Heavy | 40.31 | 37.84 | -6.13% | 23.396 | 24.191 |

These are arithmetic means of two trial rates and two trial medians; they are not pooled percentiles. The HUD difference is within observed run-to-run variation. Heavy-workload throughput was about 6.1% lower for the object version in this run.

| Workload | Version | Round | Paint batches/s | Work median ms | Work p95 ms | Work p99 ms | UI-only median ms | Frames over 8.333 ms |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| HUD | Old | 1 | 100.63 | 9.555 | 12.154 | 14.654 | 7.553 | 600/600 |
| HUD | New | 1 | 100.17 | 9.639 | 11.978 | 13.853 | 7.637 | 600/600 |
| HUD | New | 2 | 96.00 | 10.068 | 12.725 | 14.211 | 8.066 | 600/600 |
| HUD | Old | 2 | 95.69 | 10.112 | 12.758 | 15.027 | 8.110 | 600/600 |
| Heavy | Old | 1 | 40.52 | 23.279 | 34.147 | 46.440 | 21.276 | 600/600 |
| Heavy | New | 1 | 36.76 | 25.177 | 38.785 | 44.096 | 23.175 | 600/600 |
| Heavy | New | 2 | 38.91 | 23.205 | 39.342 | 51.902 | 21.203 | 600/600 |
| Heavy | Old | 2 | 40.09 | 23.512 | 33.419 | 47.293 | 21.510 | 600/600 |

Neither version met the 120 Hz budget under these forced full-redraw workloads. The object pattern had little effect on the HUD trial and a measurable cost in the heavy trial. These measurements do not isolate the dominant native rendering cost and do not establish a universal maximum frame rate. Updating only dirty controls, using smaller UI regions or batching drawing would require separate measurements.

#### Regression fixes and validation

- Corrected a conversion-induced ControlSkin local-variable shadowing error: natural bitmap allocation dimensions must remain separate from optional requested dimensions used by cache metadata.
- Corrected a conversion-induced Dropdown shadowing error: popup placement uses the field height independently of the popup height.
- Pre-fix files are preserved in Backups/GameStress-before-skin-fix. The original pre-conversion backup remains unchanged.
- ObjectRegression.lua passed 1,680,764 checks, including natural/scaled cache churn, callback parity, RGB rendering and repeated disposal.
- ListStress.lua --integration-only passed native capture, radio navigation, panel cancellation, resizing, popup anchoring, commit/cancel and close checks.

#### Repeat

Run GameStress.ps1 with PowerShell 7 to repeat all eight trials. It writes GameStressResults.json and individual trial JSON files beside the test. Framework modules and the production launcher are not modified by the benchmark.

Reproduction update: the current GameStress.ps1 defaults to Game mode and also measures the preserved pre-optimization objects. Use -Mode Full for the forced-full-redraw workload described above. These historical results are unchanged; see [the redraw optimization report](#wxluma-redraw-optimization-results) for the new comparison.

</details>


<details>
<summary>Original standalone export and runtime/licensing notes</summary>

### UI Test

Copy this entire folder to another Windows x64 workstation and run test.exe. Keep Bin, Scripts and Images beside it. No installation, original repository, game startup, database, mods or preferences are used. Paths come from test.exe's own folder, regardless of the working directory. Live resizing is retained. Close the window or press Escape to exit (Escape first dismisses an open dropdown or cancels a panel drag).

Bin contains the Lua/wxLua/wxWidgets DLL dependency closure and three app-local Microsoft C/C++ runtime DLLs. Windows supplies its system DLLs and Universal C Runtime. This export was tested on the current Windows workstation, not a clean second machine. No WebView browser or media feature is used by the workbench.

#### LuaEx

LuaEx is deliberately NOT included. Its reserved relative location is Scripts/Plugins/LuaEx/load.lua (put the LuaEx package folder, containing load.lua, at Scripts/Plugins/LuaEx). The loader already includes Scripts/Plugins/?.lua and Scripts/Plugins/?/init.lua in package.path. No junction or external absolute path is used.

The current workbench requires only wxLua and the reusable UI modules: it runs without LuaEx and does not initialize LuaEx. Dropping LuaEx into that location makes it available for future explicitly added tests; it does not initialize it automatically. There is consequently no missing-LuaEx error for this workbench.

#### Contents

- test.exe: newly compiled native launcher for this independent UI test, not a renamed application executable.
- Bin: 18 runtime DLLs, selected from recursive native import inspection.
- Scripts/init.lua: minimal loader; only starts Tests/UI.lua and the wx event loop.
- Scripts/Tests/UI.lua: standalone workbench copy with UI Test branding and sample data.
- Scripts/UI: 13 widget implementations, five shared helpers, Controls.lua compatibility facade and Window.lua surface. Window's default title is neutral in this export copy.
- Images/UI/Controls and Images/UI/Window: 57 PNG skin parts.
- Source: launcher C source, build.cmd, copy/runtime hash records and validation notes. Source is not required to run.
- Licenses: upstream runtime/library notices. Microsoft runtime binaries are from the installed Visual Studio redistribution directory; their applicable Microsoft redistribution terms remain in force.

No original files were moved or modified by packaging. Existing reusable module documentation may retain its original namespace.

#### Diagnostic run and rebuilding

Run test.exe --smoke for a brief automatic startup/tab/list/live-panel/close check. Success writes smoke-result.txt beside test.exe after garbage collection. Startup errors display a UI Test error message and append test-error.log beside test.exe.

Rebuilding is optional and needs an x64 Visual Studio Developer Command Prompt, Lua 5.4 headers and its matching lua54.lib. From Source run:

    build.cmd "path to Lua include folder" "path to lua54.lib"

The build writes ../test.exe and test.obj in Source; the SDK is not needed to run the built export.

</details>
