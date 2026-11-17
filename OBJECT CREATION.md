wxLuma Object Creation Rules
These rules define the intended behavior of new and existing controls. Apply them in the controls and shared framework code, not just in examples.
General principles
- Follow the Principle of Least Astonishment (POLA). Controls should look and behave as users expect from their OS.
- Default to the OS appearance through wxWidgets and wxLua.
- Controls must work without an explicitly supplied theme or skin.
- Centralize appearance rules. Related controls should share rendering and geometry code rather than reproduce it independently.
- Keep example controls reasonably sized. Layout space must not stretch their artwork into oversized objects.
System appearance
- Use native rendering where available.
- Otherwise, use shared geometry and semantic OS colors.
- Choose colors by purpose: button face, editor/list background, text, disabled text, selection, selection text, and border.
- Do not use old skin images, gradients, or hard-coded dark colors as System fallbacks.
- Use semantic icons that communicate the action. A calendar button should depict a calendar, not a generic information symbol.
- Icons must remain legible against their backgrounds.
Backgrounds and contrast
- Controls that belong directly on a containing surface should blend into that surface.
- Labels, checkbox areas, radio areas, and the space outside a switch’s pill should inherit the actual parent background.
- Do not paint a rectangular background around an otherwise shaped object.
- Preserve contrast between an object’s functional parts. The switch track must remain distinguishable from its parent and thumb.
- Editors, lists, and property rows should use the appropriate OS surface colors.
- Pair selection backgrounds with selection text colors.
Borders
- Use the appropriate native border by default for controls that normally have one.
- Allow an explicit Border override.
- Do not paint a second frame over an existing native border.
- Buttons, toggle buttons, image buttons, switches, checkboxes, and radio buttons default to no outer rectangular border.
- Knobs, progress bars, globes, irises, circular meters, and radial meters default to no outer rectangular border.
- Rectangular popup menus and submenus should have a visible default edge.
- A circular indicator, track outline, or object silhouette is separate from the control window’s rectangular border.
Focus and hover
- Keyboard focus must never add a dashed, dotted, or replacement outline around a custom control or its text.
- Removing focus decoration must preserve keyboard navigation and activation.
- Do not replace a removed underline with another surrounding line.
- Knobs must not change their surrounding background on hover, drag, or focus.
- Sliders must not acquire a border on focus.
- Hover feedback should describe the interactive part and remain consistent with the control’s appearance.
- Persistent separators must remain visible independently of hover. Hovering one item must not reveal unrelated separators.
Hit testing
- Hit areas must match the intended interactive geometry.
- Knob pointer and wheel input must stay within the knob itself, excluding its surrounding rectangle and caption.
- Buttons must not activate outside their visible bounds.
- Image buttons using alpha hit testing must ignore transparent image areas.
- Unused padding around skinned artwork must not activate the button.
- Activation, hover, and public pointer/click events must use the same hit-test rules.
- Captured dragging may continue outside the initial hit area until release or cancellation.
Buttons and tabs
- Buttons must not add decorative borders or lines around their captions.
- Use suitable fill or artwork changes for hover, press, and selected states.
- Center tab text by default.
- Center an icon-and-text tab group together.
- Allow explicit text-alignment overrides.
- Tabs must not add an active underline or a surrounding focus/selection outline.
Dropdowns and popup lists
- A closed non-editable dropdown should use the OS button appearance.
- Its popup should use the OS list background.
- Do not force the closed field and popup items to share one background color.
- Use OS selection and selection-text colors for selected items.
- Editable combo boxes should retain native text-editing behavior and editor appearance.
- The editor must meet the arrow region without an unexplained gap.
- Size popups for complete visible rows, accounting for native border thickness.
- Do not leave an empty row-sized area below the final item.
- Show a scrollbar only when items exceed the available viewport.
Arrows and spinners
- System dropdowns, spinners, scroll controls, overflow controls, and submenu indicators should use native arrow rendering.
- Do not substitute text characters such as V, ^, <, or > for arrow graphics.
- Image skins should supply their own arrow artwork.
- Spinner buttons must align with the editor and with each other.
- Painting and hit testing must use the same button geometry.
- Use OS metrics for scrollbar and arrow-button dimensions rather than proportional layout widths.
Sliders
- Normal and range sliders must share track and thumb artwork, dimensions, spacing, and state styling.
- A range slider differs through its two handles and interval behavior.
- Do not give range sliders unrelated thumb shapes, extra track styling, or automatic active-handle decoration.
- Overlapping handles must not darken translucent artwork by drawing the same footprint twice.
- Pointer-to-value mapping must use the same endpoints as the painted track.
Progress objects and meters
- Linear progress bars should outline the actual track.
- Globes, irises, circular meters, and radial meters should outline their outer circular shape.
- These outlines must remain visible when empty or partly filled.
- Outlines must not create a rectangular frame around circular objects.
- Use OS border colors by default in System mode.
- Default shape-outline width is two pixels.
- Support Outline = false, OutlineColour = {R, G, B}, and OutlineWidth.
- Keep circular outlines antialiased with the object.
- Shape outlines must remain stable across focus changes.
Skin organization
- Design controls to support optional skins without requiring one.
- Keep skin-specific decisions separate from control behavior.
- Store assets under named skin folders, with each object’s assets in its own object folder.
- Do not support flat asset directories.
- Preserve intentional skin artwork when a skin is explicitly selected.
- Changing skins must preserve values, selections, text, and interaction behavior.
Verification
- Verify defaults and explicit overrides at the control level.
- Test relevant enabled, disabled, hovered, pressed, selected, empty, and full states.
- Verify appearance changes preserve keyboard behavior and hit testing.
- Automated rendering checks support verification; they do not replace the user’s visual inspection.
- Do not launch the showcase or perform visual inspections unless the user requests it.
