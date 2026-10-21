# Editors and dialogs

All factories return independent actual/decoy objects, accept their own `Skin`,
and expose the usual `on`/`off`, enabled state, disposal, and containment methods.
Setters are silent unless `bNotify` is true. Dot-call methods match the other controls.

## ToggleButton

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

## NumericField

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

## Dialog

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
