# Skinning controls

New visual controls must accept the shared `Skin` object. When a control needs artwork that does not yet exist, add named PNG assets under `Images/UI/Controls` and exercise them in the workbench. Colour options remain available where useful.

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
