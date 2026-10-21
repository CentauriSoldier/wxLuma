# Progress geometry

The existing Progress object handles horizontal and vertical bars. No new object is required. Options `Orientation = "horizontal" | "vertical"` and `Origin = "left" | "right" | "top" | "bottom"` can be supplied at creation. The default is horizontal from the left. An explicitly vertical bar defaults to the bottom, filling upward. Origin alone infers the axis; conflicting explicit creation options are rejected before creating a native control.

`getOrientation()` and `setOrientation(axis, notify)` read/change the axis. Changing orientation maps forward origins left/bottom and reverse origins right/top. `getOrigin()` and `setOrigin(edge, notify)` read/change the starting edge; setOrigin automatically changes orientation to match. Neither setter changes value, layout dimensions or appearance. Call layout explicitly if the surrounding layout should change.

Both colour and skin modes support all four origins. Vertical skin materials rotate clockwise, then retain their full extent while the fill clips from the chosen edge. Center text stays horizontal and clips to the available interior; choose shorter text or an empty Text string for narrow bars.

CircularProgress accepts `StartAngle` at creation and exposes `getStartAngle()`/`setStartAngle(degrees, notify)` at runtime. Angles use clock-face coordinates: 0 top, 90 right, 180 bottom, 270 left. CW/CCW independently controls the sweep from that angle. Finite fractional and negative degrees are supported and normalize to [0, 360). The default remains 0, preserving the original twelve-o'clock start. Equivalent wrapped angles are no-ops.

All setters return the component, are silent by default, and notify only on effective changes when requested. Events are `orientationChanged` (Orientation/OldOrientation), `originChanged` (Origin/OldOrigin) and `startAngleChanged` (StartAngle/OldStartAngle). Geometry changes do not emit valueChanged or OnChange.

The Resources & panel workbench includes a directional progress meter with an origin button cycling bottom, top, right and left. The shared slider changes its value too. A separate circle-start button advances by 45 degrees without changing CW/CCW or progress.

# GlobeProgress and RadialProgress

Create with `Controls.globeProgress(parent, options)` or `Controls.radialProgress(parent, options)`. Both use independent public objects and the existing `Min`/`Max`/`Value`, `getValue()`, `setValue(value, notify)`, appearance, skin, input-event and containment APIs. No timers run. Non-square bounds preserve a centered circle. Geometry is antialiased in both skin and colour modes and caches one raster per object.

GlobeProgress represents a straight liquid level inside a circular silhouette. Default is `Origin = "bottom"` and `Orientation = "vertical"`. All four origins are available through `getOrigin()`/`setOrigin(edge, notify)`; origin also sets the matching axis. `getOrientation()`/`setOrientation(axis, notify)` follow Progress's left/bottom forward and right/top reverse mapping. Progress measures level distance across the diameter, not filled circular area. The globe does not distort when the axis changes.

RadialProgress uses `Direction = "outward"` (default, center to rim) or `"inward"` (rim to center). Change it through `getDirection()`/`setDirection(direction, notify)`. Both directions are empty at Min and full at Max. Progress measures radial distance: 50% outward is a filled disc of half the outer radius; 50% inward is a filled ring surrounding a track disc of half the outer radius. This is not an angular sweep and has no starting-angle setting.

Both accept `Text` (%v/current, %m/max), `Colour = {R, G, B}`, `Appearance = "skin" | "colour"` and `Artwork`. Default appearance is skin unless Colour is supplied. Dedicated material prefixes are Globe Progress and Radial Progress, each with Track/Fill Normal/Disabled PNGs under the shared skin root. Materials stay stationary while the filled region changes. The skin owns its cached bitmaps; destroy controls before their shared skin.

Setters validate before changing state, preserve value when changing geometry or appearance, and return the public component. Notification defaults to false. User observers use `valueChanged` and `appearanceChanged` plus globe `orientationChanged`/`originChanged` or radial `directionChanged`. Shared on/off mouse, keyboard, hover, focus, enabled, size and lifecycle events are available as for the other progress controls.

The Orb meters workbench category demonstrates both objects with runtime direction buttons, independent skin toggles and a shared progress slider.


## Reserved capacity (all progress controls)

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

## Circular pie and radial bands

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

The Orb meters workbench page includes current/reserve sliders, independent
reserve direction buttons, and a toggle for the Resources page's circular pie.


## IrisProgress

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
