# List and Table selection

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
