# Progress geometry

The existing Progress object handles horizontal and vertical bars. No new object is required. Options `Orientation = "horizontal" | "vertical"` and `Origin = "left" | "right" | "top" | "bottom"` can be supplied at creation. The default is horizontal from the left. An explicitly vertical bar defaults to the bottom, filling upward. Origin alone infers the axis; conflicting explicit creation options are rejected before creating a native control.

`getOrientation()` and `setOrientation(axis, notify)` read/change the axis. Changing orientation maps forward origins left/bottom and reverse origins right/top. `getOrigin()` and `setOrigin(edge, notify)` read/change the starting edge; setOrigin automatically changes orientation to match. Neither setter changes value, layout dimensions or appearance. Call layout explicitly if the surrounding layout should change.

Both colour and skin modes support all four origins. Vertical skin materials rotate clockwise, then retain their full extent while the fill clips from the chosen edge. Center text stays horizontal and clips to the available interior; choose shorter text or an empty Text string for narrow bars.

CircularProgress accepts `StartAngle` at creation and exposes `getStartAngle()`/`setStartAngle(degrees, notify)` at runtime. Angles use clock-face coordinates: 0 top, 90 right, 180 bottom, 270 left. CW/CCW independently controls the sweep from that angle. Finite fractional and negative degrees are supported and normalize to [0, 360). The default remains 0, preserving the original twelve-o'clock start. Equivalent wrapped angles are no-ops.

All setters return the component, are silent by default, and notify only on effective changes when requested. Events are `orientationChanged` (Orientation/OldOrientation), `originChanged` (Origin/OldOrigin) and `startAngleChanged` (StartAngle/OldStartAngle). Geometry changes do not emit valueChanged or OnChange.

The Resources & panel workbench includes a directional progress meter with an origin button cycling bottom, top, right and left. The shared slider changes its value too. A separate circle-start button advances by 45 degrees without changing CW/CCW or progress.
