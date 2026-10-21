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
